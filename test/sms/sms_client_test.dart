import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_twilio/src/sms/errors.dart';
import 'package:flutter_twilio/src/sms/sms_client.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

SmsClient client(MockClient inner) => SmsClient(
      accountSid: 'AC123',
      authToken: 'secret',
      defaultFrom: '+100',
      httpClient: inner,
    );

void main() {
  test('send posts to Messages.json with basic auth + form body', () async {
    late http.Request sent;
    final c = client(MockClient((req) async {
      sent = req;
      return http.Response(
        jsonEncode({
          'sid': 'SM1',
          'status': 'queued',
          'direction': 'outbound-api',
          'from': '+100',
          'to': '+200',
          'body': 'hi',
          'num_segments': '1',
        }),
        201,
      );
    }));

    final msg = await c.send(to: '+200', body: 'hi');

    expect(sent.method, 'POST');
    expect(
      sent.url.toString(),
      'https://api.twilio.com/2010-04-01/Accounts/AC123/Messages.json',
    );
    expect(
      sent.headers['authorization'],
      'Basic ${base64Encode(utf8.encode('AC123:secret'))}',
    );
    expect(sent.bodyFields, {'To': '+200', 'From': '+100', 'Body': 'hi'});
    expect(msg.sid, 'SM1');
  });

  test('send 4xx throws TwilioSmsException with twilioCode', () async {
    final c = client(MockClient((_) async => http.Response(
          '{"code":21211,"message":"bad To","status":400,"more_info":"x"}',
          400,
        )));

    await expectLater(
      c.send(to: 'xxx', body: 'hi'),
      throwsA(isA<TwilioSmsException>()
          .having((e) => e.statusCode, 'statusCode', 400)
          .having((e) => e.twilioCode, 'twilioCode', 21211)),
    );
  });

  test('network failure surfaces as connection_error', () async {
    final c = client(MockClient((_) async => throw Exception('offline')));
    await expectLater(
      c.send(to: '+200', body: 'hi'),
      throwsA(isA<TwilioSmsException>()
          .having((e) => e.code, 'code', 'connection_error')),
    );
  });

  test('list returns parsed messages with PageSize query', () async {
    late Uri sentUrl;
    final c = client(MockClient((req) async {
      sentUrl = req.url;
      return http.Response(
        jsonEncode({
          'messages': [
            {
              'sid': 'SM1',
              'status': 'delivered',
              'direction': 'outbound-api',
              'from': '+100',
              'to': '+200',
              'body': 'a',
              'num_segments': '1',
            },
            {
              'sid': 'SM2',
              'status': 'queued',
              'direction': 'outbound-api',
              'from': '+100',
              'to': '+200',
              'body': 'b',
              'num_segments': '1',
            },
          ],
        }),
        200,
      );
    }));
    final msgs = await c.list(limit: 2);
    expect(msgs, hasLength(2));
    expect(msgs.first.sid, 'SM1');
    expect(sentUrl.queryParameters['PageSize'], '2');
  });

  test('get fetches a single message by sid', () async {
    late Uri sentUrl;
    final c = client(MockClient((req) async {
      sentUrl = req.url;
      return http.Response(
        jsonEncode({
          'sid': 'SM9',
          'status': 'delivered',
          'direction': 'outbound-api',
          'from': '+100',
          'to': '+200',
          'body': 'ok',
          'num_segments': '1',
        }),
        200,
      );
    }));
    final msg = await c.get(sid: 'SM9');
    expect(msg.sid, 'SM9');
    expect(sentUrl.path, endsWith('Messages/SM9.json'));
  });

  test('send uses explicit from: argument over defaultFrom', () async {
    late http.Request sent;
    final c = client(MockClient((req) async {
      sent = req;
      return http.Response(
        jsonEncode({
          'sid': 'SM2',
          'status': 'queued',
          'direction': 'outbound-api',
          'from': '+999',
          'to': '+200',
          'body': 'hi',
          'num_segments': '1',
        }),
        201,
      );
    }));

    await c.send(to: '+200', body: 'hi', from: '+999');

    expect(sent.bodyFields['From'], '+999');
  });

  test('send without from and no defaultFrom throws invalid_argument', () async {
    final c = SmsClient(
      accountSid: 'AC123',
      authToken: 'secret',
      httpClient: MockClient((_) async {
        fail('HTTP should not be called when from is missing');
      }),
    );

    await expectLater(
      c.send(to: '+200', body: 'hi'),
      throwsA(isA<TwilioSmsException>()
          .having((e) => e.code, 'code', 'invalid_argument')
          .having((e) => e.statusCode, 'statusCode', 0)),
    );
  });

  test('send with a malformed 2xx body throws parse_error', () async {
    final c = client(MockClient((_) async => http.Response(
          // Valid JSON but missing "sid".
          '{"status":"queued","direction":"outbound-api"}',
          200,
        )));

    await expectLater(
      c.send(to: '+200', body: 'hi'),
      throwsA(isA<TwilioSmsException>()
          .having((e) => e.code, 'code', 'parse_error')),
    );
  });

  test('5xx with empty body still yields a readable message', () async {
    final c = client(MockClient((_) async => http.Response('', 503)));

    await expectLater(
      c.send(to: '+200', body: 'hi'),
      throwsA(isA<TwilioSmsException>()
          .having((e) => e.statusCode, 'statusCode', 503)
          .having((e) => e.message, 'message', contains('503'))),
    );
  });
}
