import 'package:flutter_test/flutter_test.dart';
import 'package:twilio_voice_sms/src/voice/generated/voice_api.g.dart';
import 'package:twilio_voice_sms/src/voice/models/active_call.dart';
import 'package:twilio_voice_sms/src/voice/models/call_event.dart';

void main() {
  group('CallEvent', () {
    test('maps CallEventType.connected to CallEvent.connected', () {
      expect(CallEvent.fromPigeon(CallEventType.connected),
          CallEvent.connected);
    });

    test('every CallEventType has a matching CallEvent', () {
      for (final type in CallEventType.values) {
        expect(() => CallEvent.fromPigeon(type), returnsNormally,
            reason: 'missing mapping for $type');
      }
    });
  });

  group('ActiveCall', () {
    test('fromDto preserves fields', () {
      final dto = ActiveCallDto(
        sid: 'CA123',
        from: '+100',
        to: '+200',
        direction: CallDirection.outgoing,
        startedAt: 1700000000000,
        isMuted: false,
        isOnHold: false,
        isOnSpeaker: true,
        currentRoute: AudioRoute.speaker,
        customParameters: {'x': 'y'},
      );
      final c = ActiveCall.fromDto(dto);
      expect(c.sid, 'CA123');
      expect(c.to, '+200');
      expect(c.direction, CallDirection.outgoing);
      expect(c.isOnSpeaker, isTrue);
      expect(c.customParameters, {'x': 'y'});
    });

    test('fromDto handles null customParameters', () {
      final dto = ActiveCallDto(
        sid: 'CA1',
        from: '+1',
        to: '+2',
        direction: CallDirection.incoming,
        startedAt: 0,
        isMuted: false,
        isOnHold: false,
        isOnSpeaker: false,
        currentRoute: AudioRoute.earpiece,
      );
      expect(ActiveCall.fromDto(dto).customParameters, isEmpty);
    });
  });
}
