import 'package:flutter_test/flutter_test.dart';
import 'package:twilio_voice_sms/src/voice/generated/voice_api.g.dart' as pigeon;
import 'package:twilio_voice_sms/src/voice/models/call_event.dart';

void main() {
  test('every CallEventType maps to a CallEvent', () {
    for (final t in pigeon.CallEventType.values) {
      // Will throw if any value is unmapped.
      CallEvent.fromPigeon(t);
    }
  });

  test('audioRouteChanged round-trips', () {
    expect(
      CallEvent.fromPigeon(pigeon.CallEventType.audioRouteChanged),
      CallEvent.audioRouteChanged,
    );
  });

  test('deprecated speakerOn/Off still resolve', () {
    // ignore: deprecated_member_use_from_same_package
    expect(CallEvent.fromPigeon(pigeon.CallEventType.speakerOn), CallEvent.speakerOn);
    // ignore: deprecated_member_use_from_same_package
    expect(CallEvent.fromPigeon(pigeon.CallEventType.speakerOff), CallEvent.speakerOff);
  });
}
