import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:twilio_voice_sms/src/voice/errors.dart';

void main() {
  PlatformException pe(String code) => PlatformException(code: code, message: code);

  test('bluetooth_unavailable maps to BluetoothUnavailableException', () {
    final e = VoiceException.fromPigeon(pe('bluetooth_unavailable'));
    expect(e, isA<BluetoothUnavailableException>());
    expect(e.code, 'bluetooth_unavailable');
  });

  test('wired_unavailable maps to WiredUnavailableException', () {
    expect(VoiceException.fromPigeon(pe('wired_unavailable')),
        isA<WiredUnavailableException>());
  });

  test('audio_route_failed maps to AudioRouteFailedException', () {
    expect(VoiceException.fromPigeon(pe('audio_route_failed')),
        isA<AudioRouteFailedException>());
  });

  test('tone_asset_not_found maps to ToneAssetNotFoundException', () {
    expect(VoiceException.fromPigeon(pe('tone_asset_not_found')),
        isA<ToneAssetNotFoundException>());
  });

  test('notification_permission_denied maps to NotificationPermissionException',
      () {
    expect(VoiceException.fromPigeon(pe('notification_permission_denied')),
        isA<NotificationPermissionException>());
  });
}
