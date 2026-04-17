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
    /// Throws [FlutterTwilioError.audio_session_error] if `AVAudioSession`
    /// refuses the port override.
    func setSpeaker(_ onSpeaker: Bool) throws {
        // Attempt the route change synchronously so we can surface failures to
        // Dart as `audio_session_error`. The `audioDevice.block` is still set
        // so any Twilio-initiated audio-session re-configuration reapplies the
        // same override.
        do {
            if onSpeaker {
                try AVAudioSession.sharedInstance().overrideOutputAudioPort(.speaker)
            } else {
                try AVAudioSession.sharedInstance().overrideOutputAudioPort(.none)
            }
        } catch {
            let ns = error as NSError
            throw FlutterTwilioError.of(
                "audio_session_error",
                ns.localizedDescription,
                ["nativeMessage": ns.localizedDescription]
            )
        }
        // Re-install the block so Twilio's own audio re-configuration preserves
        // the route we just picked.
        audioDevice.block = {
            DefaultAudioDevice.DefaultAVAudioSessionConfigurationBlock()
            do {
                if onSpeaker {
                    try AVAudioSession.sharedInstance().overrideOutputAudioPort(.speaker)
                } else {
                    try AVAudioSession.sharedInstance().overrideOutputAudioPort(.none)
                }
            } catch {
                NSLog("TVAudioHandler audioDevice.block route error: \(error.localizedDescription)")
            }
        }
        state.isSpeakerOn = onSpeaker
        emitter.emit(onSpeaker ? .speakerOn : .speakerOff)
    }

    /// Internal helper re-used by the plugin on `callDidConnect` to force
    /// speaker-off at call start. Silently logs any failures — if the route
    /// change is part of call setup we can't meaningfully throw from here.
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
