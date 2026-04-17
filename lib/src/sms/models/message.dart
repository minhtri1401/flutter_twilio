import '../errors.dart';

class Message {
  const Message({
    required this.sid,
    required this.status,
    required this.direction,
    required this.from,
    required this.to,
    required this.body,
    required this.numSegments,
    this.dateSent,
    this.errorCode,
    this.errorMessage,
    this.price,
    this.priceUnit,
  });

  final String sid;
  final String status;
  final String direction;
  final String from;
  final String to;
  final String body;
  final int numSegments;
  final DateTime? dateSent;
  final int? errorCode;
  final String? errorMessage;
  final String? price;
  final String? priceUnit;

  /// Parses a Twilio REST message payload. Throws a [TwilioSmsException]
  /// (code `parse_error`, statusCode 0) if any required field is missing or
  /// of an unexpected type — we never leak a raw `TypeError` to callers.
  factory Message.fromJson(Map<String, dynamic> json) {
    try {
      return Message(
        sid: _requiredString(json, 'sid'),
        status: _requiredString(json, 'status'),
        direction: _requiredString(json, 'direction'),
        from: _optionalString(json, 'from') ?? '',
        to: _optionalString(json, 'to') ?? '',
        body: _optionalString(json, 'body') ?? '',
        numSegments: _intOr(json['num_segments'], 0),
        dateSent: _dateOrNull(json['date_sent']),
        errorCode: _intOrNull(json['error_code']),
        errorMessage: _optionalString(json, 'error_message'),
        price: _optionalString(json, 'price'),
        priceUnit: _optionalString(json, 'price_unit'),
      );
    } on TwilioSmsException {
      rethrow;
    } catch (e) {
      throw TwilioSmsException(
        statusCode: 0,
        code: 'parse_error',
        message: 'Failed to parse Twilio message payload: $e',
        details: {'raw': json},
      );
    }
  }

  static String _requiredString(Map<String, dynamic> json, String key) {
    final v = json[key];
    if (v is String) return v;
    throw TwilioSmsException(
      statusCode: 0,
      code: 'parse_error',
      message:
          'Expected String for "$key" in Twilio message payload, got ${v?.runtimeType}',
      details: {'raw': json},
    );
  }

  static String? _optionalString(Map<String, dynamic> json, String key) {
    final v = json[key];
    return v is String ? v : null;
  }

  static int _intOr(Object? o, int fallback) =>
      o is int ? o : (o is String ? int.tryParse(o) ?? fallback : fallback);

  static int? _intOrNull(Object? o) => o is int
      ? o
      : (o is String ? int.tryParse(o) : null);

  static DateTime? _dateOrNull(Object? o) =>
      o is String ? DateTime.tryParse(o) : null;
}
