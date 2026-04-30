import Foundation

struct TVVoiceConfig {
    var ringbackAssetKey: String?
    var connectToneAssetKey: String?
    var disconnectToneAssetKey: String?
    var playRingback: Bool
    var playConnectTone: Bool
    var playDisconnectTone: Bool
    var bringAppToForegroundOnAnswer: Bool
    var bringAppToForegroundOnEnd: Bool

    static let defaultConfig = TVVoiceConfig(
        ringbackAssetKey: nil,
        connectToneAssetKey: nil,
        disconnectToneAssetKey: nil,
        playRingback: true,
        playConnectTone: true,
        playDisconnectTone: true,
        bringAppToForegroundOnAnswer: true,
        bringAppToForegroundOnEnd: false
    )
}
