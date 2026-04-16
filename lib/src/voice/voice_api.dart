import 'models/active_call.dart';
import 'models/call.dart';

/// Public voice surface. Implemented by [VoiceImpl] over the generated
/// Pigeon host API.
abstract class VoiceApi {
  Future<void> setAccessToken(String token);
  Future<void> register();
  Future<void> unregister();

  Future<ActiveCall> place({
    required String to,
    String? from,
    Map<String, String>? extra,
  });

  Future<void> answer();
  Future<void> reject();
  Future<void> hangUp();

  Future<void> setMuted(bool muted);
  Future<void> setOnHold(bool onHold);
  Future<void> setSpeaker(bool onSpeaker);
  Future<void> sendDigits(String digits);

  Future<ActiveCall?> getActiveCall();
  Future<bool> hasMicPermission();
  Future<bool> requestMicPermission();

  /// Broadcasts every call event. Errors surface as `onError` on the stream
  /// carrying a [VoiceException] subtype.
  Stream<Call> get events;
}
