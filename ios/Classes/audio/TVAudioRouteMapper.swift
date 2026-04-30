import AVFoundation
import Foundation

enum TVAudioRouteMapper {

    static func fromPort(_ port: AVAudioSession.Port) -> AudioRoute {
        switch port {
        case .builtInReceiver: return .earpiece
        case .builtInSpeaker: return .speaker
        case .bluetoothHFP, .bluetoothA2DP, .bluetoothLE: return .bluetooth
        case .headphones, .usbAudio, .lineOut, .HDMI, .airPlay: return .wired
        default: return .earpiece
        }
    }

    static func currentRoute() -> AudioRoute {
        let outs = AVAudioSession.sharedInstance().currentRoute.outputs
        guard let primary = outs.first else { return .earpiece }
        return fromPort(primary.portType)
    }

    static func listAvailable() -> [AudioRouteInfo] {
        let session = AVAudioSession.sharedInstance()
        let outs = session.currentRoute.outputs
        let current = currentRoute()

        var hasBT = false
        var hasWired = false
        var btName: String? = nil
        var wiredName: String? = nil

        for out in outs {
            let r = fromPort(out.portType)
            if r == .bluetooth { hasBT = true; btName = btName ?? out.portName }
            if r == .wired { hasWired = true; wiredName = wiredName ?? out.portName }
        }
        for desc in session.availableInputs ?? [] {
            if [.bluetoothHFP, .bluetoothLE].contains(desc.portType) {
                hasBT = true
                if btName == nil { btName = desc.portName }
            }
        }

        var out: [AudioRouteInfo] = []
        out.append(AudioRouteInfo(route: .earpiece, isActive: current == .earpiece, deviceName: nil))
        out.append(AudioRouteInfo(route: .speaker, isActive: current == .speaker, deviceName: nil))
        if hasBT {
            out.append(AudioRouteInfo(route: .bluetooth, isActive: current == .bluetooth, deviceName: btName))
        }
        if hasWired {
            out.append(AudioRouteInfo(route: .wired, isActive: current == .wired, deviceName: wiredName))
        }
        return out
    }
}
