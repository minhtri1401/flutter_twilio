import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_twilio/src/voice/errors.dart';

void main() {
  group('VoiceException.fromPigeon', () {
    PlatformException ex(String code, [Map<String, Object?>? details]) =>
        PlatformException(code: code, message: '$code msg', details: details);

    test('maps not_initialized → VoiceNotInitializedException', () {
      final e = VoiceException.fromPigeon(ex('not_initialized'));
      expect(e, isA<VoiceNotInitializedException>());
      expect(e.code, 'not_initialized');
    });

    test('maps missing_permission with permission detail', () {
      final e = VoiceException.fromPigeon(
          ex('missing_permission', {'permission': 'RECORD_AUDIO'}));
      expect(e, isA<VoicePermissionDeniedException>());
      expect((e as VoicePermissionDeniedException).permission, 'RECORD_AUDIO');
    });

    test('maps twilio_sdk_error with twilio fields', () {
      final e = VoiceException.fromPigeon(
          ex('twilio_sdk_error', {'twilioCode': 31205, 'twilioDomain': 'SDK'}));
      expect(e, isA<TwilioSdkException>());
      expect((e as TwilioSdkException).twilioCode, 31205);
      expect(e.twilioDomain, 'SDK');
    });

    test('unknown code falls back to base VoiceException', () {
      final e = VoiceException.fromPigeon(ex('something_new'));
      expect(e, isA<VoiceException>());
      expect(e.code, 'something_new');
      expect(e.runtimeType, VoiceException);
    });
  });
}
