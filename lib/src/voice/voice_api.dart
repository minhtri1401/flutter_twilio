import 'models/active_call.dart';
import 'models/audio_route.dart';
import 'models/call.dart';

/// Public voice surface. Implemented by [VoiceImpl] over the generated
/// Pigeon host API.
abstract class VoiceApi {
  Future<void> setAccessToken(String token);
  Future<void> register();
  Future<void> unregister();

  Future<ActiveCall> place({
    required String to,
    String? from,
    Map<String, String>? extra,
  });

  Future<void> answer();
  Future<void> reject();
  Future<void> hangUp();

  Future<void> setMuted(bool muted);
  Future<void> setOnHold(bool onHold);
  Future<void> sendDigits(String digits);

  /// Selects the active audio output route for the current (or next) call.
  /// Throws [BluetoothUnavailableException] / [WiredUnavailableException]
  /// when the requested device class is absent, or
  /// [AudioRouteFailedException] for other native audio-session failures.
  Future<void> setAudioRoute(AudioRoute route);

  Future<AudioRoute> getAudioRoute();

  /// Enumerates available output routes with their active state and a
  /// human-readable [AudioRouteInfo.deviceName] (display-only) for non-built-in
  /// devices. Built-in `earpiece` and `speaker` are always present.
  Future<List<AudioRouteInfo>> listAudioRoutes();

  Future<ActiveCall?> getActiveCall();
  Future<bool> hasMicPermission();
  Future<bool> requestMicPermission();

  /// Android: brings the host activity to the foreground via the launcher
  /// intent. iOS: documented no-op (CallKit handles foregrounding).
  Future<void> bringAppToForeground();

  /// Backwards-compatible shim. New code should use [setAudioRoute].
  @Deprecated(
    'Use setAudioRoute(AudioRoute.speaker) / setAudioRoute(AudioRoute.earpiece). '
    'Will be removed in 0.3.0.',
  )
  Future<void> setSpeaker(bool onSpeaker);

  /// Broadcasts every call event. Errors surface as `onError` on the stream
  /// carrying a [VoiceException] subtype.
  Stream<Call> get events;
}
