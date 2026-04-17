import Foundation
import Flutter

/// Bridges native call-lifecycle events into Flutter via Pigeon's
/// [VoiceFlutterApi]. Replaces the legacy string-based FlutterEventChannel.
///
/// The emitter holds a weak reference to an active-call snapshot provider
/// so consumers (CallKit delegate, PushKit delegate, Call.Delegate, …) don't
/// have to build DTOs themselves for every emit.
final class TVEventEmitter {
    private let tag = "TVEventEmitter"

    /// Cached Pigeon-generated Flutter API client. Nil until the plugin is
    /// attached to the engine.
    private var api: VoiceFlutterApi?

    /// Pulls a fresh `ActiveCallDto` snapshot from whatever owns the current
    /// call state — usually `FlutterTwilioPlugin`.
    var activeCallProvider: (() -> ActiveCallDto?)?

    func attach(api: VoiceFlutterApi) {
        self.api = api
    }

    func detach() {
        self.api = nil
    }

    // MARK: - Typed emitters

    /// Emit a typed call event. If `activeCall` is not supplied, a snapshot is
    /// pulled from [activeCallProvider].
    func emit(
        _ type: CallEventType,
        activeCall: ActiveCallDto? = nil,
        error: CallErrorDto? = nil
    ) {
        guard let api = api else { return }
        let snap = activeCall ?? activeCallProvider?()
        let dto = CallEventDto(type: type, activeCall: snap, error: error)
        DispatchQueue.main.async {
            api.onCallEvent(event: dto) { _ in /* delivery result ignored */ }
        }
    }

    /// Emit an error event via [CallEventType.error].
    func emitError(
        _ code: String,
        _ message: String,
        _ details: [String: Any?] = [:]
    ) {
        // `CallErrorDto.details` is a `[String?: Any?]?`, so widen the key type.
        let widened: [String?: Any?] = details.reduce(into: [String?: Any?]()) { acc, pair in
            acc[pair.key] = pair.value
        }
        let err = CallErrorDto(code: code, message: message, details: widened)
        guard let api = api else { return }
        let dto = CallEventDto(type: .error, activeCall: activeCallProvider?(), error: err)
        DispatchQueue.main.async {
            api.onCallEvent(event: dto) { _ in }
        }
    }
}
