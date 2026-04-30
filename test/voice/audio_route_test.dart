import 'package:flutter_test/flutter_test.dart';
import 'package:twilio_voice_sms/src/voice/generated/voice_api.g.dart' as pigeon;
import 'package:twilio_voice_sms/src/voice/models/audio_route.dart';

void main() {
  group('AudioRoute.fromPigeon', () {
    test('maps every pigeon value', () {
      expect(AudioRoute.fromPigeon(pigeon.AudioRoute.earpiece), AudioRoute.earpiece);
      expect(AudioRoute.fromPigeon(pigeon.AudioRoute.speaker), AudioRoute.speaker);
      expect(AudioRoute.fromPigeon(pigeon.AudioRoute.bluetooth), AudioRoute.bluetooth);
      expect(AudioRoute.fromPigeon(pigeon.AudioRoute.wired), AudioRoute.wired);
    });
  });

  group('AudioRoute.toPigeon', () {
    test('round-trips through fromPigeon', () {
      for (final r in AudioRoute.values) {
        expect(AudioRoute.fromPigeon(r.toPigeon()), r);
      }
    });
  });

  group('AudioRouteInfo.fromDto', () {
    test('copies all fields', () {
      final dto = pigeon.AudioRouteInfo(
        route: pigeon.AudioRoute.bluetooth,
        isActive: true,
        deviceName: 'AirPods Pro',
      );
      final info = AudioRouteInfo.fromDto(dto);
      expect(info.route, AudioRoute.bluetooth);
      expect(info.isActive, isTrue);
      expect(info.deviceName, 'AirPods Pro');
    });

    test('preserves null deviceName', () {
      final dto = pigeon.AudioRouteInfo(
        route: pigeon.AudioRoute.earpiece,
        isActive: false,
      );
      expect(AudioRouteInfo.fromDto(dto).deviceName, isNull);
    });
  });
}
