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

  factory Message.fromJson(Map<String, dynamic> json) {
    int intOf(Object? o) =>
        o is int ? o : (o is String ? int.tryParse(o) ?? 0 : 0);
    DateTime? dateOf(Object? o) => o is String ? DateTime.tryParse(o) : null;
    int? intOrNull(Object? o) => o is int
        ? o
        : (o is String ? int.tryParse(o) : null);

    return Message(
      sid: json['sid'] as String,
      status: json['status'] as String,
      direction: json['direction'] as String,
      from: (json['from'] as String?) ?? '',
      to: (json['to'] as String?) ?? '',
      body: (json['body'] as String?) ?? '',
      numSegments: intOf(json['num_segments']),
      dateSent: dateOf(json['date_sent']),
      errorCode: intOrNull(json['error_code']),
      errorMessage: json['error_message'] as String?,
      price: json['price'] as String?,
      priceUnit: json['price_unit'] as String?,
    );
  }
}
