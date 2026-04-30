import AVFoundation
import Flutter
import Foundation

/// Plays a single tone (looping or one-shot). Source can be a Flutter asset
/// key (resolved via FlutterDartProject) or a bundled `.caf` resource shipped
/// with this plugin under `Resources/`.
class TVTonePlayer {

    private var player: AVAudioPlayer?
    /// Serial queue used to serialize play/stop access from different threads
    /// (Twilio SDK delegate callbacks vs. Pigeon method-channel calls).
    private let queue = DispatchQueue(label: "com.dev.flutter_twilio.tone.player")

    func play(flutterAssetKey: String?, bundledResource: String, looping: Bool) {
        queue.sync {
            _stop()
            guard let url = resolveURL(flutterAssetKey: flutterAssetKey, bundledResource: bundledResource) else {
                NSLog("TVTonePlayer: tone asset not found (key=\(flutterAssetKey ?? "nil"), bundled=\(bundledResource))")
                return
            }
            do {
                let p = try AVAudioPlayer(contentsOf: url)
                p.numberOfLoops = looping ? -1 : 0
                p.prepareToPlay()
                p.play()
                player = p
            } catch {
                NSLog("TVTonePlayer: playback failed: \(error.localizedDescription)")
            }
        }
    }

    func stop() {
        queue.sync { _stop() }
    }

    /// Unsynchronized stop — must only be called from within `queue`.
    private func _stop() {
        player?.stop()
        player = nil
    }

    private func resolveURL(flutterAssetKey: String?, bundledResource: String) -> URL? {
        if let key = flutterAssetKey {
            let resolvedKey = FlutterDartProject.lookupKey(forAsset: key)
            if let path = Bundle.main.path(forResource: resolvedKey, ofType: nil) {
                return URL(fileURLWithPath: path)
            }
            return nil
        }
        let pluginBundle = Bundle(for: type(of: self))
        if let url = pluginBundle.url(forResource: bundledResource, withExtension: "caf") {
            return url
        }
        if let resourcesPath = pluginBundle.path(forResource: "twilio_voice_sms", ofType: "bundle"),
           let resourcesBundle = Bundle(path: resourcesPath),
           let url = resourcesBundle.url(forResource: bundledResource, withExtension: "caf") {
            return url
        }
        return nil
    }
}
