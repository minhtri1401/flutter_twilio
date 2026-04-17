import Foundation
import UIKit
import AVFoundation
import TwilioVoice
import CallKit

/// Plain Swift handler exposing typed call-operation methods for the Pigeon
/// [VoiceHostApi]. Holds the current Twilio `Call` / `CallInvite` plus the
/// `CXCallController` used to bridge the Dart API to CallKit.
final class TVCallHandler {

    private let tag = "TVCallHandler"

    private let state: TVPluginState
    private let emitter: TVEventEmitter
    private let audioHandler: TVAudioHandler
    private let permissionHandler: TVPermissionHandler
    private let callController: CXCallController
    private let callKitProvider: CXProvider

    /// Current active TwilioVoice call (outgoing or accepted incoming).
    weak var delegateOwner: AnyObject?
    var call: Call?
    var callInvite: CallInvite?

    /// CallKit answer/connect completion, captured while a call is ringing and
    /// invoked once Twilio reports connect success/failure.
    var callKitCompletionCallback: ((Bool) -> Void)?

    /// Incoming-push completion handler set from PushKit; fulfilled once
    /// TwilioVoice finishes processing the payload.
    var incomingPushCompletionCallback: (() -> Void)?

    /// Active CallKit calls, used by `isCallActive(uuid:)`.
    var activeCalls: [UUID: CXCall] = [:]

    init(
        state: TVPluginState,
        emitter: TVEventEmitter,
        audioHandler: TVAudioHandler,
        permissionHandler: TVPermissionHandler,
        callController: CXCallController,
        callKitProvider: CXProvider
    ) {
        self.state = state
        self.emitter = emitter
        self.audioHandler = audioHandler
        self.permissionHandler = permissionHandler
        self.callController = callController
        self.callKitProvider = callKitProvider
    }

    // MARK: - VoiceHostApi entry points

    func place(to: String, from: String?, extra: [String: String]) throws -> ActiveCallDto {
        guard state.accessToken != nil else {
            throw FlutterTwilioError.of("not_initialized", "Access token not set")
        }
        guard permissionHandler.hasMicPermission() else {
            throw FlutterTwilioError.of(
                "missing_permission",
                "Microphone permission is required to place calls",
                ["permission": "microphone"]
            )
        }

        // Mirror the legacy state tracking so CXStartCallAction builds
        // ConnectOptions from `state.callArgs`.
        state.callOutgoing = true
        state.identity = from ?? state.identity
        state.callTo = to

        var args: [String: AnyObject] = [:]
        args["To"] = to as AnyObject
        if let f = from { args["From"] = f as AnyObject }
        for (k, v) in extra { args[k] = v as AnyObject }
        state.callArgs = args

        let uuid = UUID()
        performStartCallAction(uuid: uuid, handle: to)

        return ActiveCallDto(
            sid: call?.sid ?? "unknown",
            from: from ?? "",
            to: to,
            direction: .outgoing,
            startedAt: state.callStartedAtMillis,
            isMuted: state.isMuted,
            isOnHold: state.isOnHold,
            isOnSpeaker: audioHandler.isSpeakerOn,
            customParameters: [:]
        )
    }

    func answer() throws {
        guard let ci = callInvite else {
            throw FlutterTwilioError.of("no_active_call", "No pending call invite to answer")
        }
        let answerAction = CXAnswerCallAction(call: ci.uuid)
        let transaction = CXTransaction(action: answerAction)
        callController.request(transaction) { [weak self] error in
            if let error = error {
                self?.emitter.emitError(
                    "connection_error",
                    "AnswerCallAction request failed: \(error.localizedDescription)"
                )
            }
        }
    }

    func reject() throws {
        guard let ci = callInvite else {
            throw FlutterTwilioError.of("no_active_call", "No pending call invite to reject")
        }
        performEndCallAction(uuid: ci.uuid)
        emitter.emit(.reject)
    }

    func hangUp() throws {
        if let call = call {
            state.userInitiatedDisconnect = true
            performEndCallAction(uuid: call.uuid ?? UUID())
        } else if let ci = callInvite {
            performEndCallAction(uuid: ci.uuid)
        } else {
            throw FlutterTwilioError.of("no_active_call", "No active call to hang up")
        }
    }

    func setMuted(_ muted: Bool) throws {
        guard let call = call else {
            throw FlutterTwilioError.of("no_active_call", "No active call to mute")
        }
        call.isMuted = muted
        state.isMuted = muted
        emitter.emit(muted ? .mute : .unmute)
    }

    func setOnHold(_ onHold: Bool) throws {
        guard let call = call else {
            throw FlutterTwilioError.of("no_active_call", "No active call to hold")
        }
        call.isOnHold = onHold
        state.isOnHold = onHold
        emitter.emit(onHold ? .hold : .unhold)
    }

    func sendDigits(_ digits: String) throws {
        guard let call = call else {
            throw FlutterTwilioError.of("no_active_call", "No active call to send digits")
        }
        call.sendDigits(digits)
    }

    func getActiveCall() -> ActiveCallDto? {
        if call == nil && callInvite == nil { return nil }

        let sid: String
        if let s = call?.sid {
            sid = s
        } else if let s = callInvite?.callSid {
            sid = s
        } else {
            sid = "unknown"
        }

        let fromResolved = call?.from ?? callInvite?.from ?? state.identity
        let toResolved = call?.to ?? callInvite?.to ?? state.callTo
        let direction: CallDirection = (callInvite != nil && call == nil) ? .incoming : .outgoing

        // CallInvite.customParameters is `[String: String]?` (values are Strings).
        let custom: [String?: String?] = callInvite?.customParameters?.reduce(
            into: [String?: String?]()
        ) { acc, pair in
            acc[pair.key] = pair.value
        } ?? [:]

        return ActiveCallDto(
            sid: sid,
            from: fromResolved,
            to: toResolved,
            direction: direction,
            startedAt: state.callStartedAtMillis,
            isMuted: state.isMuted,
            isOnHold: state.isOnHold,
            isOnSpeaker: audioHandler.isSpeakerOn,
            customParameters: custom
        )
    }

    // MARK: - CallKit transactions (used by delegates)

    func performStartCallAction(uuid: UUID, handle: String) {
        let callHandle = CXHandle(type: .generic, value: handle)
        let startCallAction = CXStartCallAction(call: uuid, handle: callHandle)
        let transaction = CXTransaction(action: startCallAction)
        callController.request(transaction) { [weak self] error in
            guard let self = self else { return }
            if let error = error {
                self.emitter.emitError(
                    "connection_error",
                    "StartCallAction transaction request failed: \(error.localizedDescription)"
                )
                return
            }
            let callUpdate = CXCallUpdate()
            callUpdate.remoteHandle = callHandle
            callUpdate.localizedCallerName = handle
            callUpdate.supportsDTMF = false
            callUpdate.supportsHolding = true
            callUpdate.supportsGrouping = false
            callUpdate.supportsUngrouping = false
            callUpdate.hasVideo = false
            self.callKitProvider.reportCall(with: uuid, updated: callUpdate)
        }
    }

    func reportIncomingCall(from: String, uuid: UUID) {
        let callHandle = CXHandle(type: .generic, value: from)
        let callUpdate = CXCallUpdate()
        callUpdate.remoteHandle = callHandle
        callUpdate.localizedCallerName = from
        callUpdate.supportsDTMF = true
        callUpdate.supportsHolding = true
        callUpdate.supportsGrouping = false
        callUpdate.supportsUngrouping = false
        callUpdate.hasVideo = false
        callKitProvider.reportNewIncomingCall(with: uuid, update: callUpdate) { [weak self] error in
            if let error = error {
                self?.emitter.emitError(
                    "connection_error",
                    "Failed to report incoming call: \(error.localizedDescription)"
                )
            }
        }
    }

    func performEndCallAction(uuid: UUID) {
        guard isCallActive(uuid: uuid) else {
            // Call already ended — still flush a callEnded to Dart listeners.
            emitter.emit(.callEnded)
            return
        }
        let endCallAction = CXEndCallAction(call: uuid)
        callController.request(CXTransaction(action: endCallAction)) { [weak self] error in
            if let error = error {
                self?.emitter.emitError(
                    "connection_error",
                    "End Call Failed: \(error.localizedDescription)"
                )
            } else {
                self?.emitter.emit(.callEnded)
            }
        }
    }

    func performVoiceCall(uuid: UUID, completionHandler: @escaping (Bool) -> Void) {
        guard let token = state.accessToken else { completionHandler(false); return }
        guard let delegate = delegateOwner as? CallDelegate else {
            completionHandler(false)
            return
        }
        let connectOptions = ConnectOptions(accessToken: token) { builder in
            for (key, value) in self.state.callArgs where key != "From" {
                builder.params[key] = "\(value)"
            }
            builder.uuid = uuid
        }
        call = TwilioVoiceSDK.connect(options: connectOptions, delegate: delegate)
        callKitCompletionCallback = completionHandler
    }

    func performAnswerVoiceCall(uuid: UUID, completionHandler: @escaping (Bool) -> Void) {
        guard let ci = callInvite else {
            completionHandler(false)
            return
        }
        guard let delegate = delegateOwner as? CallDelegate else {
            completionHandler(false)
            return
        }
        let acceptOptions = AcceptOptions(callInvite: ci) { builder in builder.uuid = ci.uuid }
        let theCall = ci.accept(options: acceptOptions, delegate: delegate)
        call = theCall
        callKitCompletionCallback = completionHandler
        // Keep the invite live in getActiveCall until the call is fully marked
        // incoming via events; but clear it so a subsequent answer() throws.
        callInvite = nil
        guard #available(iOS 13, *) else {
            incomingPushHandled()
            return
        }
    }

    func isCallActive(uuid: UUID) -> Bool {
        return activeCalls[uuid] != nil
    }

    func callDisconnected() {
        call = nil
        callInvite = nil
        state.callOutgoing = false
        state.userInitiatedDisconnect = false
        state.isMuted = false
        state.isOnHold = false
        state.isSpeakerOn = false
        state.callStartedAtMillis = 0
    }

    func incomingPushHandled() {
        if let completion = incomingPushCompletionCallback {
            incomingPushCompletionCallback = nil
            completion()
        }
    }
}
