import Foundation
import CallKit
import AVFoundation

// MARK: - CXProviderDelegate
extension FlutterTwilioPlugin: CXProviderDelegate {
    public func providerDidReset(_ provider: CXProvider) {
        audioDevice.isEnabled = false
    }

    public func providerDidBegin(_ provider: CXProvider) {}

    public func provider(_ provider: CXProvider, didActivate audioSession: AVAudioSession) {
        audioDevice.isEnabled = true
    }

    public func provider(_ provider: CXProvider, didDeactivate audioSession: AVAudioSession) {
        audioDevice.isEnabled = false
    }

    public func provider(_ provider: CXProvider, timedOutPerforming action: CXAction) {}

    public func provider(_ provider: CXProvider, perform action: CXStartCallAction) {
        provider.reportOutgoingCall(with: action.callUUID, startedConnectingAt: Date())
        callHandler.performVoiceCall(uuid: action.callUUID) { success in
            if success {
                provider.reportOutgoingCall(with: action.callUUID, connectedAt: Date())
            }
        }
        action.fulfill()
    }

    public func provider(_ provider: CXProvider, perform action: CXAnswerCallAction) {
        callHandler.performAnswerVoiceCall(uuid: action.callUUID) { _ in }
        emitter.emit(.answer)
        action.fulfill()
    }

    public func provider(_ provider: CXProvider, perform action: CXEndCallAction) {
        if callHandler.callInvite != nil {
            callHandler.callInvite?.reject()
            callHandler.callInvite = nil
        } else if let call = callHandler.call {
            call.disconnect()
        }
        action.fulfill()
    }

    public func provider(_ provider: CXProvider, perform action: CXSetHeldCallAction) {
        if let call = callHandler.call {
            call.isOnHold = action.isOnHold
            state.isOnHold = action.isOnHold
            emitter.emit(action.isOnHold ? .hold : .unhold)
            action.fulfill()
        } else {
            action.fail()
        }
    }

    public func provider(_ provider: CXProvider, perform action: CXSetMutedCallAction) {
        if let call = callHandler.call {
            call.isMuted = action.isMuted
            state.isMuted = action.isMuted
            emitter.emit(action.isMuted ? .mute : .unmute)
            action.fulfill()
        } else {
            action.fail()
        }
    }
}

// MARK: - CXCallObserverDelegate
extension FlutterTwilioPlugin: CXCallObserverDelegate {
    public func callObserver(_ callObserver: CXCallObserver, callChanged call: CXCall) {
        if call.hasEnded {
            callHandler.activeCalls.removeValue(forKey: call.uuid)
        } else {
            callHandler.activeCalls[call.uuid] = call
        }
    }
}
