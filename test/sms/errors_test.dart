import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_twilio/src/sms/errors.dart';

void main() {
  test('fromResponseBody parses Twilio error envelope', () {
    const body =
        '{"code":21211,"message":"Invalid \\"To\\" phone","more_info":"https://..","status":400}';
    final e = TwilioSmsException.fromResponseBody(400, body);
    expect(e.statusCode, 400);
    expect(e.twilioCode, 21211);
    expect(e.message, contains('Invalid'));
    expect(e.moreInfo, startsWith('https://'));
  });

  test('falls back gracefully when body is not JSON', () {
    final e = TwilioSmsException.fromResponseBody(500, 'Internal Server Error');
    expect(e.statusCode, 500);
    expect(e.twilioCode, isNull);
    expect(e.message, contains('Internal Server Error'));
  });

  test('connection factory yields statusCode=0, code=connection_error', () {
    final e = TwilioSmsException.connection('lost');
    expect(e.statusCode, 0);
    expect(e.code, 'connection_error');
    expect(e.message, 'lost');
  });
}
