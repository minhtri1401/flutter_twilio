import 'dart:convert';

import 'package:http/http.dart' as http;

import 'errors.dart';
import 'models/message.dart';
import 'sms_api.dart';

class SmsClient implements SmsApi {
  SmsClient({
    required this.accountSid,
    required this.authToken,
    this.defaultFrom,
    http.Client? httpClient,
  }) : _http = httpClient ?? http.Client();

  final String accountSid;
  final String authToken;
  final String? defaultFrom;
  final http.Client _http;

  Uri _uri(String path, [Map<String, String>? q]) => Uri.https(
        'api.twilio.com',
        '/2010-04-01/Accounts/$accountSid/$path',
        q,
      );

  Map<String, String> get _headers => {
        'authorization':
            'Basic ${base64Encode(utf8.encode('$accountSid:$authToken'))}',
      };

  Future<http.Response> _request(
    String method,
    Uri url, {
    Map<String, String>? body,
  }) async {
    try {
      final req = http.Request(method, url);
      req.headers.addAll(_headers);
      if (body != null) req.bodyFields = body;
      final streamed = await _http.send(req);
      return http.Response.fromStream(streamed);
    } catch (e) {
      throw TwilioSmsException.connection(e.toString());
    }
  }

  Map<String, dynamic> _decodeOrThrow(http.Response r) {
    if (r.statusCode >= 200 && r.statusCode < 300) {
      return jsonDecode(r.body) as Map<String, dynamic>;
    }
    throw TwilioSmsException.fromResponseBody(r.statusCode, r.body);
  }

  @override
  Future<Message> send({
    required String to,
    required String body,
    String? from,
  }) async {
    final effectiveFrom = from ?? defaultFrom;
    if (effectiveFrom == null) {
      throw TwilioSmsException(
        statusCode: 0,
        code: 'invalid_argument',
        message:
            'No "from" number: pass `from:` explicitly or set defaultFrom (twilioNumber) on init.',
      );
    }
    final res = await _request(
      'POST',
      _uri('Messages.json'),
      body: {
        'To': to,
        'From': effectiveFrom,
        'Body': body,
      },
    );
    return Message.fromJson(_decodeOrThrow(res));
  }

  @override
  Future<Message> get({required String sid}) async {
    final res = await _request('GET', _uri('Messages/$sid.json'));
    return Message.fromJson(_decodeOrThrow(res));
  }

  @override
  Future<List<Message>> list({int? limit, String? to, String? from}) async {
    final q = <String, String>{};
    if (limit != null) q['PageSize'] = '$limit';
    if (to != null) q['To'] = to;
    if (from != null) q['From'] = from;
    final res = await _request('GET', _uri('Messages.json', q));
    final json = _decodeOrThrow(res);
    final items = (json['messages'] as List<dynamic>? ?? const [])
        .cast<Map<String, dynamic>>();
    return items.map(Message.fromJson).toList();
  }

  void close() => _http.close();
}
