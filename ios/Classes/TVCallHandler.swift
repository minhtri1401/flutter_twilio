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
    var call: Call? {
        didSet { updateHasActiveCall() }
    }
    var callInvite: CallInvite? {
        didSet { updateHasActiveCall() }
    }

    /// CallKit answer/connect completion, captured while a call is ringing and
    /// invoked once Twilio reports connect success/failure.
    var callKitCompletionCallback: ((Bool) -> Void)?

    /// Incoming-push completion handler set from PushKit; fulfilled once
    /// TwilioVoice finishes processing the payload.
    var incomingPushCompletionCallback: (() -> Void)?

    /// Active CallKit calls, used by `isCallActive(uuid:)`.
    var activeCalls: [UUID: CXCall] = [:]

    /// Pending async continuation for `place()`. Touched from the caller's
    /// queue + the Twilio SDK's delegate queues, so always read/write on the
    /// main thread — see [resolvePendingPlace] / [rejectPendingPlace].
    private var pendingPlaceContinuation: CheckedContinuation<ActiveCallDto, Error>?

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

    /// Place an outgoing call. Returns only once Twilio has a real `Call` with
    /// a valid `sid` (on `callDidStartRinging`) or the SDK rejects the
    /// connection attempt (on `callDidFailToConnect`). The CallKit round-trip
    /// means the real Twilio `Call` is materialised later inside
    /// [TVCallKitDelegate.provider(_:perform:CXStartCallAction)]; see
    /// `resolvePendingPlace` / `rejectPendingPlace`.
    func place(to: String, from: String?, extra: [String: String]) async throws -> ActiveCallDto {
        // Preconditions — fail fast with typed errors.
        if state.hasActiveCall {
            throw FlutterTwilioError.of(
                "call_already_active",
                "Another call is already active."
            )
        }
        guard state.accessToken != nil else {
            throw FlutterTwilioError.of(
                "not_initialized",
                "setAccessToken was not called."
            )
        }
        guard permissionHandler.hasMicPermission() else {
            throw FlutterTwilioError.of(
                "missing_permission",
                "Microphone permission is required to place a call.",
                ["permission": "microphone"]
            )
        }

        // Mirror the legacy state tracking so CXStartCallAction builds
        // `ConnectOptions` from `state.callArgs`.
        state.callOutgoing = true
        state.identity = from ?? state.identity
        state.callTo = to

        var args: [String: AnyObject] = [:]
        args["To"] = to as AnyObject
        if let f = from { args["From"] = f as AnyObject }
        for (k, v) in extra { args[k] = v as AnyObject }
        state.callArgs = args

        return try await withCheckedThrowingContinuation { cont in
            // All continuation access happens on the main thread so we never
            // race callDidStartRinging / callDidFailToConnect (which come in
            // on Twilio SDK queues).
            DispatchQueue.main.async {
                if self.pendingPlaceContinuation != nil {
                    cont.resume(throwing: FlutterTwilioError.of(
                        "call_already_active",
                        "A place() request is already in flight."
                    ))
                    return
                }
                self.pendingPlaceContinuation = cont
                let uuid = UUID()
                self.performStartCallAction(uuid: uuid, handle: to)
            }
        }
    }

    /// Called by `TVCallDelegate.callDidStartRinging` — earliest point the
    /// Twilio `Call` has a real CA* sid we can hand back to Dart.
    func resolvePendingPlace(with call: Call) {
        DispatchQueue.main.async {
            guard let cont = self.pendingPlaceContinuation else { return }
            self.pendingPlaceContinuation = nil
            cont.resume(returning: self.snapshotActiveCall(from: call))
        }
    }

    /// Called by `TVCallDelegate.callDidFailToConnect` or by the CallKit
    /// delegate when `CXStartCallAction` can't be fulfilled.
    func rejectPendingPlace(with error: Error) {
        DispatchQueue.main.async {
            guard let cont = self.pendingPlaceContinuation else { return }
            self.pendingPlaceContinuation = nil
            if let pe = error as? PigeonError {
                cont.resume(throwing: pe)
            } else {
                cont.resume(throwing: FlutterTwilioError.fromTwilio(error))
            }
        }
    }

    func answer() throws {
        if state.hasActiveCall && callInvite == nil {
            // There's a live `Call` already running — don't start a second.
            throw FlutterTwilioError.of(
                "call_already_active",
                "Another call is already active."
            )
        }
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

    // MARK: - Snapshot helpers

    /// Build an `ActiveCallDto` from a live Twilio `Call`. Used to resolve the
    /// `place()` continuation with the real sid.
    func snapshotActiveCall(from call: Call) -> ActiveCallDto {
        let resolvedFrom = call.from ?? state.identity
        let resolvedTo = call.to ?? state.callTo
        let startedAt = state.callStartedAtMillis > 0
            ? state.callStartedAtMillis
            : Int64(Date().timeIntervalSince1970 * 1000.0)
        return ActiveCallDto(
            sid: call.sid,
            from: resolvedFrom,
            to: resolvedTo,
            direction: .outgoing,
            startedAt: startedAt,
            isMuted: state.isMuted,
            isOnHold: state.isOnHold,
            isOnSpeaker: audioHandler.isSpeakerOn,
            customParameters: [:]
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
                // Transaction refused before Twilio ever saw the call — treat
                // as a transport-level failure so Dart surfaces it via the
                // `connection_error` taxonomy, not as a raw SDK error.
                let pe = FlutterTwilioError.of(
                    "connection_error",
                    "CallKit refused to start the transaction: \(error.localizedDescription)",
                    ["nativeMessage": error.localizedDescription]
                )
                self.emitter.emitError(
                    pe.code,
                    pe.message ?? "CallKit refused transaction",
                    (pe.details as? [String: Any?]) ?? [:]
                )
                self.rejectPendingPlace(with: pe)
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
        guard let token = state.accessToken else {
            rejectPendingPlace(with: FlutterTwilioError.of(
                "not_initialized",
                "Access token was cleared before CXStartCallAction fired."
            ))
            completionHandler(false)
            return
        }
        guard let delegate = delegateOwner as? CallDelegate else {
            rejectPendingPlace(with: FlutterTwilioError.of(
                "unknown",
                "Call delegate owner was deallocated."
            ))
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

    // MARK: - Private helpers

    private func updateHasActiveCall() {
        state.hasActiveCall = (call != nil) || (callInvite != nil)
    }
}
