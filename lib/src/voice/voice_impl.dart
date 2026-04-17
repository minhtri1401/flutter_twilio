import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'errors.dart';
import 'generated/voice_api.g.dart';
import 'models/active_call.dart';
import 'models/call.dart';
import 'models/call_event.dart';
import 'voice_api.dart';

class VoiceImpl implements VoiceApi, VoiceFlutterApi {
  VoiceImpl({VoiceHostApi? host}) : _host = host ?? VoiceHostApi() {
    VoiceFlutterApi.setUp(this);
  }

  final VoiceHostApi _host;
  final StreamController<Call> _events = StreamController<Call>.broadcast();

  @override
  Stream<Call> get events => _events.stream;

  Future<T> _guard<T>(Future<T> Function() fn) async {
    try {
      return await fn();
    } on PlatformException catch (e) {
      throw VoiceException.fromPigeon(e);
    }
  }

  @override
  Future<void> setAccessToken(String token) =>
      _guard(() => _host.setAccessToken(token));

  @override
  Future<void> register() => _guard(() => _host.register());

  @override
  Future<void> unregister() => _guard(() => _host.unregister());

  @override
  Future<ActiveCall> place({
    required String to,
    String? from,
    Map<String, String>? extra,
  }) =>
      _guard(() async {
        final dto = await _host.place(PlaceCallRequest(
          to: to,
          from: from,
          extraParameters: extra,
        ));
        return ActiveCall.fromDto(dto);
      });

  @override
  Future<void> answer() => _guard(() => _host.answer());

  @override
  Future<void> reject() => _guard(() => _host.reject());

  @override
  Future<void> hangUp() => _guard(() => _host.hangUp());

  @override
  Future<void> setMuted(bool muted) => _guard(() => _host.setMuted(muted));

  @override
  Future<void> setOnHold(bool onHold) => _guard(() => _host.setOnHold(onHold));

  @override
  Future<void> setSpeaker(bool onSpeaker) =>
      _guard(() => _host.setSpeaker(onSpeaker));

  @override
  Future<void> sendDigits(String digits) =>
      _guard(() => _host.sendDigits(digits));

  @override
  Future<ActiveCall?> getActiveCall() => _guard(() async {
        final dto = await _host.getActiveCall();
        return dto == null ? null : ActiveCall.fromDto(dto);
      });

  @override
  Future<bool> hasMicPermission() => _guard(() => _host.hasMicPermission());

  @override
  Future<bool> requestMicPermission() =>
      _guard(() => _host.requestMicPermission());

  // --- VoiceFlutterApi (native → Dart) ---------------------------------------

  @override
  void onCallEvent(CallEventDto event) => handleCallEventForTesting(event);

  @visibleForTesting
  void handleCallEventForTesting(CallEventDto event) {
    if (event.type == CallEventType.error && event.error != null) {
      final err = event.error!;
      _events.addError(VoiceException.fromCodeMessageDetails(
        err.code,
        err.message,
        _normalizeDetails(err.details),
      ));
      return;
    }
    _events.add(Call(
      event: CallEvent.fromPigeon(event.type),
      active: event.activeCall == null
          ? null
          : ActiveCall.fromDto(event.activeCall!),
    ));
  }

  Map<String, Object?> _normalizeDetails(Map<String?, Object?>? raw) {
    if (raw == null) return const {};
    return {
      for (final e in raw.entries)
        if (e.key != null) e.key!: e.value,
    };
  }

  @visibleForTesting
  Future<void> runGuardedForTesting(Future<void> Function() impl) =>
      _guard(impl);

  void dispose() => _events.close();
}
