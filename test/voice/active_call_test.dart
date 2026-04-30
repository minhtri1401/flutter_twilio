import 'package:flutter_test/flutter_test.dart';
import 'package:twilio_voice_sms/src/voice/generated/voice_api.g.dart' as pigeon;
import 'package:twilio_voice_sms/src/voice/models/active_call.dart';
import 'package:twilio_voice_sms/src/voice/models/audio_route.dart';

pigeon.ActiveCallDto _dto({int? connectedAt}) => pigeon.ActiveCallDto(
      sid: 'CA1',
      from: '+1',
      to: '+2',
      direction: pigeon.CallDirection.outgoing,
      startedAt: 1700000000000,
      isMuted: false,
      isOnHold: false,
      isOnSpeaker: false,
      currentRoute: pigeon.AudioRoute.earpiece,
      connectedAt: connectedAt,
    );

void main() {
  test('connectedAt round-trips when set', () {
    final ac = ActiveCall.fromDto(_dto(connectedAt: 1700000005000));
    expect(ac.connectedAt, DateTime.fromMillisecondsSinceEpoch(1700000005000));
  });

  test('connectedAt is null when not set', () {
    expect(ActiveCall.fromDto(_dto()).connectedAt, isNull);
  });

  test('currentRoute maps to public enum', () {
    final ac = ActiveCall.fromDto(_dto());
    expect(ac.currentRoute, AudioRoute.earpiece);
  });
}
