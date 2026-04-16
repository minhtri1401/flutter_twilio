import 'package:flutter/foundation.dart';

import 'sms/sms_api.dart';
import 'sms/sms_client.dart';
import 'voice/voice_api.dart';
import 'voice/voice_impl.dart';

/// Unified facade: shared credentials + access to `voice` and `sms`.
///
/// Usage:
/// ```dart
/// await FlutterTwilio.instance.init(
///   accountSid: 'AC...',
///   authToken: '...',
///   twilioNumber: '+1...',
/// );
///
/// await FlutterTwilio.instance.voice.setAccessToken('...');
/// await FlutterTwilio.instance.sms.send(to: '+1...', body: 'hi');
/// ```
class FlutterTwilio {
  FlutterTwilio._();

  static final FlutterTwilio instance = FlutterTwilio._();

  @visibleForTesting
  factory FlutterTwilio.newForTesting() = FlutterTwilio._;

  String? _accountSid;
  String? _authToken;
  String? _twilioNumber;
  VoiceImpl? _voice;
  SmsClient? _sms;

  void init({
    required String accountSid,
    required String authToken,
    String? twilioNumber,
  }) {
    _accountSid = accountSid;
    _authToken = authToken;
    _twilioNumber = twilioNumber;

    _sms?.close();
    _sms = SmsClient(
      accountSid: accountSid,
      authToken: authToken,
      defaultFrom: twilioNumber,
    );
    _voice ??= VoiceImpl();
  }

  VoiceApi get voice =>
      _voice ??
      (throw StateError(
          'FlutterTwilio.init() must be called before accessing .voice'));

  SmsApi get sms =>
      _sms ??
      (throw StateError(
          'FlutterTwilio.init() must be called before accessing .sms'));

  @visibleForTesting
  String? get accountSidForTesting => _accountSid;

  @visibleForTesting
  String? get twilioNumberForTesting => _twilioNumber;

  @visibleForTesting
  String? get authTokenForTesting => _authToken;
}
