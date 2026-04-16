import 'package:flutter/services.dart';

/// Shared base for everything thrown by flutter_twilio.
abstract class FlutterTwilioException implements Exception {
  String get code;
  String get message;
  Map<String, Object?> get details;

  @override
  String toString() => '$runtimeType(code=$code, message=$message)';
}

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

  static VoiceException fromPigeon(PlatformException e) {
    final code = e.code;
    final message = e.message ?? code;
    final details = _asMap(e.details);

    switch (code) {
      case 'not_initialized':
        return VoiceNotInitializedException(message: message, details: details);
      case 'missing_permission':
        return VoicePermissionDeniedException(
          message: message,
          details: details,
          permission: details['permission']?.toString() ?? 'unknown',
        );
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

class VoiceNotInitializedException extends VoiceException {
  VoiceNotInitializedException({
    required super.message,
    super.details = const {},
  }) : super(code: 'not_initialized');
}

class VoicePermissionDeniedException extends VoiceException {
  VoicePermissionDeniedException({
    required super.message,
    required this.permission,
    super.details = const {},
  }) : super(code: 'missing_permission');

  final String permission;
}

class VoiceInvalidTokenException extends VoiceException {
  VoiceInvalidTokenException({
    required super.message,
    super.details = const {},
  }) : super(code: 'invalid_token');
}

class VoiceNoActiveCallException extends VoiceException {
  VoiceNoActiveCallException({
    required super.message,
    super.details = const {},
  }) : super(code: 'no_active_call');
}

class VoiceCallAlreadyActiveException extends VoiceException {
  VoiceCallAlreadyActiveException({
    required super.message,
    super.details = const {},
  }) : super(code: 'call_already_active');
}

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
