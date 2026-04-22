# Migration: twilio_voice → flutter_twilio

This release renames the package from `twilio_voice` to `flutter_twilio` and
restructures the public API. The scope has also narrowed: Web and macOS are
no longer supported, and the Android side runs calls in-app (no more
`ConnectionService` or phone-account setup).

The original `twilio_voice → in-app calling` migration notes are preserved
further below for any apps still working through that Android rewrite — the
sections apply transitively after you finish the steps in this one.

---

## 1. pubspec.yaml

```yaml
# Before
dependencies:
  twilio_voice: ^0.3.2+2

# After
dependencies:
  twilio_voice_sms: ^0.1.1
```

## 2. Imports and class rename

There is a single import and a single facade. The old `TwilioVoice.instance`
surface is replaced by `FlutterTwilio.instance.voice`; a new
`FlutterTwilio.instance.sms` sibling exposes SMS.

```dart
// Before
import 'package:twilio_voice/twilio_voice.dart';
final tv = TwilioVoice.instance;

// After
import 'package:twilio_voice_sms/twilio_voice_sms.dart';
final voice = FlutterTwilio.instance.voice;
final sms   = FlutterTwilio.instance.sms;
```

## 3. `init()` + explicit register flow

The old plugin's `setTokens(accessToken, deviceToken)` collapsed three
concerns into a single call: (a) storing Twilio account credentials,
(b) handing the plugin an FCM device token you had to fetch via
`firebase_messaging`, (c) registering the device with Twilio's servers so
incoming calls could be push-delivered. All three are now explicit steps,
**and the plugin fetches its own FCM token internally** — you no longer
need `firebase_messaging` in your app just to feed Twilio. (You still
need the Firebase project + google-services.json so Twilio's push reaches
the device.)

```dart
// Before
await tv.setTokens(
  accessToken: '<twilio-voice-JWT>',
  deviceToken: '<fcm-token-you-fetched>', // Android only
);

// After
FlutterTwilio.instance.init(
  accountSid: '<AC...>',
  authToken: '<account-auth-token>',
  twilioNumber: '+15551234567',           // default "from" for SMS + outbound calls
);
await FlutterTwilio.instance.voice.setAccessToken('<twilio-voice-JWT>');
await FlutterTwilio.instance.voice.register();
```

`setAccessToken` only stores the JWT. `register()` is what actually talks to
Twilio — it kicks off the FCM token fetch and calls `Voice.register(...)`.
The method returns as soon as the fetch is initiated; the real result
arrives asynchronously on `voice.events`:

- Success → a `Call` with `event: CallEvent.registered`.
- Failure → `onError` with `VoiceRegistrationException` (generic failures) or
  `VoiceInvalidTokenException` (Twilio rejected the JWT — codes 20101 /
  20104 / 20157).

To rotate the JWT without fully unregistering, call `setAccessToken` with
the new value and `register()` again.

## 4. Platform support reduced

Web and macOS are no longer supported. If your app targeted either of them,
you'll need to remove those targets or stay on `twilio_voice` 0.3.x.

| Platform | twilio_voice 0.3 | flutter_twilio 0.1 |
|---|---|---|
| Android | ✅ | ✅ |
| iOS | ✅ | ✅ |
| Web | ✅ | ❌ |
| macOS | ✅ | ❌ |

## 5. Android package rename

The Android plugin moved from `com.twilio.twilio_voice` to
`com.dev.flutter_twilio`. Your app's `AndroidManifest.xml` FCM service entry
needs updating:

```xml
<!-- Before -->
<service
    android:name="com.twilio.twilio_voice.fcm.VoiceFirebaseMessagingService"
    android:exported="false"
    android:stopWithTask="false">
    <intent-filter>
        <action android:name="com.google.firebase.MESSAGING_EVENT" />
    </intent-filter>
</service>

<!-- After -->
<service
    android:name="com.dev.flutter_twilio.fcm.VoiceFirebaseMessagingService"
    android:exported="false"
    android:stopWithTask="false">
    <intent-filter>
        <action android:name="com.google.firebase.MESSAGING_EVENT" />
    </intent-filter>
</service>
```

No phone-account setup, `MANAGE_OWN_CALLS`, or
`BIND_TELECOM_CONNECTION_SERVICE` is needed — that was retired in the
in-app-calling migration below and stays retired here.

## 6. iOS deployment target

Minimum `ios/Podfile` target is **13.0** (was 11.0 in early `twilio_voice`
releases, raised to 13.0 in the in-app-calling migration).

```ruby
platform :ios, '13.0'
```

## 7. Error handling: typed exceptions

Every voice failure now arrives as a `VoiceException` subtype with a
stable `code` string — either thrown directly from a method call or
surfaced as `onError` on `voice.events`. Catch by subtype, not by parsing
`PlatformException.code`.

```dart
try {
  await FlutterTwilio.instance.voice.register();
} on VoiceInvalidTokenException catch (e) {
  // refresh and retry
} on VoiceException catch (e) {
  // e.code, e.message, e.details
}
```

Stable voice codes:

| Subtype | `code` | Thrown from |
|---|---|---|
| `VoiceNotInitializedException` | `not_initialized` | state checks |
| `VoicePermissionDeniedException` | `missing_permission` | mic-gated calls (carries `.permission`) |
| `VoiceInvalidArgumentException` | `invalid_argument` | malformed arguments |
| `VoiceInvalidTokenException` | `invalid_token` | Twilio rejected the JWT |
| `VoiceNoActiveCallException` | `no_active_call` | action requires an active call |
| `VoiceCallAlreadyActiveException` | `call_already_active` | place/answer while another call is live |
| `TwilioSdkException` | `twilio_sdk_error` | carries `twilioCode`, `twilioDomain` |
| `VoiceAudioSessionException` | `audio_session_error` | AVAudioSession / AudioManager failure |
| `VoiceRegistrationException` | `registration_error` | FCM / PushKit / Twilio register failure (async, via stream) |
| `VoiceConnectionException` | `connection_error` | network / transport failure (async, via stream) |

Unknown codes from future native updates fall through to the base
`VoiceException` so old Dart builds stay forward-compatible.

SMS failures are `TwilioSmsException` with `statusCode` (HTTP status) and
`twilioCode` (Twilio error code, e.g. `21211`). Malformed Twilio 2xx
responses are caught as `TwilioSmsException(code: 'parse_error')` rather
than leaking a raw `TypeError`.

## 8. New SMS surface

Twilio REST SMS is now a first-class sibling of voice, using the account
credentials supplied to `init`:

```dart
final sms = FlutterTwilio.instance.sms;

final msg    = await sms.send(to: '+15557654321', body: 'hi');
final one    = await sms.get(sid: msg.sid);
final recent = await sms.list(limit: 20);
```

## 9. Removed methods from the old API

The following `twilio_voice` methods are **gone** — not renamed, not
deprecated. If you relied on them, design around them before migrating.

| Removed method(s) | Why |
|---|---|
| `registerPhoneAccount()`, `hasRegisteredPhoneAccount()`, `isPhoneAccountEnabled()`, `openPhoneAccountSettings()`, `hasManageOwnCallsPermission()`, `requestManageOwnCallsPermission()` | Android no longer uses `ConnectionService`; there is no phone account to register. |
| `toggleBluetooth(bluetoothOn:)` / `hasBluetoothPermissions()` / `requestBluetoothPermissions()` | Bluetooth routing is now handled by the OS through the audio route picker; the plugin no longer exposes a manual toggle. |
| `updateCallKitIcon(icon:)` | CallKit icon is sourced from `Assets.xcassets/callkit_icon.png` at build time. |
| `registerClient(id, name)`, `unregisterClient(id)`, `setDefaultCallerName(name)` | The multi-client name-resolution layer was dropped. Handle caller-name display in your app or pass names through the TwiML `__TWI_*` custom parameters (still supported via `ActiveCall.customParameters`). |
| `requiresBackgroundPermissions()`, `requestBackgroundPermissions()`, `showBackgroundCallUI()` | Custom background call UI was retired during the in-app-calling migration. |
| `rejectCallOnNoPermissions()` / `isRejectingCallOnNoPermissions()` | Tied to the `CALL_PHONE` permission group that is no longer required. |

## 10. Method renames (voice)

Most of the kept methods moved off `.call` and onto `.voice` directly, with
parameter-name tidies:

| Before | After | Notes |
|---|---|---|
| `TwilioVoice.instance.setTokens(accessToken: ...)` | `FlutterTwilio.instance.voice.setAccessToken(...)` + `voice.register()` | **Behavioral split.** Old `setTokens` stored the token *and* registered with Twilio in one call. New `setAccessToken` only stores; you must follow with `voice.register()`. See §3. |
| `setTokens(deviceToken: '<fcm>')` | _(removed)_ | The FCM device token is now fetched by the plugin via `FirebaseMessaging.getInstance().token`. Your code should no longer pass it in. |
| _(none — was implicit inside `setTokens`)_ | `FlutterTwilio.instance.voice.register()` | New explicit step; result arrives on `voice.events` (see §3). |
| `TwilioVoice.instance.unregister()` | `FlutterTwilio.instance.voice.unregister()` | Semantic parity. |
| `TwilioVoice.instance.call.place(from:, to:, extraOptions:)` | `FlutterTwilio.instance.voice.place(to:, from:, extra:)` |
| `TwilioVoice.instance.call.answer()` | `FlutterTwilio.instance.voice.answer()` |
| `TwilioVoice.instance.call.hangUp()` | `FlutterTwilio.instance.voice.hangUp()` |
| `TwilioVoice.instance.call.toggleMute(isMuted:)` | `FlutterTwilio.instance.voice.setMuted(bool)` |
| `TwilioVoice.instance.call.toggleSpeaker(speakerIsOn:)` | `FlutterTwilio.instance.voice.setSpeaker(bool)` |
| `TwilioVoice.instance.call.holdCall(shouldHold:)` | `FlutterTwilio.instance.voice.setOnHold(bool)` |
| `TwilioVoice.instance.call.sendDigits(digits)` | `FlutterTwilio.instance.voice.sendDigits(digits)` |
| `TwilioVoice.instance.hasMicAccess()` / `requestMicAccess()` | `FlutterTwilio.instance.voice.hasMicPermission()` / `requestMicPermission()` |
| `TwilioVoice.instance.callEventsListener` (stream of `CallEvent`) | `FlutterTwilio.instance.voice.events` (stream of `Call { event, active }`) |

---

# Legacy: twilio_voice in-app calling migration

The sections below are the original migration notes for moving from the
`ConnectionService`-based Android implementation to in-app calling within
the legacy `twilio_voice` package. They remain relevant if you're coming
from `twilio_voice` 0.2.x or earlier.

> **Note on code samples in this legacy section:** examples here use the
> old `TwilioVoicePlatform.instance` / `tv.setTokens` / `tv.call.place`
> API, not the new `FlutterTwilio.instance.voice` facade. For the current
> package's API, see §1–10 above.

---

## Android: In-App Calling (Breaking Architecture Change)

### What changed

The Android implementation previously used Android's `ConnectionService` / `TelecomManager`, which routes calls through the system call UI (the native dialer). This has been replaced with a custom in-app calling architecture:

| | Before | After |
|--|--------|-------|
| Call UI | System dialer / native call screen | Your Flutter UI |
| Audio management | `ConnectionService` audio focus | `TVCallAudioService` foreground service |
| Phone account required | Yes | **No** |
| `MANAGE_OWN_CALLS` permission | Required | Not required |
| Min SDK | 26 | 26 (unchanged) |

Calls now stay inside your application. The system dialer will no longer appear.

### Required: AndroidManifest.xml

Your app's `AndroidManifest.xml` no longer needs the phone account or `MANAGE_OWN_CALLS` entries. The plugin now declares its foreground service automatically — no extra entries are required in your app manifest beyond the existing FCM service:

```xml
<manifest ...>
    <!-- FCM service — already in your manifest -->
    <application>
        <service
            android:name="com.twilio.twilio_voice.fcm.VoiceFirebaseMessagingService"
            android:exported="false"
            android:stopWithTask="false">
            <intent-filter>
                <action android:name="com.google.firebase.MESSAGING_EVENT" />
            </intent-filter>
        </service>
    </application>
</manifest>
```

**Remove** any of the following if present — they are no longer needed:

```xml
<!-- Remove these -->
<uses-permission android:name="android.permission.MANAGE_OWN_CALLS" />
<uses-permission android:name="android.permission.BIND_TELECOM_CONNECTION_SERVICE" />
```

### Required: Runtime permissions

Because calls run in-app, you need microphone permission before placing or answering a call. Request it at app startup or before the first call:

```dart
final tv = TwilioVoicePlatform.instance;

// Check
final hasMic = await tv.hasMicAccess();

// Request
if (!hasMic) {
  await tv.requestMicAccess();
}
```

The `CALL_PHONE` and `READ_PHONE_STATE` permissions are still needed for some features (caller ID, call log integration). Request them as appropriate for your app.

### Removed: Phone account setup flow

If your app previously walked the user through registering a phone account, remove that flow. These methods are now deprecated no-ops:

```dart
// Before — required setup flow
await tv.registerPhoneAccount();
final enabled = await tv.isPhoneAccountEnabled();
if (!enabled) {
  await tv.openPhoneAccountSettings();
}

// After — delete the above. Not needed.
```

---

## Deprecated Methods

The following methods are deprecated and will be removed in a future version. They still work and return graceful defaults, so existing apps will not crash.

### Phone account methods (Android only — all no-ops returning `true`)

| Deprecated method | Reason |
|-------------------|--------|
| `registerPhoneAccount()` | Phone accounts not used |
| `hasRegisteredPhoneAccount()` | Phone accounts not used |
| `isPhoneAccountEnabled()` | Phone accounts not used |
| `openPhoneAccountSettings()` | Phone accounts not used |

### Permission methods (Android only)

| Deprecated method | Reason |
|-------------------|--------|
| `hasManageOwnCallsPermission()` | No longer required for in-app calling |
| `requestManageOwnCallsPermission()` | No longer required for in-app calling |

### Already-deprecated methods (unchanged)

These were deprecated in earlier releases and remain deprecated:

| Method | Reason |
|--------|--------|
| `requiresBackgroundPermissions()` | Custom call UI removed |
| `requestBackgroundPermissions()` | Custom call UI removed |
| `hasBluetoothPermissions()` | Handled natively |
| `requestBluetoothPermissions()` | Handled natively |
| `showBackgroundCallUI()` | Custom call UI removed |

---

## Minimum Requirements

| Platform | Requirement |
|----------|-------------|
| Android | Min SDK 26 (Android 8.0) — unchanged |
| iOS | Min deployment target 13.0 (raised from 11.0) |
| Flutter | `>=1.10.0` — unchanged |

---

## Typical Setup After Migration

### 1. Register tokens

```dart
final tv = TwilioVoicePlatform.instance;

await tv.setTokens(
  accessToken: '<your-twilio-access-token>',
  deviceToken: '<fcm-device-token>', // Android only; iOS handled internally
);
```

### 2. Request permissions (Android)

```dart
// Microphone — required for all calls
await tv.requestMicAccess();

// Read phone state — for caller ID features
await tv.requestReadPhoneStatePermission();

// Call phone — for placing outgoing calls
await tv.requestCallPhonePermission();
```

### 3. Listen for call events

```dart
tv.callEventsListener.listen((event) {
  switch (event) {
    case CallEvent.incoming:
      // Show incoming call UI
      break;
    case CallEvent.connected:
      // Show in-call UI
      break;
    case CallEvent.callEnded:
      // Return to idle UI
      break;
    default:
      break;
  }
});
```

### 4. Place a call

```dart
// Using place() — explicit from/to
await tv.call.place(from: 'alice', to: '+15551234567');

// Using connect() — pass arbitrary params to your TwiML app
await tv.call.connect(extraOptions: {
  'To': '+15551234567',
  'accessToken': '<token>',
});
```

### 5. Answer / hang up

```dart
// Answer incoming call
await tv.call.answer();

// Hang up
await tv.call.hangUp();
```

### 6. Audio controls

```dart
// Speaker
await tv.call.toggleSpeaker(true);

// Mute
await tv.call.toggleMute(true);

// Bluetooth (iOS/Android)
await tv.call.toggleBluetooth(bluetoothOn: true);
```

---

## iOS: No Breaking Changes

iOS uses CallKit and PushKit — the architecture is unchanged. The only change is the minimum deployment target raised to **iOS 13.0** (from 11.0).

If your `ios/Podfile` sets a lower minimum:

```ruby
# Before
platform :ios, '11.0'

# After
platform :ios, '13.0'
```

---

## Summary of Removed Requirements

| Item | Required before | Required now |
|------|----------------|--------------|
| Android phone account registration | Yes | No |
| `MANAGE_OWN_CALLS` permission | Yes | No |
| `BIND_TELECOM_CONNECTION_SERVICE` permission | Yes | No |
| System call UI consent | Yes | No |
| Microphone permission before call | Recommended | **Required** |
