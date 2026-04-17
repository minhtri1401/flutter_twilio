import Flutter
import PushKit
import TwilioVoice

// MARK: - PKPushRegistryDelegate
extension FlutterTwilioPlugin: PKPushRegistryDelegate {
    public func pushRegistry(_ registry: PKPushRegistry, didUpdate credentials: PKPushCredentials, for type: PKPushType) {
        sendPhoneCallEvents(description: "LOG|pushRegistry:didUpdatePushCredentials:forType:", isError: false)
        guard type == .voIP else { return }
        guard registrationRequired() || deviceToken != credentials.token else {
            sendPhoneCallEvents(description: "LOG|pushRegistry:didUpdatePushCredentials device token unchanged, no update needed.", isError: false)
            return
        }
        sendPhoneCallEvents(description: "LOG|pushRegistry:didUpdatePushCredentials:forType: device token updated", isError: false)
        let token = credentials.token
        sendPhoneCallEvents(description: "LOG|pushRegistry:attempting to register with twilio", isError: false)
        if let accessToken = accessToken {
            TwilioVoiceSDK.register(accessToken: accessToken, deviceToken: token) { error in
                if let error = error {
                    self.sendPhoneCallEvents(description: "LOG|An error occurred while registering: \(error.localizedDescription)", isError: false)
                    self.sendPhoneCallEvents(description: "DEVICETOKEN|\(String(decoding: token, as: UTF8.self))", isError: false)
                } else {
                    self.sendPhoneCallEvents(description: "LOG|Successfully registered for VoIP push notifications.", isError: false)
                }
            }
        }
        deviceToken = token
        UserDefaults.standard.set(Date(), forKey: kCachedBindingDate)
    }

    public func pushRegistry(_ registry: PKPushRegistry, didInvalidatePushTokenFor type: PKPushType) {
        sendPhoneCallEvents(description: "LOG|pushRegistry:didInvalidatePushTokenForType:", isError: false)
        guard type == .voIP else { return }
        unregister()
    }

    public func pushRegistry(_ registry: PKPushRegistry, didReceiveIncomingPushWith payload: PKPushPayload, for type: PKPushType) {
        sendPhoneCallEvents(description: "LOG|pushRegistry:didReceiveIncomingPushWithPayload:forType:", isError: false)
        if type == .voIP {
            TwilioVoiceSDK.handleNotification(payload.dictionaryPayload, delegate: self, delegateQueue: nil)
        }
    }

    public func pushRegistry(_ registry: PKPushRegistry, didReceiveIncomingPushWith payload: PKPushPayload, for type: PKPushType, completion: @escaping () -> Void) {
        sendPhoneCallEvents(description: "LOG|pushRegistry:didReceiveIncomingPushWithPayload:forType:completion:", isError: false)
        if type == .voIP {
            TwilioVoiceSDK.handleNotification(payload.dictionaryPayload, delegate: self, delegateQueue: nil)
        }
        if let version = Float(UIDevice.current.systemVersion), version < 13.0 {
            incomingPushCompletionCallback = completion
        } else {
            completion()
        }
    }
}

// MARK: - Registration helpers
extension FlutterTwilioPlugin {
    func registrationRequired() -> Bool {
        guard let lastBinding = UserDefaults.standard.object(forKey: kCachedBindingDate) as? Date else {
            sendPhoneCallEvents(description: "LOG|Registration required: true, last binding date not found", isError: false)
            return true
        }
        var components = DateComponents()
        components.setValue(kRegistrationTTLInDays / 2, for: .day)
        guard let expirationDate = Calendar.current.date(byAdding: components, to: lastBinding) else { return true }
        if expirationDate.compare(Date()) == .orderedDescending {
            sendPhoneCallEvents(description: "LOG|Registration required: false, half of TTL not passed", isError: false)
            return false
        }
        return true
    }

    func register() {
        guard let deviceToken = deviceToken, let token = accessToken else {
            sendPhoneCallEvents(description: "LOG|Missing required parameters to register", isError: true)
            return
        }
        registerTokens(token: token, deviceToken: deviceToken)
    }

    func registerTokens(token: String, deviceToken: Data) {
        TwilioVoiceSDK.register(accessToken: token, deviceToken: deviceToken) { error in
            if let error = error {
                self.sendPhoneCallEvents(description: "LOG|An error occurred while registering: \(error.localizedDescription)", isError: false)
            } else {
                self.sendPhoneCallEvents(description: "LOG|Successfully registered for VoIP push notifications.", isError: false)
            }
        }
    }

    func unregister() {
        guard let deviceToken = deviceToken, let token = accessToken else {
            sendPhoneCallEvents(description: "LOG|Missing required parameters to unregister", isError: true)
            return
        }
        unregisterTokens(token: token, deviceToken: deviceToken)
    }

    func unregisterTokens(token: String, deviceToken: Data) {
        TwilioVoiceSDK.unregister(accessToken: token, deviceToken: deviceToken) { error in
            if let error = error {
                self.sendPhoneCallEvents(description: "LOG|An error occurred while unregistering: \(error.localizedDescription)", isError: false)
            } else {
                self.sendPhoneCallEvents(description: "LOG|Successfully unregistered from VoIP push notifications.", isError: false)
            }
        }
    }
}

// MARK: - handle() registration helpers
extension FlutterTwilioPlugin {
    func handleTokens(args: [String: AnyObject], result: FlutterResult) {
        guard let token = args["accessToken"] as? String else {
            result(FlutterError(code: "INVALID_ARGUMENTS", message: "Missing accessToken", details: nil))
            return
        }
        accessToken = token
        guard let deviceToken = deviceToken else {
            sendPhoneCallEvents(description: "LOG|Device token is nil. Cannot register for VoIP push notifications.", isError: true)
            return
        }
        sendPhoneCallEvents(description: "LOG|pushRegistry:attempting to register with twilio", isError: false)
        TwilioVoiceSDK.register(accessToken: token, deviceToken: deviceToken) { error in
            if let error = error {
                self.sendPhoneCallEvents(description: "LOG|An error occurred while registering: \(error.localizedDescription)", isError: false)
            } else {
                self.sendPhoneCallEvents(description: "LOG|Successfully registered for VoIP push notifications.", isError: false)
            }
        }
    }

    func handleUnregister(args: [String: AnyObject]) {
        guard let deviceToken = deviceToken else { return }
        if let token = args["accessToken"] as? String {
            unregisterTokens(token: token, deviceToken: deviceToken)
        } else if let token = accessToken {
            unregisterTokens(token: token, deviceToken: deviceToken)
        }
    }

    func handleRegisterClient(args: [String: AnyObject]) {
        guard let clientId = args["id"] as? String, let clientName = args["name"] as? String else { return }
        if clients[clientId] == nil || clients[clientId] != clientName {
            clients[clientId] = clientName
            UserDefaults.standard.set(clients, forKey: kClientList)
        }
    }

    func handleUnregisterClient(args: [String: AnyObject]) {
        guard let clientId = args["id"] as? String else { return }
        clients.removeValue(forKey: clientId)
        UserDefaults.standard.set(clients, forKey: kClientList)
    }

    func handleDefaultCaller(args: [String: AnyObject]) {
        guard let caller = args["defaultCaller"] as? String else { return }
        defaultCaller = caller
        if clients["defaultCaller"] == nil || clients["defaultCaller"] != defaultCaller {
            clients["defaultCaller"] = defaultCaller
            UserDefaults.standard.set(clients, forKey: kClientList)
        }
    }
}
