# flutter_twilio

Twilio Programmable Voice (VoIP) and REST SMS for Flutter, exposed through a single
`FlutterTwilio.instance` facade. Android + iOS only.

## Why

- One facade for voice and SMS, sharing account credentials in-memory.
- Typed Pigeon bridge to native — no stringly-typed channel method names, no
  ad-hoc `PlatformException` codes at the call site.
- Structured errors: every voice failure is a `VoiceException` subtype with a
  stable `code` string; every SMS failure is a `TwilioSmsException` with the
  raw HTTP status and Twilio-specific error code.
- iOS CallKit + PushKit, Android in-app calling with a foreground audio
  service.

> **New here?** The [getting-started guide](docs/guide.md) walks you from
> `pub get` to a working outbound call in about 20 minutes, with optional
> sections for inbound push calls, SMS, testing, and common pitfalls.

## Platform support

| | Android | iOS |
|---|---|---|
| Voice | ✅ Twilio Voice SDK 6.9 | ✅ Twilio Voice SDK 6.13 |
| SMS | ✅ Twilio REST API | ✅ Twilio REST API |

- Android min SDK: 26
- iOS deployment target: 13.0
- Web and macOS are not supported.

## Install

```yaml
dependencies:
  twilio_voice_sms: ^0.1.0
```

## Initialize

Credentials are held in memory only — they are never written to disk by the
plugin. Initialize once, typically near app startup.

`init` is split along the two subsystems' auth models. **Voice** uses a
short-lived JWT passed to `setAccessToken` per session and needs no
account-level credentials. **SMS** hits Twilio's REST API directly and needs
your Account SID + Auth Token.

```dart
import 'package:twilio_voice_sms/twilio_voice_sms.dart';

// Voice-only (no SMS):
FlutterTwilio.instance.init();

// Voice + SMS:
FlutterTwilio.instance.init(
  accountSid: '<AC...>',
  authToken: '<your Twilio auth token>',
  twilioNumber: '+15551234567', // default "from" for sms.send()
);
```

Accessing `.sms` without providing credentials throws `StateError`; voice
always works after `init()`.

## Voice

```dart
final voice = FlutterTwilio.instance.voice;

// Subscribe once; normal events come through `listen`, failures through `onError`.
voice.events.listen(
  (Call call) {
    // call.event : CallEvent
    // call.active : ActiveCall? (null for non-call events like registered/error)
    if (call.event == CallEvent.connected) {
      // show in-call UI
    }
  },
  onError: (Object e) {
    if (e is VoiceException) {
      // e.code, e.message, e.details
    }
  },
);

await voice.setAccessToken('<twilio voice JWT>');
await voice.register();

// Placing a call returns the ActiveCall snapshot once the SDK has accepted it.
await voice.place(to: '+15557654321');

// Answering an incoming call:
await voice.answer();

// End it:
await voice.hangUp();
```

Full method surface: `setAccessToken`, `register`, `unregister`, `place`,
`answer`, `reject`, `hangUp`, `setMuted`, `setOnHold`, `setSpeaker`,
`sendDigits`, `getActiveCall`, `hasMicPermission`, `requestMicPermission`,
`events`.

## SMS

SMS uses the Twilio REST API directly from Dart — it needs your Account SID
and Auth Token (supplied to `init`). No access token required.

```dart
final sms = FlutterTwilio.instance.sms;

final msg = await sms.send(
  to: '+15557654321',
  body: 'Hi from flutter_twilio',
  // from: '+15551234567', // falls back to twilioNumber from init()
);
print(msg.sid);

final one = await sms.get(sid: msg.sid);
final recent = await sms.list(limit: 20);
```

## Error handling

### Voice

All voice failures arrive as `VoiceException` subtypes, either thrown from a
method call or surfaced through `voice.events.onError`. The shipping
subtypes and their stable `code` strings:

| Subtype | `code` | Thrown from |
|---|---|---|
| `VoiceNotInitializedException` | `not_initialized` | state checks |
| `VoicePermissionDeniedException` | `missing_permission` | mic-gated calls (carries `.permission`) |
| `VoiceInvalidArgumentException` | `invalid_argument` | malformed arguments |
| `VoiceInvalidTokenException` | `invalid_token` | Twilio rejected the JWT |
| `VoiceNoActiveCallException` | `no_active_call` | action requires an active call |
| `VoiceCallAlreadyActiveException` | `call_already_active` | place/answer while another call is live |
| `TwilioSdkException` | `twilio_sdk_error` | SDK failures (carries `twilioCode`, `twilioDomain`) |
| `VoiceAudioSessionException` | `audio_session_error` | AVAudioSession / AudioManager failure |
| `VoiceRegistrationException` | `registration_error` | FCM/PushKit/Twilio register failure (async, via stream) |
| `VoiceConnectionException` | `connection_error` | network / transport failure (async, via stream) |

Unknown codes from future native updates fall through to the base
`VoiceException` so old Dart builds stay forward-compatible.

See [`lib/src/voice/errors.dart`](lib/src/voice/errors.dart) for the full
taxonomy.

### SMS

`TwilioSmsException` exposes:

- `statusCode` — the HTTP status returned by Twilio.
- `twilioCode` — Twilio's error code (e.g. `21211` for invalid "To" number),
  when present.
- `message`, `moreInfo` — human-readable details.

## Setup

### iOS

- Add a PushKit entitlement and upload a VoIP service certificate to Twilio.
- Drop a `callkit_icon.png` into `Assets.xcassets` if you want a custom
  CallKit icon.
- Set `platform :ios, '13.0'` (or higher) in your `ios/Podfile`.

### Android

Add the FCM service to your app manifest so Twilio push notifications reach
the plugin. No phone-account setup, `MANAGE_OWN_CALLS`, or
`BIND_TELECOM_CONNECTION_SERVICE` is needed — the plugin runs calls in-app.

```xml
<application ...>
    <service
        android:name="com.dev.flutter_twilio.fcm.VoiceFirebaseMessagingService"
        android:exported="false"
        android:stopWithTask="false">
        <intent-filter>
            <action android:name="com.google.firebase.MESSAGING_EVENT" />
        </intent-filter>
    </service>
</application>
```

Request microphone permission at runtime before placing or answering a call:

```dart
if (!await FlutterTwilio.instance.voice.hasMicPermission()) {
  await FlutterTwilio.instance.voice.requestMicPermission();
}
```

## Migration from `twilio_voice`

See [`MIGRATION.md`](MIGRATION.md).

## Troubleshooting

### iOS: "Duplicate plugin key" crash at app launch

Symptom: on iOS you see a crash / assertion like
`Duplicate plugin key: twilio_voice` (or `flutter_twilio`) before any of
your code runs. Cause: your dependency tree contains **both** the old
`twilio_voice` package and `flutter_twilio` (usually because a transitive
dependency still pins the old one, or a stale `Podfile.lock` / `Pods/`
directory is lingering).

Fix:

```sh
# 1. remove twilio_voice from pubspec.yaml (+ any transitive overrides)
# 2. clean everything
flutter clean
cd ios && rm -rf Pods Podfile.lock && pod deintegrate && cd ..
flutter pub get
cd ios && pod install && cd ..
```

`flutter_twilio` pins its ObjC class name via `@objc(FlutterTwilioPlugin)`
and guards against being registered twice from the same engine, so the
only way to hit this class of bug now is the two-plugins-in-one-app case
above.

### Pigeon files out of sync

If CI fails the `pigeon-diff` step, regenerate locally and commit:

```sh
./tool/pigeon_generate.sh
git add pigeons lib/src/voice/generated ios/Classes/Generated android/src/main/kotlin/com/dev/flutter_twilio/generated
```

## Changelog

See [`CHANGELOG.md`](CHANGELOG.md).

## License

MIT — see [`LICENSE`](LICENSE). Free to use, modify, and redistribute in
commercial and non-commercial projects.

## Acknowledgments

`flutter_twilio` is a ground-up refactor of the excellent
[`twilio_voice`](https://pub.dev/packages/twilio_voice) plugin
originally authored by [Diego Garcia](https://github.com/diegogarciar) and
maintained by [Charles Dyason](https://github.com/cybex-dev) and
contributors. The in-app Android calling architecture, CallKit/PushKit
integration, and call lifecycle logic inherit from that work.
