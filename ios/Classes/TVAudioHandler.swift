import AVFoundation
import Foundation
import TwilioVoice

/// Thin shim around `TVAudioRouter`. Owns the AVAudioSession route override
/// for the active call and emits `audioRouteChanged` events to Dart.
final class TVAudioHandler {
    private let state: TVPluginState
    private let emitter: TVEventEmitter
    private let router: TVAudioRouter

    init(state: TVPluginState, emitter: TVEventEmitter, audioDevice: DefaultAudioDevice) {
        self.state = state
        self.emitter = emitter
        self.router = TVAudioRouter(audioDevice: audioDevice)
    }

    var current: AudioRoute { router.current }

    /// Backwards-compat shortcut for `currentRoute == .speaker`.
    var isSpeakerOn: Bool { router.current == .speaker }

    func list() -> [AudioRouteInfo] { router.list() }

    /// Sets the route; emits `audioRouteChanged` on success.
    func setAudioRoute(_ route: AudioRoute) throws {
        try router.set(route)
        state.isSpeakerOn = (route == .speaker)
        emitter.emit(.audioRouteChanged, audioRoute: route)
    }

    /// Deprecated — kept for the cycle. Forwards to setAudioRoute and
    /// also emits the legacy speakerOn/speakerOff event.
    func setSpeakerLegacy(_ on: Bool) throws {
        try setAudioRoute(on ? .speaker : .earpiece)
        emitter.emit(on ? .speakerOn : .speakerOff)
    }

    /// Internal helper used by the plugin on `callDidConnect` to force a
    /// default route at call start. Silently logs failures.
    func toggleAudioRoute(toSpeaker: Bool) {
        try? router.set(toSpeaker ? .speaker : .earpiece)
    }
}
