import Foundation

enum CallPhase {
    case outgoingConnecting, incomingRinging, connected, disconnected, error
}

final class TVRingbackController {

    private let player: TVTonePlayer
    private let enabled: Bool
    private let customAssetKey: String?
    private var ringing = false

    init(player: TVTonePlayer, enabled: Bool, customAssetKey: String?) {
        self.player = player
        self.enabled = enabled
        self.customAssetKey = customAssetKey
    }

    func onCallEvent(_ phase: CallPhase) {
        switch phase {
        case .outgoingConnecting:
            guard enabled, !ringing else { return }
            ringing = true
            player.play(
                flutterAssetKey: customAssetKey,
                bundledResource: "ringback_na",
                looping: true
            )
        case .incomingRinging:
            return
        case .connected, .disconnected, .error:
            if ringing {
                ringing = false
                player.stop()
            }
        }
    }
}
