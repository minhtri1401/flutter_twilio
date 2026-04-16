import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_twilio/src/flutter_twilio.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('accessing voice/sms before init throws StateError', () {
    final t = FlutterTwilio.newForTesting();
    expect(() => t.voice, throwsStateError);
    expect(() => t.sms, throwsStateError);
  });

  test('init enables voice and sms access', () {
    final t = FlutterTwilio.newForTesting();
    t.init(accountSid: 'AC', authToken: 'tok', twilioNumber: '+1');
    expect(t.voice, isNotNull);
    expect(t.sms, isNotNull);
  });

  test('init overrides credentials', () {
    final t = FlutterTwilio.newForTesting();
    t.init(accountSid: 'AC', authToken: 'tok', twilioNumber: '+1');
    t.init(accountSid: 'AC2', authToken: 'tok2', twilioNumber: '+2');
    expect(t.accountSidForTesting, 'AC2');
    expect(t.twilioNumberForTesting, '+2');
  });
}
