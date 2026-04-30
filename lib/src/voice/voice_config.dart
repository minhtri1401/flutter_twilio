import 'generated/voice_api.g.dart' as pigeon;

/// Voice subsystem configuration. Stashed by [FlutterTwilio.init] and
/// pushed to the native side via the Pigeon `configure` call.
///
/// Defaults are applied here in the public Dart wrapper. The Pigeon DTO
/// requires explicit values for the bool fields — keep this wrapper as the
/// single source of truth for "what does init() with no args mean".
class VoiceConfig {
  const VoiceConfig({
    this.ringbackAsset,
    this.connectToneAsset,
    this.disconnectToneAsset,
    this.playRingback = true,
    this.playConnectTone = false,
    this.playDisconnectTone = false,
    this.bringAppToForegroundOnAnswer = true,
    this.bringAppToForegroundOnEnd = false,
  });

  /// Flutter asset key (e.g. `'assets/sounds/ring.ogg'`). `null` ⇒ use the
  /// bundled default tone.
  final String? ringbackAsset;
  final String? connectToneAsset;
  final String? disconnectToneAsset;

  final bool playRingback;
  final bool playConnectTone;
  final bool playDisconnectTone;

  /// Android: bring the host activity to the foreground when the user taps
  /// **Accept** on the incoming-call notification. Default `true`. iOS: no-op
  /// (CallKit foregrounds automatically).
  final bool bringAppToForegroundOnAnswer;

  /// Android: bring the host activity to the foreground when a call ends.
  /// Default `false`. iOS: no-op.
  final bool bringAppToForegroundOnEnd;

  pigeon.VoiceConfig toPigeon() => pigeon.VoiceConfig(
        ringbackAssetPath: ringbackAsset,
        connectToneAssetPath: connectToneAsset,
        disconnectToneAssetPath: disconnectToneAsset,
        playRingback: playRingback,
        playConnectTone: playConnectTone,
        playDisconnectTone: playDisconnectTone,
        bringAppToForegroundOnAnswer: bringAppToForegroundOnAnswer,
        bringAppToForegroundOnEnd: bringAppToForegroundOnEnd,
      );
}
