import UserNotifications
import TwilioVoice

// MARK: - NotificationDelegate
extension FlutterTwilioPlugin: NotificationDelegate {
    public func callInviteReceived(callInvite: CallInvite) {
        sendPhoneCallEvents(description: "LOG|callInviteReceived:", isError: false)
        UserDefaults.standard.set(Date(), forKey: kCachedBindingDate)

        var from = callInvite.from ?? defaultCaller
        from = from.replacingOccurrences(of: "client:", with: "")

        sendPhoneCallEvents(description: "Ringing|\(from)|\(callInvite.to)|Incoming\(formatCustomParams(params: callInvite.customParameters))", isError: false)
        reportIncomingCall(from: from, uuid: callInvite.uuid)
        self.callInvite = callInvite
    }

    public func cancelledCallInviteReceived(cancelledCallInvite: CancelledCallInvite, error: Error) {
        sendPhoneCallEvents(description: "Missed Call", isError: false)
        sendPhoneCallEvents(description: "LOG|cancelledCallInviteCanceled:", isError: false)
        showMissedCallNotification(from: cancelledCallInvite.from, to: cancelledCallInvite.to)
        guard let ci = callInvite else {
            sendPhoneCallEvents(description: "LOG|No pending call invite", isError: false)
            return
        }
        performEndCallAction(uuid: ci.uuid)
    }

    func formatCustomParams(params: [String: Any]?) -> String {
        guard let customParameters = params else { return "" }
        do {
            let jsonData = try JSONSerialization.data(withJSONObject: customParameters)
            if let jsonStr = String(data: jsonData, encoding: .utf8) {
                return "|\(jsonStr)"
            }
        } catch {
            print("unable to send custom parameters")
        }
        return ""
    }

    func showMissedCallNotification(from: String?, to: String?) {
        guard UserDefaults.standard.optionalBool(forKey: "show-notifications") ?? true else { return }
        let notificationCenter = UNUserNotificationCenter.current()
        notificationCenter.getNotificationSettings { settings in
            guard settings.authorizationStatus == .authorized else { return }
            let content = UNMutableNotificationContent()
            var userName: String?
            if var fromStr = from {
                if fromStr.contains("client:") {
                    fromStr = fromStr.replacingOccurrences(of: "client:", with: "")
                    userName = self.clients[fromStr]
                } else {
                    userName = fromStr
                }
                content.userInfo = ["type": "twilio-missed-call", "From": fromStr]
                if let to = to { content.userInfo["To"] = to }
            }
            content.title = userName ?? self.clients["defaultCaller"] ?? self.defaultCaller
            content.body = NSLocalizedString("notification_missed_call_body", comment: "")
            let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
            let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: trigger)
            notificationCenter.add(request) { error in
                if let error = error { print("Notification Error: ", error) }
            }
        }
    }
}

// MARK: - UNUserNotificationCenterDelegate
extension FlutterTwilioPlugin: UNUserNotificationCenterDelegate {
    public func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse, withCompletionHandler completionHandler: @escaping () -> Void) {
        let userInfo = response.notification.request.content.userInfo
        if let type = userInfo["type"] as? String, type == "twilio-missed-call", let user = userInfo["From"] as? String {
            callTo = user
            if let to = userInfo["To"] as? String { identity = to }
            makeCall(to: callTo)
            completionHandler()
            sendPhoneCallEvents(description: "ReturningCall|\(identity)|\(user)|Outgoing", isError: false)
        }
    }

    public func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification, withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        let userInfo = notification.request.content.userInfo
        if let type = userInfo["type"] as? String, type == "twilio-missed-call" {
            completionHandler([.alert])
        }
    }
}
