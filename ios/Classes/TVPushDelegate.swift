import Foundation
import UIKit
import PushKit
import TwilioVoice

// MARK: - PKPushRegistryDelegate
extension FlutterTwilioPlugin: PKPushRegistryDelegate {
    public func pushRegistry(_ registry: PKPushRegistry, didUpdate credentials: PKPushCredentials, for type: PKPushType) {
        guard type == .voIP else { return }
        registrationHandler.storeDeviceToken(credentials.token)
    }

    public func pushRegistry(_ registry: PKPushRegistry, didInvalidatePushTokenFor type: PKPushType) {
        guard type == .voIP else { return }
        registrationHandler.invalidateDeviceToken()
    }

    public func pushRegistry(_ registry: PKPushRegistry, didReceiveIncomingPushWith payload: PKPushPayload, for type: PKPushType) {
        if type == .voIP {
            TwilioVoiceSDK.handleNotification(payload.dictionaryPayload, delegate: self, delegateQueue: nil)
        }
    }

    public func pushRegistry(_ registry: PKPushRegistry, didReceiveIncomingPushWith payload: PKPushPayload, for type: PKPushType, completion: @escaping () -> Void) {
        if type == .voIP {
            TwilioVoiceSDK.handleNotification(payload.dictionaryPayload, delegate: self, delegateQueue: nil)
        }
        if let version = Float(UIDevice.current.systemVersion), version < 13.0 {
            callHandler.incomingPushCompletionCallback = completion
        } else {
            completion()
        }
    }
}
