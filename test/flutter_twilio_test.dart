import 'package:flutter_test/flutter_test.dart';
import 'package:twilio_voice_sms/src/flutter_twilio.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  tearDown(() => FlutterTwilio.instance.resetForTesting());

  test('accessing voice/sms before init throws StateError', () {
    expect(() => FlutterTwilio.instance.voice, throwsStateError);
    expect(() => FlutterTwilio.instance.sms, throwsStateError);
  });

  test('init() with no arguments enables voice and leaves sms disabled', () {
    FlutterTwilio.instance.init();
    expect(FlutterTwilio.instance.voice, isNotNull);
    expect(() => FlutterTwilio.instance.sms, throwsStateError);
  });

  test('init with full credentials enables both voice and sms', () {
    FlutterTwilio.instance
        .init(accountSid: 'AC', authToken: 'tok', twilioNumber: '+1');
    expect(FlutterTwilio.instance.voice, isNotNull);
    expect(FlutterTwilio.instance.sms, isNotNull);
  });

  test('init without twilioNumber still enables sms (only defaultFrom is lost)',
      () {
    FlutterTwilio.instance.init(accountSid: 'AC', authToken: 'tok');
    expect(FlutterTwilio.instance.sms, isNotNull);
    expect(FlutterTwilio.instance.twilioNumberForTesting, isNull);
  });

  test('init with only accountSid throws ArgumentError', () {
    expect(
      () => FlutterTwilio.instance.init(accountSid: 'AC'),
      throwsArgumentError,
    );
  });

  test('init with only authToken throws ArgumentError', () {
    expect(
      () => FlutterTwilio.instance.init(authToken: 'tok'),
      throwsArgumentError,
    );
  });

  test('init overrides credentials', () {
    FlutterTwilio.instance
        .init(accountSid: 'AC', authToken: 'tok', twilioNumber: '+1');
    FlutterTwilio.instance
        .init(accountSid: 'AC2', authToken: 'tok2', twilioNumber: '+2');
    expect(FlutterTwilio.instance.accountSidForTesting, 'AC2');
    expect(FlutterTwilio.instance.twilioNumberForTesting, '+2');
  });

  test('re-init from voice-only to full credentials enables sms', () {
    FlutterTwilio.instance.init();
    expect(() => FlutterTwilio.instance.sms, throwsStateError);
    FlutterTwilio.instance.init(accountSid: 'AC', authToken: 'tok');
    expect(FlutterTwilio.instance.sms, isNotNull);
  });

  test('re-init dropping credentials disables sms again', () {
    FlutterTwilio.instance.init(accountSid: 'AC', authToken: 'tok');
    expect(FlutterTwilio.instance.sms, isNotNull);
    FlutterTwilio.instance.init();
    expect(() => FlutterTwilio.instance.sms, throwsStateError);
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
