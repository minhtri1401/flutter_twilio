import Foundation
import UIKit
import UserNotifications
import TwilioVoice

// MARK: - NotificationDelegate (TwilioVoice incoming call invites)
extension FlutterTwilioPlugin: NotificationDelegate {
    public func callInviteReceived(callInvite: CallInvite) {
        UserDefaults.standard.set(Date(), forKey: "CachedBindingDate")

        let fromRaw = callInvite.from ?? "Unknown Caller"
        let from = fromRaw.replacingOccurrences(of: "client:", with: "")

        callHandler.callInvite = callInvite
        callHandler.reportIncomingCall(from: from, uuid: callInvite.uuid)

        emitter.emit(.incoming)
        emitter.emit(.ringing)
    }

    public func cancelledCallInviteReceived(cancelledCallInvite: CancelledCallInvite, error: Error) {
        emitter.emit(.missedCall)
        emitter.emit(.callEnded)
        showMissedCallNotification(from: cancelledCallInvite.from, to: cancelledCallInvite.to)
        if let ci = callHandler.callInvite {
            callHandler.performEndCallAction(uuid: ci.uuid)
        }
    }

    func showMissedCallNotification(from: String?, to: String?) {
        guard UserDefaults.standard.object(forKey: "show-notifications") as? Bool ?? true else { return }
        let notificationCenter = UNUserNotificationCenter.current()
        notificationCenter.getNotificationSettings { settings in
            guard settings.authorizationStatus == .authorized else { return }
            let content = UNMutableNotificationContent()
            var userName: String?
            if var fromStr = from {
                if fromStr.contains("client:") {
                    fromStr = fromStr.replacingOccurrences(of: "client:", with: "")
                }
                userName = fromStr
                content.userInfo = ["type": "twilio-missed-call", "From": fromStr]
                if let to = to { content.userInfo["To"] = to }
            }
            content.title = userName ?? "Unknown Caller"
            content.body = NSLocalizedString("notification_missed_call_body", comment: "")
            let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
            let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: trigger)
            notificationCenter.add(request) { _ in }
        }
    }
}

// MARK: - UNUserNotificationCenterDelegate
extension FlutterTwilioPlugin: UNUserNotificationCenterDelegate {
    public func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse, withCompletionHandler completionHandler: @escaping () -> Void) {
        let userInfo = response.notification.request.content.userInfo
        if let type = userInfo["type"] as? String, type == "twilio-missed-call" {
            emitter.emit(.returningCall)
        }
        completionHandler()
    }

    public func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification, withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        let userInfo = notification.request.content.userInfo
        if let type = userInfo["type"] as? String, type == "twilio-missed-call" {
            completionHandler([.alert])
        }
    }
}
