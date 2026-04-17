import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_twilio/src/sms/errors.dart';
import 'package:flutter_twilio/src/sms/models/message.dart';

void main() {
  test('Message.fromJson parses the Twilio REST response', () {
    final json = jsonDecode(r'''
      {
        "sid": "SM123",
        "status": "queued",
        "direction": "outbound-api",
        "from": "+100",
        "to": "+200",
        "body": "hi",
        "date_sent": "2026-04-17T10:00:00Z",
        "num_segments": "1",
        "error_code": null,
        "error_message": null,
        "price": "-0.00750",
        "price_unit": "USD"
      }''') as Map<String, dynamic>;

    final m = Message.fromJson(json);
    expect(m.sid, 'SM123');
    expect(m.status, 'queued');
    expect(m.from, '+100');
    expect(m.numSegments, 1);
    expect(m.dateSent!.toUtc(), DateTime.utc(2026, 4, 17, 10));
    expect(m.errorCode, isNull);
    expect(m.price, '-0.00750');
  });

  test('Message.fromJson tolerates null date_sent and missing fields', () {
    final m = Message.fromJson(const {
      'sid': 'SMx',
      'status': 'accepted',
      'direction': 'outbound-api',
      'from': '+1',
      'to': '+2',
      'body': '',
      'num_segments': 0,
    });
    expect(m.dateSent, isNull);
    expect(m.numSegments, 0);
  });

  test('Message.fromJson throws TwilioSmsException when sid is missing', () {
    expect(
      () => Message.fromJson(const {
        'status': 'queued',
        'direction': 'outbound-api',
      }),
      throwsA(isA<TwilioSmsException>()
          .having((e) => e.code, 'code', 'parse_error')
          .having((e) => e.statusCode, 'statusCode', 0)),
    );
  });

  test('Message.fromJson throws when a required field is the wrong type', () {
    expect(
      () => Message.fromJson(const {
        'sid': 12345, // expected String
        'status': 'queued',
        'direction': 'outbound-api',
      }),
      throwsA(isA<TwilioSmsException>()
          .having((e) => e.code, 'code', 'parse_error')),
    );
  });

  test('Message.fromJson preserves raw payload in details on parse failure',
      () {
    try {
      Message.fromJson(const {'status': 'queued'});
      fail('expected TwilioSmsException');
    } on TwilioSmsException catch (e) {
      expect(e.details['raw'], isA<Map>());
    }
  });
}
