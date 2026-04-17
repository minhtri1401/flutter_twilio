import CallKit
import AVFoundation

// MARK: - CXProviderDelegate
extension FlutterTwilioPlugin: CXProviderDelegate {
    public func providerDidReset(_ provider: CXProvider) {
        sendPhoneCallEvents(description: "LOG|providerDidReset:", isError: false)
        audioDevice.isEnabled = false
    }

    public func providerDidBegin(_ provider: CXProvider) {
        sendPhoneCallEvents(description: "LOG|providerDidBegin", isError: false)
    }

    public func provider(_ provider: CXProvider, didActivate audioSession: AVAudioSession) {
        sendPhoneCallEvents(description: "LOG|provider:didActivateAudioSession:", isError: false)
        audioDevice.isEnabled = true
    }

    public func provider(_ provider: CXProvider, didDeactivate audioSession: AVAudioSession) {
        sendPhoneCallEvents(description: "LOG|provider:didDeactivateAudioSession:", isError: false)
        audioDevice.isEnabled = false
    }

    public func provider(_ provider: CXProvider, timedOutPerforming action: CXAction) {
        sendPhoneCallEvents(description: "LOG|provider:timedOutPerformingAction:", isError: false)
    }

    public func provider(_ provider: CXProvider, perform action: CXStartCallAction) {
        sendPhoneCallEvents(description: "LOG|provider:performStartCallAction:", isError: false)
        provider.reportOutgoingCall(with: action.callUUID, startedConnectingAt: Date())
        performVoiceCall(uuid: action.callUUID, client: "") { success in
            if success {
                self.sendPhoneCallEvents(description: "LOG|provider:performVoiceCall() successful", isError: false)
                provider.reportOutgoingCall(with: action.callUUID, connectedAt: Date())
            } else {
                self.sendPhoneCallEvents(description: "LOG|provider:performVoiceCall() failed", isError: false)
            }
        }
        action.fulfill()
    }

    public func provider(_ provider: CXProvider, perform action: CXAnswerCallAction) {
        sendPhoneCallEvents(description: "LOG|provider:performAnswerCallAction:", isError: false)
        performAnswerVoiceCall(uuid: action.callUUID) { success in
            if success {
                self.sendPhoneCallEvents(description: "LOG|provider:performAnswerVoiceCall() successful", isError: false)
            } else {
                self.sendPhoneCallEvents(description: "LOG|provider:performAnswerVoiceCall() failed:", isError: false)
            }
        }
        action.fulfill()
    }

    public func provider(_ provider: CXProvider, perform action: CXEndCallAction) {
        sendPhoneCallEvents(description: "LOG|provider:performEndCallAction:", isError: false)
        if callInvite != nil {
            sendPhoneCallEvents(description: "LOG|provider:performEndCallAction: rejecting call", isError: false)
            callInvite?.reject()
            callInvite = nil
        } else if let call = call {
            sendPhoneCallEvents(description: "LOG|provider:performEndCallAction: disconnecting call", isError: false)
            call.disconnect()
        }
        action.fulfill()
    }

    public func provider(_ provider: CXProvider, perform action: CXSetHeldCallAction) {
        sendPhoneCallEvents(description: "LOG|provider:performSetHeldAction:", isError: false)
        if let call = call {
            call.isOnHold = action.isOnHold
            action.fulfill()
        } else {
            action.fail()
        }
    }

    public func provider(_ provider: CXProvider, perform action: CXSetMutedCallAction) {
        sendPhoneCallEvents(description: "LOG|provider:performSetMutedAction:", isError: false)
        if let call = call {
            call.isMuted = action.isMuted
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
            activeCalls.removeValue(forKey: call.uuid)
        } else {
            activeCalls[call.uuid] = call
        }
    }

    func isCallActive(uuid: UUID) -> Bool {
        return activeCalls[uuid] != nil
    }

    func incomingPushHandled() {
        if let completion = incomingPushCompletionCallback {
            incomingPushCompletionCallback = nil
            completion()
        }
    }
}
