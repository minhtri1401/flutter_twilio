import CallKit
import TwilioVoice

// MARK: - CallKit action helpers
extension SwiftTwilioVoicePlugin {
    func performStartCallAction(uuid: UUID, handle: String) {
        let callHandle = CXHandle(type: .generic, value: handle)
        let startCallAction = CXStartCallAction(call: uuid, handle: callHandle)
        let transaction = CXTransaction(action: startCallAction)
        callKitCallController.request(transaction) { error in
            if let error = error {
                self.sendPhoneCallEvents(description: "LOG|StartCallAction transaction request failed: \(error.localizedDescription)", isError: false)
                return
            }
            self.sendPhoneCallEvents(description: "LOG|StartCallAction transaction request successful", isError: false)
            var callerName: String?
            if handle.contains("client:") {
                callerName = self.clients[handle.replacingOccurrences(of: "client:", with: "")]
            } else {
                callerName = handle
            }
            let callUpdate = CXCallUpdate()
            callUpdate.remoteHandle = callHandle
            callUpdate.localizedCallerName = callerName ?? self.clients["defaultCaller"] ?? self.defaultCaller
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
        var callerName: String?
        if from.contains("client:") {
            callerName = clients[from.replacingOccurrences(of: "client:", with: "")]
        } else {
            callerName = from
        }
        let callUpdate = CXCallUpdate()
        callUpdate.remoteHandle = callHandle
        callUpdate.localizedCallerName = callerName ?? clients["defaultCaller"] ?? defaultCaller
        callUpdate.supportsDTMF = true
        callUpdate.supportsHolding = true
        callUpdate.supportsGrouping = false
        callUpdate.supportsUngrouping = false
        callUpdate.hasVideo = false
        callKitProvider.reportNewIncomingCall(with: uuid, update: callUpdate) { error in
            if let error = error {
                self.sendPhoneCallEvents(description: "LOG|Failed to report incoming call: \(error.localizedDescription).", isError: false)
            } else {
                self.sendPhoneCallEvents(description: "LOG|Incoming call successfully reported.", isError: false)
            }
        }
    }

    func performEndCallAction(uuid: UUID) {
        sendPhoneCallEvents(description: "LOG|performEndCallAction method invoked", isError: false)
        guard isCallActive(uuid: uuid) else {
            print("Call not found or already ended. Skipping end request.")
            sendPhoneCallEvents(description: "Call Ended", isError: false)
            return
        }
        let endCallAction = CXEndCallAction(call: uuid)
        callKitCallController.request(CXTransaction(action: endCallAction)) { error in
            if let error = error {
                self.sendPhoneCallEvents(description: "End Call Failed: \(error.localizedDescription).", isError: true)
            } else {
                self.sendPhoneCallEvents(description: "Call Ended", isError: false)
            }
        }
    }

    func performVoiceCall(uuid: UUID, client: String?, completionHandler: @escaping (Bool) -> Void) {
        guard let token = accessToken else { completionHandler(false); return }
        let connectOptions = ConnectOptions(accessToken: token) { builder in
            for (key, value) in self.callArgs where key != "From" {
                builder.params[key] = "\(value)"
            }
            builder.uuid = uuid
        }
        call = TwilioVoiceSDK.connect(options: connectOptions, delegate: self)
        callKitCompletionCallback = completionHandler
    }

    func performAnswerVoiceCall(uuid: UUID, completionHandler: @escaping (Bool) -> Void) {
        guard let ci = callInvite else {
            sendPhoneCallEvents(description: "LOG|No CallInvite matches the UUID", isError: false)
            return
        }
        let acceptOptions = AcceptOptions(callInvite: ci) { builder in builder.uuid = ci.uuid }
        sendPhoneCallEvents(description: "LOG|performAnswerVoiceCall: answering call", isError: false)
        let theCall = ci.accept(options: acceptOptions, delegate: self)
        let from = theCall.from ?? identity
        let to = theCall.to ?? callTo
        sendPhoneCallEvents(description: "Answer|\(from)|\(to)|Incoming\(formatCustomParams(params: ci.customParameters))", isError: false)
        call = theCall
        callKitCompletionCallback = completionHandler
        callInvite = nil
        guard #available(iOS 13, *) else { incomingPushHandled(); return }
    }
}
