import 'package:flutter_test/flutter_test.dart';
import 'package:twilio_voice_sms/src/voice/voice_config.dart';

void main() {
  test('default values match spec', () {
    const c = VoiceConfig();
    expect(c.playRingback, isTrue);
    expect(c.playConnectTone, isFalse);
    expect(c.playDisconnectTone, isFalse);
    expect(c.bringAppToForegroundOnAnswer, isTrue);
    expect(c.bringAppToForegroundOnEnd, isFalse);
    expect(c.ringbackAsset, isNull);
    expect(c.connectToneAsset, isNull);
    expect(c.disconnectToneAsset, isNull);
  });

  test('toPigeon copies every field', () {
    const c = VoiceConfig(
      ringbackAsset: 'assets/ring.ogg',
      connectToneAsset: 'assets/c.ogg',
      disconnectToneAsset: 'assets/d.ogg',
      playRingback: false,
      playConnectTone: true,
      playDisconnectTone: true,
      bringAppToForegroundOnAnswer: false,
      bringAppToForegroundOnEnd: true,
    );
    final p = c.toPigeon();
    expect(p.ringbackAssetPath, 'assets/ring.ogg');
    expect(p.connectToneAssetPath, 'assets/c.ogg');
    expect(p.disconnectToneAssetPath, 'assets/d.ogg');
    expect(p.playRingback, isFalse);
    expect(p.playConnectTone, isTrue);
    expect(p.playDisconnectTone, isTrue);
    expect(p.bringAppToForegroundOnAnswer, isFalse);
    expect(p.bringAppToForegroundOnEnd, isTrue);
  });
}
