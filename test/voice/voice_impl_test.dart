// ignore_for_file: non_constant_identifier_names
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:twilio_voice_sms/src/voice/errors.dart';
import 'package:twilio_voice_sms/src/voice/generated/voice_api.g.dart';
import 'package:twilio_voice_sms/src/voice/models/call.dart';
import 'package:twilio_voice_sms/src/voice/models/call_event.dart';
import 'package:twilio_voice_sms/src/voice/voice_impl.dart';

class _FakeHost implements VoiceHostApi {
  final List<String> log = [];
  ActiveCallDto? _active;

  @override
  final String pigeonVar_messageChannelSuffix = '';

  @override
  BinaryMessenger? get pigeonVar_binaryMessenger => null;

  @override
  Future<void> setAccessToken(String token) async {
    log.add('setAccessToken:$token');
  }

  @override
  Future<void> register() async {
    log.add('register');
  }

  @override
  Future<void> unregister() async {
    log.add('unregister');
  }

  @override
  Future<ActiveCallDto> place(PlaceCallRequest request) async {
    log.add('place:${request.to}');
    _active = ActiveCallDto(
      sid: 'CA1',
      from: request.from ?? '?',
      to: request.to,
      direction: CallDirection.outgoing,
      startedAt: 0,
      isMuted: false,
      isOnHold: false,
      isOnSpeaker: false,
    );
    return _active!;
  }

  @override
  Future<void> answer() async {
    log.add('answer');
  }

  @override
  Future<void> reject() async {
    log.add('reject');
  }

  @override
  Future<void> hangUp() async {
    log.add('hangUp');
    _active = null;
  }

  @override
  Future<void> setMuted(bool muted) async {
    log.add('muted:$muted');
  }

  @override
  Future<void> setOnHold(bool onHold) async {
    log.add('hold:$onHold');
  }

  @override
  Future<void> setSpeaker(bool onSpeaker) async {
    log.add('speaker:$onSpeaker');
  }

  @override
  Future<void> sendDigits(String digits) async {
    log.add('digits:$digits');
  }

  @override
  Future<ActiveCallDto?> getActiveCall() async => _active;

  @override
  Future<bool> hasMicPermission() async => true;

  @override
  Future<bool> requestMicPermission() async => true;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('place returns an ActiveCall and forwards arguments', () async {
    final host = _FakeHost();
    final impl = VoiceImpl(host: host);
    final call = await impl.place(to: '+100', from: '+200');
    expect(call.sid, 'CA1');
    expect(host.log, contains('place:+100'));
  });

  test('events stream yields Call for non-error and onError for error', () async {
    final impl = VoiceImpl(host: _FakeHost());
    final received = <Object>[];
    final sub = impl.events.listen(received.add, onError: received.add);

    impl.handleCallEventForTesting(CallEventDto(
      type: CallEventType.connected,
      activeCall: ActiveCallDto(
        sid: 'CA2',
        from: 'a',
        to: 'b',
        direction: CallDirection.incoming,
        startedAt: 0,
        isMuted: false,
        isOnHold: false,
        isOnSpeaker: false,
      ),
    ));

    impl.handleCallEventForTesting(CallEventDto(
      type: CallEventType.error,
      error: CallErrorDto(
        code: 'twilio_sdk_error',
        message: 'boom',
        details: <String?, Object?>{'twilioCode': 31205},
      ),
    ));

    await Future<void>.delayed(const Duration(milliseconds: 20));
    await sub.cancel();

    expect(received.length, 2);
    final first = received.first;
    expect(first, isA<Call>());
    expect((first as Call).event, CallEvent.connected);
    expect(received.last, isA<TwilioSdkException>());
  });

  test('runGuardedForTesting wraps PlatformException → VoiceException', () async {
    final impl = VoiceImpl(host: _FakeHost());
    expect(
      () => impl.runGuardedForTesting(() async =>
          throw PlatformException(code: 'no_active_call', message: 'none')),
      throwsA(isA<VoiceNoActiveCallException>()),
    );
  });
}
