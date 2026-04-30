import Foundation
import UIKit
import CallKit
import TwilioVoice

// MARK: - TwilioVoice.CallDelegate (in-call lifecycle)
extension FlutterTwilioPlugin: CallDelegate {
    public func callDidStartRinging(call: Call) {
        // Earliest point the Twilio `Call` has a real CA-prefixed `sid` —
        // resolve any pending `place()` continuation with the live snapshot.
        callHandler.resolvePendingPlace(with: call)
        emitter.emit(.ringing)
        callHandler.makeRingbackController()
        callHandler.ringback?.onCallEvent(.outgoingConnecting)
    }

    public func callDidConnect(call: Call) {
        let nowMs = Int64(Date().timeIntervalSince1970 * 1000.0)
        state.callStartedAtMillis = nowMs
        state.connectedAtMillis = nowMs
        callHandler.ringback?.onCallEvent(.connected)
        if state.voiceConfig.playConnectTone {
            callHandler.connectTone.play(
                flutterAssetKey: state.voiceConfig.connectToneAssetKey,
                bundledResource: "connect_tone",
                looping: false
            )
        }
        emitter.emit(.connected)
        callHandler.callKitCompletionCallback?(true)
        // Default speaker-off on connect, matching the legacy behavior.
        audioHandler.toggleAudioRoute(toSpeaker: false)
    }

    public func call(call: Call, isReconnectingWithError error: Error) {
        emitter.emit(.reconnecting)
    }

    public func callDidReconnect(call: Call) {
        emitter.emit(.reconnected)
    }

    public func callDidFailToConnect(call: Call, error: Error) {
        callHandler.ringback?.onCallEvent(.error)
        let ns = error as NSError
        let twilioCode = ns.userInfo["TVErrorCodeKey"] as? Int ?? ns.code
        let stable = FlutterTwilioError.stableCodeFor(nsError: ns, twilioCode: twilioCode)
        emitter.emitError(
            stable,
            error.localizedDescription,
            FlutterTwilioError.twilioDetails(error)
        )
        emitter.emit(.callEnded)
        callHandler.callKitCompletionCallback?(false)
        // Resolve any in-flight place() continuation with the mapped error.
        callHandler.rejectPendingPlace(with: FlutterTwilioError.fromTwilio(error))
        if let uuid = call.uuid {
            callKitProvider.reportCall(with: uuid, endedAt: Date(), reason: .failed)
        }
        callHandler.callDisconnected()
    }

    public func callDidDisconnect(call: Call, error: Error?) {
        callHandler.ringback?.onCallEvent(.disconnected)
        if state.voiceConfig.playDisconnectTone {
            callHandler.disconnectTone.play(
                flutterAssetKey: state.voiceConfig.disconnectToneAssetKey,
                bundledResource: "disconnect_tone",
                looping: false
            )
        }
        if let error = error {
            let ns = error as NSError
            let twilioCode = ns.userInfo["TVErrorCodeKey"] as? Int ?? ns.code
            let stable = FlutterTwilioError.stableCodeFor(nsError: ns, twilioCode: twilioCode)
            emitter.emitError(
                stable,
                error.localizedDescription,
                FlutterTwilioError.twilioDetails(error)
            )
            emitter.emit(.callEnded)
        } else {
            emitter.emit(.disconnected)
            emitter.emit(.callEnded)
        }
        if !state.userInitiatedDisconnect {
            var reason = CXCallEndedReason.remoteEnded
            if error != nil { reason = .failed }
            if let uuid = call.uuid {
                callKitProvider.reportCall(with: uuid, endedAt: Date(), reason: reason)
            }
        }
        callHandler.callDisconnected()
    }
}
