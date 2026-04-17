import Foundation
import UIKit
import CallKit
import TwilioVoice

// MARK: - TwilioVoice.CallDelegate (in-call lifecycle)
extension FlutterTwilioPlugin: CallDelegate {
    public func callDidStartRinging(call: Call) {
        emitter.emit(.ringing)
    }

    public func callDidConnect(call: Call) {
        state.callStartedAtMillis = Int64(Date().timeIntervalSince1970 * 1000.0)
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
        emitter.emitError(
            "twilio_sdk_error",
            error.localizedDescription,
            [
                "twilioCode": (error as NSError).code,
                "twilioDomain": (error as NSError).domain,
                "nativeMessage": error.localizedDescription,
            ]
        )
        emitter.emit(.callEnded)
        callHandler.callKitCompletionCallback?(false)
        if let uuid = call.uuid {
            callKitProvider.reportCall(with: uuid, endedAt: Date(), reason: .failed)
        }
        callHandler.callDisconnected()
    }

    public func callDidDisconnect(call: Call, error: Error?) {
        if let error = error {
            emitter.emitError(
                "twilio_sdk_error",
                error.localizedDescription,
                [
                    "twilioCode": (error as NSError).code,
                    "twilioDomain": (error as NSError).domain,
                    "nativeMessage": error.localizedDescription,
                ]
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
