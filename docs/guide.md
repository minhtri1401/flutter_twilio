# Adding Twilio voice + SMS to a Flutter app

A practical walk-through of `twilio_voice_sms` — from "pub get" to a working
outbound call and a delivered SMS, with optional upgrades for inbound push
calls. Written for Flutter developers who have not touched the Twilio stack
before.

**Estimated time to first outbound call:** 20 minutes.
**Estimated time to full inbound + outbound with CallKit:** a half day,
most of it spent in the Twilio console and Xcode entitlements UI.

---

## Before you start

You'll need:

- A free [Twilio account](https://www.twilio.com/try-twilio) and at least
  one purchased phone number.
- Flutter `>=3.24.0` (the plugin pins Dart `>=3.3.0`).
- Some backend where you can mint a short-lived Twilio **Voice Access
  Token** (a JWT signed with an API key + secret). Even a single Cloud
  Function or a `/token` endpoint on your existing backend will do. We'll
  cover the shape of the JWT in Part 2.

Optional, only if you want to **receive** calls:

- A Firebase project with Cloud Messaging enabled (Android push transport).
- An Apple Developer account with a VoIP Service Certificate (iOS PushKit
  transport).

If you only plan to **place** calls from the device (outbound dialer,
appointment reminders, support callback widget, etc.), skip the Firebase +
VoIP certificate work entirely — it's not needed for outbound.

---

## The mental model

`twilio_voice_sms` exposes two subsystems behind one facade:

```
          FlutterTwilio.instance
                  │
         ┌────────┴────────┐
         │                 │
        voice             sms
         │                 │
     Pigeon bridge     package:http
         │                 │
   Twilio Voice SDK    Twilio REST API
   (native code)       (pure Dart)
```

- `voice` talks to the **Twilio Voice SDK** on each platform. CallKit on
  iOS, an in-app foreground service on Android. The plugin marshals
  everything across a Pigeon-typed bridge so Dart sees typed DTOs and
  typed exceptions, not stringly-typed method channels.
- `sms` is a pure-Dart HTTP client that hits Twilio's REST Messaging API
  directly. No native code involved; `http` under the hood.

They share credentials via a single `init()` call.

---

## Part 1 — Install and initialize

### 1.1 Add the dependency

```yaml
# pubspec.yaml
dependencies:
  twilio_voice_sms: ^0.1.1
```

Then:

```sh
flutter pub get
```

### 1.2 Platform floors

- **Android:** `minSdkVersion 26` (Android 8.0). Set it in
  `android/app/build.gradle`.
- **iOS:** `platform :ios, '13.0'` in `ios/Podfile`, then `cd ios && pod install`.

### 1.3 Initialize once at app startup

`init` is split along the two subsystems' auth models:

- **Voice** authenticates each session with a short-lived JWT passed
  separately to `voice.setAccessToken(...)`. It does **not** need
  account-level credentials — `init()` with no arguments is enough to
  enable `.voice`.
- **SMS** calls the Twilio REST API directly and needs your Account
  SID + Auth Token. Omit them and any call to `.sms` throws
  `StateError`.

```dart
import 'package:twilio_voice_sms/twilio_voice_sms.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  // Voice-only (most apps):
  FlutterTwilio.instance.init();

  // Or, if you also want SMS — pass both credentials together:
  // FlutterTwilio.instance.init(
  //   accountSid: const String.fromEnvironment('TWILIO_ACCOUNT_SID'),
  //   authToken:  const String.fromEnvironment('TWILIO_AUTH_TOKEN'),
  //   twilioNumber: const String.fromEnvironment('TWILIO_FROM'),
  // );

  runApp(const MyApp());
}
```

Passing one credential without the other throws `ArgumentError` — they're
both halves of the same Basic-auth pair.

Accessing `.voice` or `.sms` before `init` throws `StateError`.

**Security note:** credentials live in memory only; the plugin never
persists them. But if you embed them in the compiled binary (as with
`String.fromEnvironment` or a hard-coded constant), anyone who
decompiles your app gets them. Your **Auth Token** grants access to
your *entire* Twilio account — treat embedding it as a prototype
convenience. In production, put SMS behind your own backend. Voice
JWTs are narrower-scoped and have a short TTL, so the Voice path is
fine because the JWT comes from your backend per session anyway.

---

## Part 2 — Your first outbound call (no push, no Firebase)

This is the simplest useful thing you can do with the plugin: place a
call from a button tap.

### 2.1 Mint a Voice Access Token on your backend

A Twilio Voice Access Token is a JWT that contains a `VoiceGrant`. For
outbound-only you just need `outgoingApplicationSid` — the SID of a
[TwiML Application](https://www.twilio.com/console/voice/twiml/apps)
you've created in the Twilio console. That TwiML App's Voice URL will
be hit when your device says "dial this number"; it returns the TwiML
(`<Dial>+1...</Dial>`) that actually connects the call.

```js
// functions/mintVoiceToken.js  (Firebase Functions, Node.js — illustrative)
const { AccessToken } = require('twilio').jwt;
const { VoiceGrant } = AccessToken;

exports.mintVoiceToken = onCall(async (request) => {
  const identity = request.auth.uid;        // whatever your auth uses
  const token = new AccessToken(
    process.env.TWILIO_ACCOUNT_SID,
    process.env.TWILIO_API_KEY_SID,         // SK...
    process.env.TWILIO_API_KEY_SECRET,
    { identity, ttl: 3600 },                // 1-hour token
  );
  token.addGrant(new VoiceGrant({
    outgoingApplicationSid: process.env.TWILIO_OUTGOING_APP_SID,
    incomingAllow: false,                   // outbound only
  }));
  return { jwt: token.toJwt() };
});
```

Your Flutter app fetches this JWT, caches it in memory, and refreshes
it before the TTL expires.

### 2.2 Hand the JWT to the plugin

```dart
final jwt = await _fetchVoiceTokenFromMyBackend();
await FlutterTwilio.instance.voice.setAccessToken(jwt);
```

That's it. `setAccessToken` just stores the JWT on the native side —
it doesn't talk to Twilio's servers yet. For outbound-only apps, **you
do not need to call `voice.register()`**. Registration is only required
to receive *incoming* calls via push (see Part 3). That surprises people
coming from the old `twilio_voice.setTokens(...)` API, which
registered implicitly — the new API is explicit about this split.

### 2.3 Request microphone permission before placing

```dart
if (!await FlutterTwilio.instance.voice.hasMicPermission()) {
  final ok = await FlutterTwilio.instance.voice.requestMicPermission();
  if (!ok) return;
}
```

Skip this and `place()` will throw `VoicePermissionDeniedException` the
first time. You can handle the exception instead if you prefer a
lazy flow.

### 2.4 Place the call

```dart
try {
  final active = await FlutterTwilio.instance.voice.place(
    to: '+15551234567',
  );
  // `active.sid` is the real Twilio Call SID once the SDK accepts it.
  // The returned ActiveCall is a snapshot; subsequent state comes via events.
} on VoicePermissionDeniedException catch (e) {
  // mic was revoked between request and place
} on VoiceInvalidTokenException catch (e) {
  // refresh the JWT and retry
} on VoiceCallAlreadyActiveException {
  // another call is live; hang up first
} on VoiceException catch (e) {
  // fall-through: e.code has a stable string, e.message is human-readable
}
```

The `ActiveCall` returned tells you the call SID and the initial mute /
hold / speaker state. After that, subscribe to `events`:

### 2.5 Listen to the event stream

```dart
final sub = FlutterTwilio.instance.voice.events.listen(
  (Call c) {
    switch (c.event) {
      case CallEvent.ringing:    /* ringing tone */      break;
      case CallEvent.connected:  /* show in-call UI */   break;
      case CallEvent.disconnected:
      case CallEvent.callEnded:  /* return to idle UI */ break;
      default: break;
    }
    if (c.active != null) _updateCallSnapshot(c.active!);
  },
  onError: (Object e) {
    if (e is VoiceException) _handleVoiceError(e);
  },
);
```

Important: **errors arrive on `onError`, not as `Call` events.** A
`CallEvent.error` event type exists in the Pigeon schema but is
translated inside `VoiceImpl` into an `onError` with a typed
`VoiceException` subtype. You never have to inspect
`call.event == CallEvent.error`.

Cancel the subscription in `dispose()`. The `voice.events` stream is a
broadcast stream, so you can safely listen more than once.

### 2.6 In-call controls

```dart
await voice.setMuted(true);
await voice.setSpeaker(true);
await voice.setOnHold(true);
await voice.sendDigits('1234#');  // DTMF — e.g. for IVR
await voice.hangUp();
```

Each one throws `VoiceNoActiveCallException` if there's no live call.

---

## Part 3 — Receiving incoming calls

This is where the setup burden jumps. Skip Part 3 entirely if your app
only places calls.

### 3.1 Back-end: update the JWT

The same token-mint endpoint now needs an `identity` that Twilio will
route incoming calls to, plus a `pushCredentialSid` specific to each
platform:

```js
const platform = request.data.platform; // 'ios' | 'android', from the client
const pushCredentialSid = platform === 'ios'
  ? process.env.TWILIO_IOS_PUSH_CRED_SID   // tied to your VoIP cert
  : process.env.TWILIO_ANDROID_PUSH_CRED_SID; // tied to your FCM server key

token.addGrant(new VoiceGrant({
  outgoingApplicationSid: process.env.TWILIO_OUTGOING_APP_SID,
  incomingAllow: true,                        // allow inbound
  pushCredentialSid,
}));
```

The identity is whatever string your TwiML app's `<Dial>` verb targets.
If your web side says `<Client>alice</Client>`, the JWT's `identity`
needs to be `"alice"` for that device to receive the call.

### 3.2 Android — Firebase Cloud Messaging

One-time console work:

1. [Create a Firebase project](https://console.firebase.google.com/) or
   reuse an existing one.
2. Add your Android app to it. Download `google-services.json` → drop
   into `android/app/`.
3. In [Twilio Console → Voice → Push Credentials](https://console.twilio.com/us1/develop/voice/manage/push-credentials),
   create a new FCM credential. Paste the FCM server key from Firebase
   Console → Project Settings → Cloud Messaging.
4. Note the resulting `CRxxxxxxx...` SID — that's your
   `TWILIO_ANDROID_PUSH_CRED_SID`.

Android-side app code:

```xml
<!-- android/app/src/main/AndroidManifest.xml -->
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

That's the only manifest entry you need. The plugin handles the FCM
message handoff, token rotation, and the conversion to a
`CallEvent.incoming` event.

### 3.3 iOS — PushKit + CallKit

One-time Apple + Twilio work:

1. In Xcode → target `Runner` → Signing & Capabilities, add:
   - **Push Notifications**
   - **Background Modes** → check **Voice over IP**.
2. In the Apple Developer portal, generate a **VoIP Services
   Certificate** (Certificates, Identifiers & Profiles → `+` →
   Services → VoIP Services Certificate). Export the `.p12`.
3. In the Twilio console, create a push credential of type **APNS** and
   upload the VoIP `.p12` + its password. Note the resulting `CRxxx...`
   SID.

iOS code: nothing. The plugin's `PKPushRegistryDelegate` is already
wired up.

### 3.4 Register the device

Now — and only now, in an app that wants inbound — call `register()`
after handing over the JWT:

```dart
await voice.setAccessToken(jwt);
await voice.register();
```

`register()` returns as soon as the FCM / PushKit fetch is kicked off.
The real result arrives asynchronously on the event stream:

```dart
voice.events.listen((c) {
  if (c.event == CallEvent.registered) { /* device ready for inbound */ }
}, onError: (e) {
  if (e is VoiceRegistrationException) { /* FCM/Twilio unhappy */ }
  if (e is VoiceInvalidTokenException) { /* JWT rejected */ }
});
```

Call `voice.unregister()` when the user logs out, or when you're
rotating to a new identity. Use `setAccessToken` + `register` again to
rotate a JWT without a full unregister.

### 3.5 Handle incoming calls in the UI

```dart
voice.events.listen((c) {
  if (c.event == CallEvent.incoming) {
    // On iOS, CallKit already shows its native incoming-call UI.
    // On Android, this is where YOU show your in-app UI with Answer/Reject.
    setState(() { _incoming = c.active; });
  }
  if (c.event == CallEvent.callEnded ||
      c.event == CallEvent.disconnected ||
      c.event == CallEvent.missedCall ||
      c.event == CallEvent.declined) {
    setState(() { _incoming = null; _active = null; });
  }
});

// User taps Answer:
await voice.answer();
// User taps Reject:
await voice.reject();
```

---

## Part 4 — Sending SMS

No JWT required for SMS. The Account SID + Auth Token you provided to
`init()` are used directly:

```dart
final sms = FlutterTwilio.instance.sms;

final msg = await sms.send(
  to: '+15551234567',
  body: 'Hello from twilio_voice_sms',
  // from: '+15559999999', // optional — falls back to init's twilioNumber
);
print(msg.sid); // SMxxxxxxxx...

final one = await sms.get(sid: msg.sid);
final recent = await sms.list(limit: 20);
```

Error handling:

```dart
try {
  await sms.send(to: to, body: body);
} on TwilioSmsException catch (e) {
  switch (e.twilioCode) {
    case 21211: // Invalid "To" number
      _showFormatError();
      break;
    case 21610: // Number is opted out
      _showOptedOutError();
      break;
    default:
      _showGenericError(e.message, statusCode: e.statusCode);
  }
}
```

**Production warning** (worth repeating from §1.3): embedding the Auth
Token in a mobile app exposes your entire Twilio account to anyone who
extracts it. For anything user-facing, route SMS through your own
backend — your backend holds the Auth Token, and your app calls your
backend. Use `twilio_voice_sms.sms` from the client only for internal
tools, prototypes, or apps with an extremely restricted install base.

---

## Part 5 — Error handling patterns

Every failure from the voice subsystem is a `VoiceException` subtype
with a stable `code` string. Catch by subtype when you know how to
react; fall through to the base `VoiceException` for everything else.

| Subtype | `code` | What to do |
|---|---|---|
| `VoiceNotInitializedException` | `not_initialized` | Call `init()` / `setAccessToken` before retrying. |
| `VoicePermissionDeniedException` | `missing_permission` | Re-request mic; show a "settings" fallback if user denied twice. |
| `VoiceInvalidArgumentException` | `invalid_argument` | Programming error — check the argument, don't retry. |
| `VoiceInvalidTokenException` | `invalid_token` | JWT expired or rejected. Refresh and retry. |
| `VoiceNoActiveCallException` | `no_active_call` | UI should be disabling the button; harmless to ignore. |
| `VoiceCallAlreadyActiveException` | `call_already_active` | Hang up first. |
| `TwilioSdkException` | `twilio_sdk_error` | Inspect `.twilioCode` for specific SDK errors. |
| `VoiceAudioSessionException` | `audio_session_error` | Rare — usually means another app holds the audio session. Retry later. |
| `VoiceRegistrationException` | `registration_error` | Arrives async on the stream; retry `register()` with backoff. |
| `VoiceConnectionException` | `connection_error` | Network or transport dropped. Surface to user; retry on reconnect. |

Unknown codes fall through to base `VoiceException` so old Dart builds
keep working against newer native releases.

### Token refresh pattern

JWTs expire. Twilio recommends 1-hour TTLs. A lightweight pattern:

```dart
class VoiceTokenManager {
  VoiceTokenManager(this._fetchToken);
  final Future<String> Function() _fetchToken;

  String? _jwt;
  DateTime? _expiresAt;

  Future<void> ensureFresh() async {
    if (_jwt != null &&
        _expiresAt != null &&
        _expiresAt!.isAfter(DateTime.now().add(const Duration(minutes: 5)))) {
      return;
    }
    _jwt = await _fetchToken();
    _expiresAt = _decodeExp(_jwt!);
    await FlutterTwilio.instance.voice.setAccessToken(_jwt!);
  }

  Future<void> placeWithRetry({required String to}) async {
    await ensureFresh();
    try {
      await FlutterTwilio.instance.voice.place(to: to);
    } on VoiceInvalidTokenException {
      // Token rejected mid-flight; refetch and retry once.
      _jwt = null;
      await ensureFresh();
      await FlutterTwilio.instance.voice.place(to: to);
    }
  }
}
```

### Handling network drop mid-call

`VoiceConnectionException` arrives on `voice.events.onError` when
transport fails during an active call. The plugin also fires
`CallEvent.reconnecting` when it's attempting recovery, and
`CallEvent.reconnected` or `CallEvent.disconnected` as the final
outcome. Drive your in-call UI off those events; don't treat
`onError` as terminal.

---

## Part 6 — Three recipes

### Recipe A — Outbound-only dialer

Simplest app: a button that calls a fixed support line. Minimal
dependencies. No Firebase, no VoIP certificate, no `register()`.

```dart
class SupportCallButton extends StatefulWidget {
  const SupportCallButton({super.key, required this.jwtProvider});
  final Future<String> Function() jwtProvider;
  @override
  State<SupportCallButton> createState() => _SupportCallButtonState();
}

class _SupportCallButtonState extends State<SupportCallButton> {
  Future<void> _call() async {
    final jwt = await widget.jwtProvider();
    await FlutterTwilio.instance.voice.setAccessToken(jwt);
    if (!await FlutterTwilio.instance.voice.hasMicPermission()) {
      if (!await FlutterTwilio.instance.voice.requestMicPermission()) return;
    }
    await FlutterTwilio.instance.voice.place(to: '+18005551234');
  }
  @override
  Widget build(BuildContext context) => ElevatedButton(
        onPressed: _call, child: const Text('Call support'),
      );
}
```

That's it. No stream subscription required if your UI doesn't care
about ringing/connected; the user hears the call audio through CallKit
(iOS) or the plugin's foreground service (Android) regardless.

### Recipe B — Full VoIP app

Place calls, receive calls, handle CallKit on iOS, show your own
incoming-call UI on Android. The `example/` directory of this repo
is the canonical reference — see `example/lib/main.dart`.

### Recipe C — SMS-only notification sender

Internal admin tool that sends SMS from a single trusted device. No
voice setup at all.

```dart
await FlutterTwilio.instance.init(
  accountSid: kTwilioSid,
  authToken:  kTwilioToken,
  twilioNumber: kTwilioFrom,
);
await FlutterTwilio.instance.sms.send(
  to: customerPhone, body: 'Your order has shipped.',
);
```

You can ignore the voice API entirely; it just doesn't fire.

---

## Part 7 — Testing

**SMS is easy to unit-test.** `SmsClient` takes an injectable
`http.Client`:

```dart
import 'package:http/testing.dart';

test('sends opt-out reply', () async {
  final client = SmsClient(
    accountSid: 'AC_TEST',
    authToken:  'secret',
    defaultFrom: '+15550000000',
    httpClient: MockClient((req) async => http.Response(
      jsonEncode({'sid': 'SMx', 'status': 'queued', 'direction': 'outbound-api',
                  'from': '+15550000000', 'to': '+15551111111',
                  'body': 'STOP', 'num_segments': '1'}),
      201,
    )),
  );
  final msg = await client.send(to: '+15551111111', body: 'STOP');
  expect(msg.sid, 'SMx');
});
```

**Voice is harder** — it goes through a Pigeon-generated `VoiceHostApi`
that speaks to native. You have two good options:

1. **Mock `VoiceApi` at your application boundary** — wrap
   `FlutterTwilio.instance.voice` behind your own interface in the app
   and mock that. This is the normal Flutter-app pattern.
2. **Mock `VoiceHostApi`** — `VoiceImpl` takes an optional `host` in
   its constructor specifically so you can pass a fake. Useful for
   testing your own event-stream reactors.

For integration tests against the real Twilio SDK, use a physical
device with `flutter test integration_test` — emulators don't have the
audio pipeline wired right.

---

## Part 8 — Common pitfalls

### "Duplicate plugin key: twilio_voice" on iOS

You still have the old `twilio_voice` plugin pinned somewhere in your
dependency tree (including transitive deps or a stale
`Podfile.lock`). Clean it out:

```sh
# 1. remove twilio_voice from pubspec.yaml + any overrides
flutter clean
cd ios && rm -rf Pods Podfile.lock && pod deintegrate && cd ..
flutter pub get
cd ios && pod install && cd ..
```

`twilio_voice_sms` pins its Objective-C class name via
`@objc(FlutterTwilioPlugin)` and guards against being registered twice
from the same engine, so the only way to hit the duplicate-key bug now
is the two-plugins-coexisting case above.

### "Not initialized" on the first voice call

`FlutterTwilio.instance.init(...)` must run before any `.voice`
access. Accessing `.voice` or `.sms` before `init` throws
`StateError`. Confirm your `runApp(...)` is **after** your `init(...)`
call in `main()`.

### Nothing happens when I place a call on a fresh install

Most likely microphone permission was never requested. `place` will
throw `VoicePermissionDeniedException` — catch it, call
`requestMicPermission()`, then retry.

### `register()` succeeds but no incoming calls arrive

Three common causes:
1. The JWT didn't include a `pushCredentialSid` for the right
   platform. Open the token at [jwt.io](https://jwt.io/) and confirm.
2. The `identity` baked into the JWT doesn't match the TwiML your
   server returns — your `<Dial><Client>alice</Client>` target must
   exactly equal the JWT's `identity` claim.
3. The Firebase / VoIP Service Certificate Push Credential in the
   Twilio console is stale (expired, or uploaded from a different
   certificate than the one embedded in your current build).

Check the `CallEvent.registered` event fired (not just that
`register()` returned); that confirms Twilio actually received and
accepted the device binding.

### `place()` returns a `sid` of `"unknown"` on iOS

This is a bug that was fixed in 0.1.0. Make sure you're not on an
older pre-release.

### Hot restart leaves stale call state

Hot restart does not tear down the native plugin side. If you
hot-restart mid-call, the call continues on native until you explicitly
`hangUp()` or the remote end disconnects. Build a "reset" path into
your dev workflow, e.g. tap a hangup button before hot-restarting.

---

## Where to go next

- **[API reference](https://pub.dev/documentation/twilio_voice_sms/latest/)** —
  every public class and method, with dartdoc.
- **[example/](../example/)** — single-screen Flutter app exercising
  init, register, place, answer, reject, hang up, mute, hold, speaker,
  DTMF, and SMS send.
- **[MIGRATION.md](../MIGRATION.md)** — if you're moving from the old
  `twilio_voice` plugin.
- **[CHANGELOG.md](../CHANGELOG.md)** — what shipped in each release.
- **[Twilio Voice Quickstart](https://www.twilio.com/docs/voice/sdks)** —
  authoritative docs for the underlying SDKs and TwiML.
- **[Twilio Programmable Messaging](https://www.twilio.com/docs/messaging)** —
  the REST API the SMS client wraps.

Bugs and feature requests → [GitHub issues](https://github.com/minhtri1401/flutter_twilio/issues).
