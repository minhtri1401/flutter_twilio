import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:twilio_voice_sms/src/voice/errors.dart';

PlatformException _ex(
  String code, [
  Map<String, Object?>? details,
]) =>
    PlatformException(code: code, message: '$code msg', details: details);

void main() {
  group('VoiceException.fromPigeon', () {
    test('not_initialized → VoiceNotInitializedException', () {
      final e = VoiceException.fromPigeon(_ex('not_initialized'));
      expect(e, isA<VoiceNotInitializedException>());
      expect(e.code, 'not_initialized');
    });

    test('missing_permission carries permission detail', () {
      final e = VoiceException.fromPigeon(
          _ex('missing_permission', {'permission': 'RECORD_AUDIO'}));
      expect(e, isA<VoicePermissionDeniedException>());
      expect((e as VoicePermissionDeniedException).permission, 'RECORD_AUDIO');
    });

    test('missing_permission without permission detail defaults to "unknown"',
        () {
      final e = VoiceException.fromPigeon(_ex('missing_permission'));
      expect((e as VoicePermissionDeniedException).permission, 'unknown');
    });

    test('invalid_argument → VoiceInvalidArgumentException', () {
      final e = VoiceException.fromPigeon(_ex('invalid_argument'));
      expect(e, isA<VoiceInvalidArgumentException>());
    });

    test('invalid_token → VoiceInvalidTokenException', () {
      final e = VoiceException.fromPigeon(_ex('invalid_token'));
      expect(e, isA<VoiceInvalidTokenException>());
    });

    test('no_active_call → VoiceNoActiveCallException', () {
      final e = VoiceException.fromPigeon(_ex('no_active_call'));
      expect(e, isA<VoiceNoActiveCallException>());
    });

    test('call_already_active → VoiceCallAlreadyActiveException', () {
      final e = VoiceException.fromPigeon(_ex('call_already_active'));
      expect(e, isA<VoiceCallAlreadyActiveException>());
    });

    test('twilio_sdk_error parses twilio fields', () {
      final e = VoiceException.fromPigeon(
          _ex('twilio_sdk_error', {'twilioCode': 31205, 'twilioDomain': 'SDK'}));
      expect(e, isA<TwilioSdkException>());
      expect((e as TwilioSdkException).twilioCode, 31205);
      expect(e.twilioDomain, 'SDK');
    });

    test('twilio_sdk_error with missing twilio fields yields nulls', () {
      final e = VoiceException.fromPigeon(_ex('twilio_sdk_error'));
      expect((e as TwilioSdkException).twilioCode, isNull);
      expect(e.twilioDomain, isNull);
    });

    test('audio_session_error → VoiceAudioSessionException', () {
      final e = VoiceException.fromPigeon(_ex('audio_session_error'));
      expect(e, isA<VoiceAudioSessionException>());
    });

    test('registration_error → VoiceRegistrationException', () {
      final e = VoiceException.fromPigeon(_ex('registration_error'));
      expect(e, isA<VoiceRegistrationException>());
    });

    test('connection_error → VoiceConnectionException', () {
      final e = VoiceException.fromPigeon(_ex('connection_error'));
      expect(e, isA<VoiceConnectionException>());
    });

    test('unknown code falls back to base VoiceException', () {
      final e = VoiceException.fromPigeon(_ex('something_new'));
      expect(e, isA<VoiceException>());
      expect(e.code, 'something_new');
      expect(e.runtimeType, VoiceException);
    });

    test('details are passed through even for unknown codes', () {
      final e =
          VoiceException.fromPigeon(_ex('anything', {'extra': 42}));
      expect(e.details['extra'], 42);
    });
  });

  test('fromCodeMessageDetails matches fromPigeon for the same input', () {
    final viaPigeon = VoiceException.fromPigeon(
        _ex('twilio_sdk_error', {'twilioCode': 1, 'twilioDomain': 'd'}));
    final direct = VoiceException.fromCodeMessageDetails(
      'twilio_sdk_error',
      'twilio_sdk_error msg',
      {'twilioCode': 1, 'twilioDomain': 'd'},
    );
    expect(direct.runtimeType, viaPigeon.runtimeType);
    expect(direct.code, viaPigeon.code);
    expect((direct as TwilioSdkException).twilioCode,
        (viaPigeon as TwilioSdkException).twilioCode);
  });
}
