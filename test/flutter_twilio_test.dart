import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_twilio/src/flutter_twilio.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  tearDown(() => FlutterTwilio.instance.resetForTesting());

  test('accessing voice/sms before init throws StateError', () {
    expect(() => FlutterTwilio.instance.voice, throwsStateError);
    expect(() => FlutterTwilio.instance.sms, throwsStateError);
  });

  test('init enables voice and sms access', () {
    FlutterTwilio.instance
        .init(accountSid: 'AC', authToken: 'tok', twilioNumber: '+1');
    expect(FlutterTwilio.instance.voice, isNotNull);
    expect(FlutterTwilio.instance.sms, isNotNull);
  });

  test('init overrides credentials', () {
    FlutterTwilio.instance
        .init(accountSid: 'AC', authToken: 'tok', twilioNumber: '+1');
    FlutterTwilio.instance
        .init(accountSid: 'AC2', authToken: 'tok2', twilioNumber: '+2');
    expect(FlutterTwilio.instance.accountSidForTesting, 'AC2');
    expect(FlutterTwilio.instance.twilioNumberForTesting, '+2');
  });

  test('resetForTesting returns the facade to uninitialized state', () {
    FlutterTwilio.instance
        .init(accountSid: 'AC', authToken: 'tok', twilioNumber: '+1');
    FlutterTwilio.instance.resetForTesting();
    expect(() => FlutterTwilio.instance.voice, throwsStateError);
    expect(() => FlutterTwilio.instance.sms, throwsStateError);
    expect(FlutterTwilio.instance.accountSidForTesting, isNull);
  });
}
