import Foundation
import AVFoundation

/// Plain Swift handler for microphone permission checks.
final class TVPermissionHandler {

    func hasMicPermission() -> Bool {
        return AVAudioSession.sharedInstance().recordPermission == .granted
    }

    /// Resolves once the OS record-permission prompt finishes. If the user has
    /// already decided, the completion fires synchronously.
    func requestMicPermission(completion: @escaping (Bool) -> Void) {
        switch AVAudioSession.sharedInstance().recordPermission {
        case .granted:
            completion(true)
        case .denied:
            completion(false)
        case .undetermined:
            AVAudioSession.sharedInstance().requestRecordPermission { granted in
                completion(granted)
            }
        @unknown default:
            completion(false)
        }
    }
}
