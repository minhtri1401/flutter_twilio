// ignore_for_file: public_member_api_docs
import 'package:pigeon/pigeon.dart';

@ConfigurePigeon(PigeonOptions(
  dartOut: 'lib/src/voice/generated/voice_api.g.dart',
  dartOptions: DartOptions(),
  kotlinOut:
      'android/src/main/kotlin/com/dev/flutter_twilio/generated/VoiceApi.g.kt',
  kotlinOptions: KotlinOptions(package: 'com.dev.flutter_twilio.generated'),
  swiftOut: 'ios/Classes/Generated/VoiceApi.g.swift',
  swiftOptions: SwiftOptions(),
  dartPackageName: 'flutter_twilio',
))
enum CallDirection { incoming, outgoing }

/// Mirrors Dart's CallEvent enum. Keep this in sync 1:1 with
/// lib/src/voice/models/call_event.dart — add new values to both sides.
enum CallEventType {
  registered,
  unregistered,
  registrationFailed,
  incoming,
  ringing,
  connecting,
  connected,
  reconnecting,
  reconnected,
  disconnected,
  callEnded,
  answer,
  reject,
  declined,
  missedCall,
  returningCall,
  hold,
  unhold,
  mute,
  unmute,
  speakerOn,
  speakerOff,
  error,
}

class ActiveCallDto {
  ActiveCallDto({
    required this.sid,
    required this.from,
    required this.to,
    required this.direction,
    required this.startedAt,
    required this.isMuted,
    required this.isOnHold,
    required this.isOnSpeaker,
    this.customParameters,
  });

  String sid;
  String from;
  String to;
  CallDirection direction;
  int startedAt; // epoch millis
  bool isMuted;
  bool isOnHold;
  bool isOnSpeaker;
  Map<String?, String?>? customParameters;
}

class CallErrorDto {
  CallErrorDto({
    required this.code,
    required this.message,
    this.details,
  });

  String code;
  String message;
  Map<String?, Object?>? details;
}

class CallEventDto {
  CallEventDto({
    required this.type,
    this.activeCall,
    this.error,
  });

  CallEventType type;
  ActiveCallDto? activeCall;
  CallErrorDto? error;
}

class PlaceCallRequest {
  PlaceCallRequest({
    required this.to,
    this.from,
    this.extraParameters,
  });

  String to;
  String? from;
  Map<String?, String?>? extraParameters;
}

@HostApi()
abstract class VoiceHostApi {
  @async
  void setAccessToken(String token);

  @async
  void register();

  @async
  void unregister();

  @async
  ActiveCallDto place(PlaceCallRequest request);

  @async
  void answer();

  @async
  void reject();

  @async
  void hangUp();

  @async
  void setMuted(bool muted);

  @async
  void setOnHold(bool onHold);

  @async
  void setSpeaker(bool onSpeaker);

  @async
  void sendDigits(String digits);

  @async
  ActiveCallDto? getActiveCall();

  @async
  bool hasMicPermission();

  @async
  bool requestMicPermission();
}

@FlutterApi()
abstract class VoiceFlutterApi {
  /// Native → Dart stream of call events (including `CallEventType.error`).
  void onCallEvent(CallEventDto event);
}
