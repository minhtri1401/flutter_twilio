import Flutter
import AVFoundation

// MARK: - Permission helpers
extension SwiftTwilioVoicePlugin {
    func checkRecordPermission(completion: @escaping (_ permissionGranted: Bool) -> Void) {
        switch AVAudioSession.sharedInstance().recordPermission {
        case .granted:
            completion(true)
        case .denied:
            completion(false)
        case .undetermined:
            AVAudioSession.sharedInstance().requestRecordPermission { completion($0) }
        default:
            completion(false)
        }
    }

    func requestMicPermission(result: @escaping FlutterResult) {
        switch AVAudioSession.sharedInstance().recordPermission {
        case .granted:
            result(true)
        case .denied:
            result(false)
        case .undetermined:
            AVAudioSession.sharedInstance().requestRecordPermission { result($0) }
        @unknown default:
            result(false)
        }
    }

    func handleShowNotifications(args: [String: AnyObject], result: FlutterResult) {
        guard let show = args["show"] as? Bool else { return }
        let prefsShow = UserDefaults.standard.optionalBool(forKey: "show-notifications") ?? true
        if show != prefsShow {
            UserDefaults.standard.setValue(show, forKey: "show-notifications")
        }
        result(true)
    }
}
