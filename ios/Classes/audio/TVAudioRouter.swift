import AVFoundation
import Foundation
import TwilioVoice

final class TVAudioRouter {

    private let audioDevice: DefaultAudioDevice

    init(audioDevice: DefaultAudioDevice) {
        self.audioDevice = audioDevice
    }

    var current: AudioRoute { TVAudioRouteMapper.currentRoute() }

    func list() -> [AudioRouteInfo] { TVAudioRouteMapper.listAvailable() }

    func set(_ route: AudioRoute) throws {
        let session = AVAudioSession.sharedInstance()
        switch route {
        case .earpiece:
            try applyOverride(.none, session: session)
        case .speaker:
            try applyOverride(.speaker, session: session)
        case .bluetooth:
            guard hasBluetoothDevice(session: session) else {
                throw FlutterTwilioError.bluetoothUnavailable("No Bluetooth audio device connected")
            }
            try session.setCategory(
                .playAndRecord,
                mode: .voiceChat,
                options: [.allowBluetooth, .allowBluetoothA2DP]
            )
            try applyOverride(.none, session: session)
        case .wired:
            guard hasWiredDevice(session: session) else {
                throw FlutterTwilioError.wiredUnavailable("No wired audio device connected")
            }
            try applyOverride(.none, session: session)
        }
    }

    private func applyOverride(_ port: AVAudioSession.PortOverride, session: AVAudioSession) throws {
        do {
            try session.overrideOutputAudioPort(port)
        } catch {
            let ns = error as NSError
            throw FlutterTwilioError.audioRouteFailed(ns.localizedDescription)
        }
        // Re-install Twilio's audio block so its reconfiguration preserves our override.
        audioDevice.block = {
            DefaultAudioDevice.DefaultAVAudioSessionConfigurationBlock()
            try? AVAudioSession.sharedInstance().overrideOutputAudioPort(port)
        }
    }

    private func hasBluetoothDevice(session: AVAudioSession) -> Bool {
        let inputs = session.availableInputs ?? []
        if inputs.contains(where: { [.bluetoothHFP, .bluetoothLE].contains($0.portType) }) {
            return true
        }
        return session.currentRoute.outputs.contains { out in
            [.bluetoothHFP, .bluetoothA2DP, .bluetoothLE].contains(out.portType)
        }
    }

    private func hasWiredDevice(session: AVAudioSession) -> Bool {
        return session.currentRoute.outputs.contains { out in
            [.headphones, .usbAudio, .lineOut, .HDMI, .airPlay].contains(out.portType)
        }
    }
}
