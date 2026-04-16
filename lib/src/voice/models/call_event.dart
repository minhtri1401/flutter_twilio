import '../generated/voice_api.g.dart';

/// Public-facing enum mirroring every value in `CallEventType`.
/// Update both enums together.
enum CallEvent {
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
  error;

  static CallEvent fromPigeon(CallEventType type) {
    switch (type) {
      case CallEventType.registered:
        return CallEvent.registered;
      case CallEventType.unregistered:
        return CallEvent.unregistered;
      case CallEventType.registrationFailed:
        return CallEvent.registrationFailed;
      case CallEventType.incoming:
        return CallEvent.incoming;
      case CallEventType.ringing:
        return CallEvent.ringing;
      case CallEventType.connecting:
        return CallEvent.connecting;
      case CallEventType.connected:
        return CallEvent.connected;
      case CallEventType.reconnecting:
        return CallEvent.reconnecting;
      case CallEventType.reconnected:
        return CallEvent.reconnected;
      case CallEventType.disconnected:
        return CallEvent.disconnected;
      case CallEventType.callEnded:
        return CallEvent.callEnded;
      case CallEventType.answer:
        return CallEvent.answer;
      case CallEventType.reject:
        return CallEvent.reject;
      case CallEventType.declined:
        return CallEvent.declined;
      case CallEventType.missedCall:
        return CallEvent.missedCall;
      case CallEventType.returningCall:
        return CallEvent.returningCall;
      case CallEventType.hold:
        return CallEvent.hold;
      case CallEventType.unhold:
        return CallEvent.unhold;
      case CallEventType.mute:
        return CallEvent.mute;
      case CallEventType.unmute:
        return CallEvent.unmute;
      case CallEventType.speakerOn:
        return CallEvent.speakerOn;
      case CallEventType.speakerOff:
        return CallEvent.speakerOff;
      case CallEventType.error:
        return CallEvent.error;
    }
  }
}
