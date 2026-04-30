// ignore_for_file: non_constant_identifier_names
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:twilio_voice_sms/src/voice/generated/voice_api.g.dart' as pigeon;
import 'package:twilio_voice_sms/src/voice/voice_impl.dart';

class _SpyHost implements pigeon.VoiceHostApi {
  pigeon.AudioRoute? lastSetRoute;
  bool nativeSetSpeakerCalled = false;

  @override
  final String pigeonVar_messageChannelSuffix = '';

  @override
  BinaryMessenger? get pigeonVar_binaryMessenger => null;

  @override
  Future<void> setAudioRoute(pigeon.AudioRoute route) async {
    lastSetRoute = route;
  }

  @override
  Future<void> setSpeaker(bool onSpeaker) async {
    nativeSetSpeakerCalled = true;
  }

  @override
  Future<void> setAccessToken(String token) async {}
  @override
  Future<void> register() async {}
  @override
  Future<void> unregister() async {}
  @override
  Future<pigeon.ActiveCallDto> place(pigeon.PlaceCallRequest request) async =>
      throw UnimplementedError();
  @override
  Future<void> answer() async {}
  @override
  Future<void> reject() async {}
  @override
  Future<void> hangUp() async {}
  @override
  Future<void> setMuted(bool muted) async {}
  @override
  Future<void> setOnHold(bool onHold) async {}
  @override
  Future<void> sendDigits(String digits) async {}
  @override
  Future<pigeon.ActiveCallDto?> getActiveCall() async => null;
  @override
  Future<bool> hasMicPermission() async => true;
  @override
  Future<bool> requestMicPermission() async => true;
  @override
  Future<pigeon.AudioRoute> getAudioRoute() async => pigeon.AudioRoute.earpiece;
  @override
  Future<List<pigeon.AudioRouteInfo>> listAudioRoutes() async => const [];
  @override
  Future<void> configure(pigeon.VoiceConfig config) async {}
  @override
  Future<void> bringAppToForeground() async {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('setSpeaker(true) forwards to setAudioRoute(speaker)', () async {
    final host = _SpyHost();
    final voice = VoiceImpl(host: host);
    // ignore: deprecated_member_use_from_same_package
    await voice.setSpeaker(true);
    expect(host.lastSetRoute, pigeon.AudioRoute.speaker);
    expect(host.nativeSetSpeakerCalled, isFalse,
        reason: 'Dart shim must not call the deprecated native setSpeaker — '
            'it routes through setAudioRoute instead.');
    voice.dispose();
  });

  test('setSpeaker(false) forwards to setAudioRoute(earpiece)', () async {
    final host = _SpyHost();
    final voice = VoiceImpl(host: host);
    // ignore: deprecated_member_use_from_same_package
    await voice.setSpeaker(false);
    expect(host.lastSetRoute, pigeon.AudioRoute.earpiece);
    voice.dispose();
  });
}
