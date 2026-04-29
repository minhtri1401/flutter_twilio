// ignore_for_file: non_constant_identifier_names
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:twilio_voice_sms/src/voice/errors.dart';
import 'package:twilio_voice_sms/src/voice/generated/voice_api.g.dart' as pigeon;
import 'package:twilio_voice_sms/src/voice/models/audio_route.dart';
import 'package:twilio_voice_sms/src/voice/voice_impl.dart';

class _FakeHost implements pigeon.VoiceHostApi {
  pigeon.AudioRoute? lastSetRoute;
  pigeon.AudioRoute getRouteResult = pigeon.AudioRoute.earpiece;
  List<pigeon.AudioRouteInfo> listResult = const [];
  Object? throwOnSet;

  @override
  final String pigeonVar_messageChannelSuffix = '';

  @override
  BinaryMessenger? get pigeonVar_binaryMessenger => null;

  @override
  Future<void> setAudioRoute(pigeon.AudioRoute route) async {
    if (throwOnSet != null) throw throwOnSet!;
    lastSetRoute = route;
  }

  @override
  Future<pigeon.AudioRoute> getAudioRoute() async => getRouteResult;

  @override
  Future<List<pigeon.AudioRouteInfo>> listAudioRoutes() async => listResult;

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
  Future<void> setSpeaker(bool onSpeaker) async {}
  @override
  Future<void> sendDigits(String digits) async {}
  @override
  Future<pigeon.ActiveCallDto?> getActiveCall() async => null;
  @override
  Future<bool> hasMicPermission() async => true;
  @override
  Future<bool> requestMicPermission() async => true;
  @override
  Future<void> configure(pigeon.VoiceConfig config) async {}
  @override
  Future<void> bringAppToForeground() async {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late _FakeHost host;
  late VoiceImpl voice;

  setUp(() {
    host = _FakeHost();
    voice = VoiceImpl(host: host);
  });
  tearDown(() => voice.dispose());

  test('setAudioRoute forwards to host with the right pigeon enum value', () async {
    await voice.setAudioRoute(AudioRoute.bluetooth);
    expect(host.lastSetRoute, pigeon.AudioRoute.bluetooth);
  });

  test('setAudioRoute throws BluetoothUnavailableException on bluetooth_unavailable', () async {
    host.throwOnSet = PlatformException(code: 'bluetooth_unavailable', message: 'no BT');
    expect(
      () => voice.setAudioRoute(AudioRoute.bluetooth),
      throwsA(isA<BluetoothUnavailableException>()),
    );
  });

  test('getAudioRoute maps host result through enum', () async {
    host.getRouteResult = pigeon.AudioRoute.speaker;
    expect(await voice.getAudioRoute(), AudioRoute.speaker);
  });

  test('listAudioRoutes maps each entry', () async {
    host.listResult = [
      pigeon.AudioRouteInfo(route: pigeon.AudioRoute.earpiece, isActive: true),
      pigeon.AudioRouteInfo(
        route: pigeon.AudioRoute.bluetooth,
        isActive: false,
        deviceName: 'AirPods',
      ),
    ];
    final out = await voice.listAudioRoutes();
    expect(out, hasLength(2));
    expect(out[0].route, AudioRoute.earpiece);
    expect(out[0].isActive, isTrue);
    expect(out[1].deviceName, 'AirPods');
  });
}
