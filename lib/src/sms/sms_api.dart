import 'models/message.dart';

/// Public SMS surface. Implemented by [SmsClient].
abstract class SmsApi {
  Future<Message> send({
    required String to,
    required String body,
    String? from,
  });

  Future<Message> get({required String sid});

  Future<List<Message>> list({int? limit, String? to, String? from});
}
