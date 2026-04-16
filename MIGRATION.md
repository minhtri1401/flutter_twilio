# Migration Guide — twilio_voice upgrade

This document covers migration steps for the upcoming release, which includes significant changes on Android and deprecations on both platforms.

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
