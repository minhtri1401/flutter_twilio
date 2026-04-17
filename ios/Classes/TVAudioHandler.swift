import Foundation
import AVFoundation
import TwilioVoice

/// Plain Swift handler exposing typed audio-routing methods for the Pigeon
/// [VoiceHostApi]. Back-ends `setSpeaker(...)` via AVAudioSession override.
final class TVAudioHandler {
    private let state: TVPluginState
    private let emitter: TVEventEmitter
    private let audioDevice: DefaultAudioDevice

    init(state: TVPluginState, emitter: TVEventEmitter, audioDevice: DefaultAudioDevice) {
        self.state = state
        self.emitter = emitter
        self.audioDevice = audioDevice
    }

    /// Reads the current AVAudioSession route.
    var isSpeakerOn: Bool {
        for output in AVAudioSession.sharedInstance().currentRoute.outputs {
            if output.portType == .builtInSpeaker { return true }
        }
        return false
    }

    /// Enables / disables the built-in speaker for the current call.
    /// Throws [FlutterTwilioError] if there is no active call routing to flip.
    func setSpeaker(_ onSpeaker: Bool) throws {
        toggleAudioRoute(toSpeaker: onSpeaker)
        state.isSpeakerOn = onSpeaker
        emitter.emit(onSpeaker ? .speakerOn : .speakerOff)
    }

    /// Internal helper re-used by the plugin on `callDidConnect` to force
    /// speaker-off at call start.
    func toggleAudioRoute(toSpeaker: Bool) {
        audioDevice.block = {
            DefaultAudioDevice.DefaultAVAudioSessionConfigurationBlock()
            do {
                if toSpeaker {
                    try AVAudioSession.sharedInstance().overrideOutputAudioPort(.speaker)
                } else {
                    try AVAudioSession.sharedInstance().overrideOutputAudioPort(.none)
                }
            } catch {
                NSLog("TVAudioHandler toggleAudioRoute error: \(error.localizedDescription)")
            }
        }
        audioDevice.block()
    }
}
