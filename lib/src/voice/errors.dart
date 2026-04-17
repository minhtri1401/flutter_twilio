import 'package:flutter/services.dart';

/// Shared base for everything thrown by flutter_twilio.
abstract class FlutterTwilioException implements Exception {
  String get code;
  String get message;
  Map<String, Object?> get details;

  @override
  String toString() => '$runtimeType(code=$code, message=$message)';
}

/// Base voice exception. Use the `code` string or `is` checks against the
/// concrete subtypes below to discriminate. The full list of stable codes is
/// documented in [VoiceException.fromPigeon].
class VoiceException extends FlutterTwilioException {
  VoiceException({
    required this.code,
    required this.message,
    this.details = const {},
  });

  @override
  final String code;
  @override
  final String message;
  @override
  final Map<String, Object?> details;

  /// Maps a Pigeon [PlatformException] (or equivalent error surfaced through
  /// the event stream) to the matching [VoiceException] subtype. Unknown
  /// codes fall through to a bare [VoiceException] so callers stay
  /// forward-compatible.
  static VoiceException fromPigeon(PlatformException e) {
    return fromCodeMessageDetails(
      e.code,
      e.message ?? e.code,
      _asMap(e.details),
    );
  }

  /// Canonical factory used by both [fromPigeon] and the event-stream path
  /// (where we receive a `CallErrorDto` rather than a [PlatformException]).
  static VoiceException fromCodeMessageDetails(
    String code,
    String message,
    Map<String, Object?> details,
  ) {
    switch (code) {
      case 'not_initialized':
        return VoiceNotInitializedException(message: message, details: details);
      case 'missing_permission':
        return VoicePermissionDeniedException(
          message: message,
          details: details,
          permission: details['permission']?.toString() ?? 'unknown',
        );
      case 'invalid_argument':
        return VoiceInvalidArgumentException(
            message: message, details: details);
      case 'invalid_token':
        return VoiceInvalidTokenException(message: message, details: details);
      case 'no_active_call':
        return VoiceNoActiveCallException(message: message, details: details);
      case 'call_already_active':
        return VoiceCallAlreadyActiveException(
            message: message, details: details);
      case 'twilio_sdk_error':
        return TwilioSdkException(
          message: message,
          details: details,
          twilioCode: (details['twilioCode'] as num?)?.toInt(),
          twilioDomain: details['twilioDomain']?.toString(),
        );
      case 'audio_session_error':
        return VoiceAudioSessionException(
            message: message, details: details);
      case 'registration_error':
        return VoiceRegistrationException(
            message: message, details: details);
      case 'connection_error':
        return VoiceConnectionException(message: message, details: details);
      default:
        return VoiceException(code: code, message: message, details: details);
    }
  }

  static Map<String, Object?> _asMap(Object? raw) {
    if (raw is Map) {
      return {for (final e in raw.entries) e.key.toString(): e.value};
    }
    return const {};
  }
}

/// `init()` or `setAccessToken()` was not called before this operation.
class VoiceNotInitializedException extends VoiceException {
  VoiceNotInitializedException({
    required super.message,
    super.details = const {},
  }) : super(code: 'not_initialized');
}

/// A required runtime permission (usually RECORD_AUDIO) was not granted.
class VoicePermissionDeniedException extends VoiceException {
  VoicePermissionDeniedException({
    required super.message,
    required this.permission,
    super.details = const {},
  }) : super(code: 'missing_permission');

  /// The permission identifier the native side reported (e.g. `"RECORD_AUDIO"`
  /// on Android, `"microphone"` on iOS).
  final String permission;
}

/// A method was called with a malformed or missing required argument.
class VoiceInvalidArgumentException extends VoiceException {
  VoiceInvalidArgumentException({
    required super.message,
    super.details = const {},
  }) : super(code: 'invalid_argument');
}

/// The Twilio access token was rejected by the SDK.
class VoiceInvalidTokenException extends VoiceException {
  VoiceInvalidTokenException({
    required super.message,
    super.details = const {},
  }) : super(code: 'invalid_token');
}

/// The operation requires an active call but none exists.
class VoiceNoActiveCallException extends VoiceException {
  VoiceNoActiveCallException({
    required super.message,
    super.details = const {},
  }) : super(code: 'no_active_call');
}

/// Tried to place or answer a call while another is already live.
class VoiceCallAlreadyActiveException extends VoiceException {
  VoiceCallAlreadyActiveException({
    required super.message,
    super.details = const {},
  }) : super(code: 'call_already_active');
}

/// The Twilio Voice SDK reported a failure. Inspect [twilioCode] and
/// [twilioDomain] to branch on specific SDK errors.
class TwilioSdkException extends VoiceException {
  TwilioSdkException({
    required super.message,
    super.details = const {},
    this.twilioCode,
    this.twilioDomain,
  }) : super(code: 'twilio_sdk_error');

  final int? twilioCode;
  final String? twilioDomain;
}

/// An `AVAudioSession` (iOS) or `AudioManager` (Android) operation failed.
class VoiceAudioSessionException extends VoiceException {
  VoiceAudioSessionException({
    required super.message,
    super.details = const {},
  }) : super(code: 'audio_session_error');
}

/// Device registration (FCM token fetch, Twilio `Voice.register`, or PushKit)
/// failed. Arrives on the event stream as `onError` — not thrown from a
/// method call — because registration is async after `register()` returns.
class VoiceRegistrationException extends VoiceException {
  VoiceRegistrationException({
    required super.message,
    super.details = const {},
  }) : super(code: 'registration_error');
}

/// A transport-layer failure (network dropped, WebSocket closed, CallKit
/// transaction refused). Surfaces asynchronously via the event stream.
class VoiceConnectionException extends VoiceException {
  VoiceConnectionException({
    required super.message,
    super.details = const {},
  }) : super(code: 'connection_error');
}
