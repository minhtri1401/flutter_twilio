import 'package:flutter/foundation.dart';

import 'sms/sms_api.dart';
import 'sms/sms_client.dart';
import 'voice/voice_api.dart';
import 'voice/voice_config.dart';
import 'voice/voice_impl.dart';

/// Unified facade: voice + SMS behind one singleton.
///
/// ## Initialization
///
/// `init` is split along the two subsystems' authentication models:
///
/// - **Voice** authenticates each session with a short-lived Twilio Access
///   Token (JWT) passed separately to [VoiceApi.setAccessToken]. It does
///   **not** need account-level credentials — `init()` with no arguments is
///   enough to enable `.voice`.
/// - **SMS** calls the Twilio REST API directly and needs your Account SID
///   + Auth Token. Omit them and any call to `.sms` throws [StateError].
///
/// ```dart
/// // Voice-only (no SMS): voice works, .sms throws if accessed.
/// FlutterTwilio.instance.init();
///
/// // Voice + SMS:
/// FlutterTwilio.instance.init(
///   accountSid: 'AC...',
///   authToken: '...',
///   twilioNumber: '+1...', // default "from" for sms.send()
/// );
///
/// // SMS-only is also fine — voice is built but simply unused.
/// FlutterTwilio.instance.init(
///   accountSid: 'AC...',
///   authToken: '...',
/// );
/// ```
///
/// Credentials live in memory only; the plugin never persists them.
class FlutterTwilio {
  FlutterTwilio._();

  static final FlutterTwilio instance = FlutterTwilio._();

  String? _accountSid;
  String? _authToken;
  String? _twilioNumber;
  VoiceImpl? _voice;
  SmsClient? _sms;

  /// Sets / rotates credentials.
  ///
  /// Both [accountSid] and [authToken] are optional. Pass them if and only if
  /// you intend to use SMS. Passing one without the other throws
  /// [ArgumentError] — they're both halves of the same Basic-auth pair.
  ///
  /// Safe to call more than once. The existing `SmsClient` is closed and a
  /// fresh one created when credentials change.
  void init({
    String? accountSid,
    String? authToken,
    String? twilioNumber,
    String? ringbackAsset,
    String? connectToneAsset,
    String? disconnectToneAsset,
    bool playRingback = true,
    bool playConnectTone = false,
    bool playDisconnectTone = false,
    bool bringAppToForegroundOnAnswer = true,
    bool bringAppToForegroundOnEnd = false,
  }) {
    if ((accountSid == null) != (authToken == null)) {
      throw ArgumentError(
        'accountSid and authToken must be provided together (both or neither). '
        'For voice-only usage, omit both.',
      );
    }

    _accountSid = accountSid;
    _authToken = authToken;
    _twilioNumber = twilioNumber;

    _sms?.close();
    _sms = (accountSid != null && authToken != null)
        ? SmsClient(
            accountSid: accountSid,
            authToken: authToken,
            defaultFrom: twilioNumber,
          )
        : null;

    _voice ??= VoiceImpl();

    final config = VoiceConfig(
      ringbackAsset: ringbackAsset,
      connectToneAsset: connectToneAsset,
      disconnectToneAsset: disconnectToneAsset,
      playRingback: playRingback,
      playConnectTone: playConnectTone,
      playDisconnectTone: playDisconnectTone,
      bringAppToForegroundOnAnswer: bringAppToForegroundOnAnswer,
      bringAppToForegroundOnEnd: bringAppToForegroundOnEnd,
    );
    // Best-effort: native side may not be attached in unit tests.
    () async {
      try {
        await (_voice as VoiceImpl).configure(config);
      } catch (_) {
        // Surface real failures via the voice event stream during real runs;
        // unit tests without a platform channel intentionally swallow.
      }
    }();
  }

  VoiceApi get voice =>
      _voice ??
      (throw StateError(
          'FlutterTwilio.init() must be called before accessing .voice'));

  SmsApi get sms =>
      _sms ??
      (throw StateError(
          'FlutterTwilio SMS is not initialized. Pass accountSid and '
          'authToken to FlutterTwilio.instance.init(...) before accessing .sms.'));

  /// Clears all in-memory state (credentials, voice stream, sms client).
  /// Intended for tests — production code should just call [init] again to
  /// rotate credentials.
  @visibleForTesting
  void resetForTesting() {
    _accountSid = null;
    _authToken = null;
    _twilioNumber = null;
    _sms?.close();
    _sms = null;
    _voice?.dispose();
    _voice = null;
  }

  @visibleForTesting
  String? get accountSidForTesting => _accountSid;

  @visibleForTesting
  String? get twilioNumberForTesting => _twilioNumber;

  @visibleForTesting
  String? get authTokenForTesting => _authToken;
}
