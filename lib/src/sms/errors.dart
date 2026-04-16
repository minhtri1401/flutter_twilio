import 'dart:convert';

import '../voice/errors.dart' show FlutterTwilioException;

class TwilioSmsException implements FlutterTwilioException {
  TwilioSmsException({
    required this.statusCode,
    required this.message,
    this.code = 'sms_error',
    this.twilioCode,
    this.moreInfo,
    this.details = const {},
  });

  @override
  final String code;
  @override
  final String message;
  @override
  final Map<String, Object?> details;

  final int statusCode;
  final int? twilioCode;
  final String? moreInfo;

  factory TwilioSmsException.fromResponseBody(int statusCode, String body) {
    try {
      final decoded = jsonDecode(body);
      if (decoded is Map<String, dynamic>) {
        return TwilioSmsException(
          statusCode: statusCode,
          code: 'sms_error',
          message: decoded['message']?.toString() ?? 'SMS request failed',
          twilioCode: (decoded['code'] as num?)?.toInt(),
          moreInfo: decoded['more_info']?.toString(),
          details: {'raw': decoded},
        );
      }
    } catch (_) {
      // fall through
    }
    return TwilioSmsException(
      statusCode: statusCode,
      code: 'sms_error',
      message: body.isEmpty ? 'HTTP $statusCode' : body,
    );
  }

  factory TwilioSmsException.connection(String message) => TwilioSmsException(
        statusCode: 0,
        code: 'connection_error',
        message: message,
      );

  @override
  String toString() =>
      'TwilioSmsException(code=$code, statusCode=$statusCode, twilioCode=$twilioCode, message=$message)';
}
