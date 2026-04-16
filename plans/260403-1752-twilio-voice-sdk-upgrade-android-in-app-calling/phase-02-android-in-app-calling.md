# Phase 02: Android In-App Calling (CRITICAL)

## Context Links

- [Plan Overview](plan.md)
- [In-App Calling Research](research/researcher-02-android-in-app-calling-report.md)
- [Scout Report](scout/scout-01-codebase-report.md)

## Overview

- **Priority:** P1 (primary goal of entire project)
- **Status:** complete
- **Effort:** 2.5h
- **Description:** Remove ConnectionService/TelecomManager dependency. Calls stay inside Flutter app UI on Android.

## Key Insights

- **Root cause:** `TVConnectionService extends ConnectionService()` + `TelecomManager.addNewIncomingCall()` forces system call UI
- **Fix:** Replace with custom `TVCallManager` (call state) + `TVCallAudioService extends Service` (foreground audio session)
- **Twilio SDK supports standalone mode:** `callInvite.accept(context, listener)` works without ConnectionService
- Current flow: FCM -> TVConnectionService -> TelecomManager -> System UI -> Connection callbacks
- New flow: FCM -> VoiceFirebaseMessagingService -> MethodChannel event to Dart -> Flutter UI -> Dart calls accept/reject -> Kotlin calls SDK
- Dart-side MethodChannel methods (answer, hangUp, makeCall) remain unchanged; only Kotlin implementation changes
- `TVBroadcastReceiver` can be simplified; LocalBroadcast is deprecated anyway

## Requirements

### Functional
- Incoming calls show Flutter in-app UI (no system call screen popup)
- Outgoing calls initiated from Flutter UI without system UI
- Answer, reject, hangUp, hold, mute, speaker, bluetooth all work via MethodChannel
- Call state events (ringing, connected, disconnected, etc.) delivered to Dart EventChannel
- Foreground notification displayed during active calls (Android requirement)
- Calls work when app is in foreground and background

### Non-Functional
- Audio session maintained via foreground service
- Compliant with Android 14+ foreground service restrictions
- No `BIND_TELECOM_CONNECTION_SERVICE` or `MANAGE_OWN_CALLS` permissions required
- Files kept under 200 lines each

## Architecture

### Current Architecture (to be removed)
```
FCM -> VoiceFirebaseMessagingService
  -> Intent(TVConnectionService.ACTION_INCOMING_CALL)
  -> TVConnectionService.onStartCommand()
  -> TelecomManager.addNewIncomingCall()  <-- SYSTEM UI TRIGGER
  -> onCreateIncomingConnection() -> TVCallInviteConnection
  -> Connection callbacks (onAnswer, onDisconnect)
  -> LocalBroadcast -> TVBroadcastReceiver -> TwilioVoicePlugin -> EventChannel
```

### New Architecture
```
FCM -> VoiceFirebaseMessagingService
  -> TVCallManager.handleCallInvite(callInvite)
  -> TVCallManager emits event via callback -> TwilioVoicePlugin -> EventChannel to Dart
  -> Dart shows in-app call UI
  -> User taps Accept -> Dart calls MethodChannel("answer")
  -> TwilioVoicePlugin -> TVCallManager.acceptCall()
  -> callInvite.accept(context, callListener) -> Twilio SDK handles media
  -> TVCallAudioService starts as foreground service (notification + audio focus)
  -> Call.Listener events -> TVCallManager -> TwilioVoicePlugin -> EventChannel
```

### New Classes

| Class | Responsibility | Max Lines |
|-------|---------------|-----------|
| `TVCallManager` | Hold active CallInvite/Call, manage call state, implement Call.Listener | <200 |
| `TVCallAudioService` | Foreground Service for audio session, notification, audio focus | <150 |
| `TVCallState` | Data class for call state (replaces Connection.State) | <50 |
| `TVAudioManager` | Audio routing (speaker, bluetooth, earpiece) via AudioManager API | <150 |

### Removed Classes

| Class | Reason |
|-------|--------|
| `TVConnectionService` | Replaced by TVCallManager + TVCallAudioService |
| `TVCallConnection` | Connection base class no longer needed; Call.Listener in TVCallManager |
| `TVCallInviteConnection` | Merged into TVCallManager.acceptCall() |
| `TelecomManagerExtension` | Most methods obsolete without ConnectionService |

## Related Code Files

### Files to Create

| File | Purpose |
|------|---------|
| `android/.../service/TVCallManager.kt` | Call state management, Call.Listener impl |
| `android/.../service/TVCallAudioService.kt` | Foreground service for audio |
| `android/.../service/TVCallState.kt` | Call state data class |
| `android/.../service/TVAudioManager.kt` | Audio routing (speaker/bluetooth/earpiece) |

### Files to Modify

| File | Changes |
|------|---------|
| `android/src/main/AndroidManifest.xml` | Remove TVConnectionService, add TVCallAudioService, remove telecom permissions |
| `android/.../fcm/VoiceFirebaseMessagingService.kt` | Remove TVConnectionService dependency; call TVCallManager directly |
| `android/.../TwilioVoicePlugin.kt` | Replace TVConnectionService calls with TVCallManager; remove TelecomManager usage |
| `android/.../receivers/TVBroadcastReceiver.kt` | Simplify or remove; TVCallManager uses direct callbacks |
| `android/.../types/TVMethodChannels.kt` | Keep all methods; phone account ones become no-ops |

### Files to Delete

| File | Reason |
|------|--------|
| `android/.../service/TVConnectionService.kt` (791 lines) | Replaced entirely |
| `android/.../service/TVConnection.kt` (514 lines) | Replaced entirely |
| `android/.../types/TelecomManagerExtension.kt` (237 lines) | Most methods obsolete |

## Implementation Steps

### Step 1: Create TVCallState (data class)
- Simple data class: `callSid`, `from`, `to`, `direction`, `state` (enum: RINGING, CONNECTING, CONNECTED, RECONNECTING, DISCONNECTED), `isMuted`, `isOnHold`, `isSpeakerOn`, `isBluetoothOn`
- File: `android/.../service/TVCallState.kt`

### Step 2: Create TVAudioManager
- Wraps Android `AudioManager` for audio routing
- Methods: `setSpeaker(on)`, `setBluetooth(on)`, `requestAudioFocus()`, `abandonAudioFocus()`
- Use `AudioDeviceInfo` API for device enumeration (API 23+, handles API 34+ deprecation of `CallAudioState`)
- File: `android/.../service/TVAudioManager.kt`

### Step 3: Create TVCallAudioService
- Extends `Service` (NOT ConnectionService)
- `onCreate`: create notification channel
- `onStartCommand`: post foreground notification with `ServiceInfo.FOREGROUND_SERVICE_TYPE_MICROPHONE`
- `onDestroy`: clean up
- Notification: caller name, hangUp action button
- File: `android/.../service/TVCallAudioService.kt`

### Step 4: Create TVCallManager
- Singleton (companion object or app-scoped)
- Properties: `activeCall: Call?`, `activeCallInvite: CallInvite?`, `callState: TVCallState`, `audioManager: TVAudioManager`
- Implements `Call.Listener` (onConnected, onReconnecting, onReconnected, onDisconnected, onConnectFailure, onRinging)
- Methods:
  - `handleCallInvite(callInvite)` -- store invite, notify via callback
  - `handleCancelledCallInvite(cancelledInvite)` -- clear state, notify
  - `acceptCall(context)` -- `callInvite.accept(context, this)`, start TVCallAudioService
  - `rejectCall(context)` -- `callInvite.reject(context)`, notify
  - `makeCall(context, accessToken, params)` -- `Voice.connect(context, connectOptions, this)`
  - `hangUp()` -- `activeCall?.disconnect()`
  - `toggleMute()`, `toggleHold()`, `sendDigits(digits)`
- Callback interface: `TVCallManagerListener` with `onCallStateChanged(state)`, `onCallInviteReceived(invite)`, `onCallInviteCancelled()`
- File: `android/.../service/TVCallManager.kt`

### Step 5: Refactor VoiceFirebaseMessagingService
- Remove all `TVConnectionService` references
- Remove TelecomManager permission checks (READ_PHONE_STATE, READ_PHONE_NUMBERS, hasCallCapableAccount)
- `onCallInvite`: call `TVCallManager.handleCallInvite(callInvite)` + send LocalBroadcast to TVBroadcastReceiver for Dart notification
- `onCancelledCallInvite`: call `TVCallManager.handleCancelledCallInvite(cancelled)` + broadcast
- Keep it simple: FCM -> parse -> TVCallManager

### Step 6: Refactor TwilioVoicePlugin
- Replace all `TVConnectionService` references with `TVCallManager`
- Remove TelecomManager initialization and phone account logic
- `onMethodCall` handlers:
  - `answer` -> `TVCallManager.acceptCall(context)`
  - `hangUp` -> `TVCallManager.hangUp()`
  - `makeCall` / `connect` -> `TVCallManager.makeCall(context, token, params)`
  - `toggleMute` -> `TVCallManager.toggleMute()`
  - `toggleSpeaker` -> `TVCallManager.audioManager.setSpeaker(!current)`
  - `toggleBluetooth` -> `TVCallManager.audioManager.setBluetooth(!current)`
  - `holdCall` -> `TVCallManager.toggleHold()`
  - Phone account methods (`registerPhoneAccount`, `hasRegisteredPhoneAccount`, `isPhoneAccountEnabled`, `openPhoneAccountSettings`) -> return `true` / no-op with log warning
  - Permission methods (`hasManageOwnCallsPermission`, `requestManageOwnCallsPermission`) -> return `true` (no longer needed)
- Implement `TVCallManagerListener` to forward state to Dart EventChannel
- **Split this 1953-line file** into smaller modules (see Phase 03)

### Step 7: Update AndroidManifest.xml
- Remove TVConnectionService service declaration entirely
- Add TVCallAudioService:
  ```xml
  <service
      android:name=".service.TVCallAudioService"
      android:foregroundServiceType="microphone"
      android:exported="false" />
  ```
- Remove permissions: `MANAGE_OWN_CALLS`
- Keep: `FOREGROUND_SERVICE`, `FOREGROUND_SERVICE_MICROPHONE`, `RECORD_AUDIO`, `POST_NOTIFICATIONS`
- Optionally remove: `CALL_PHONE`, `READ_PHONE_STATE`, `READ_PHONE_NUMBERS` (evaluate if still needed for any non-telecom purpose)

### Step 8: Update/Simplify TVBroadcastReceiver
- Remove TVConnectionService-specific actions
- Keep broadcast mechanism for FCM -> Plugin communication (FCM service runs in separate process)
- Simplify action constants to: `ACTION_CALL_INVITE`, `ACTION_CALL_INVITE_CANCELLED`, `ACTION_CALL_STATE_CHANGED`

### Step 9: Delete Obsolete Files
- Delete `TVConnectionService.kt`
- Delete `TVConnection.kt` (both TVCallConnection and TVCallInviteConnection)
- Delete `TelecomManagerExtension.kt` (or strip to utility methods only)

### Step 10: Integration Test
- Build Android debug APK
- Test incoming call -> Flutter UI shows (no system popup)
- Test outgoing call -> stays in app
- Test answer, reject, hangUp, mute, speaker, hold
- Test call state events arrive in Dart
- Test app background -> foreground notification visible

## Todo List

- [x] Create `TVCallState.kt` data class
- [x] Create `TVAudioManager.kt` with AudioDeviceInfo API
- [x] Create `TVCallAudioService.kt` foreground service
- [x] Create `TVCallManager.kt` with Call.Listener
- [x] Refactor `VoiceFirebaseMessagingService.kt` to use TVCallManager
- [x] Refactor `TwilioVoicePlugin.kt` to use TVCallManager
- [x] Update `AndroidManifest.xml`
- [x] Simplify `TVBroadcastReceiver.kt`
- [x] Delete `TVConnectionService.kt`
- [x] Delete `TVConnection.kt`
- [x] Delete `TelecomManagerExtension.kt`
- [x] Compile check: `./gradlew assembleDebug` — BUILD SUCCESSFUL
- [ ] Test incoming call (in-app UI, no system popup)
- [ ] Test outgoing call
- [ ] Test all call controls (mute, hold, speaker, bluetooth, digits)
- [ ] Test foreground notification during active call

## Success Criteria

- Incoming call on Android shows Flutter in-app UI, NOT system call screen
- Outgoing call stays within Flutter app
- All MethodChannel methods work: answer, hangUp, toggleMute, toggleSpeaker, toggleBluetooth, holdCall, sendDigits
- Call state events flow correctly to Dart EventChannel
- Foreground notification visible during call
- No crash on Android 14+ (API 34)
- `MANAGE_OWN_CALLS` and `BIND_TELECOM_CONNECTION_SERVICE` permissions removed

## Risk Assessment

| Risk | Likelihood | Impact | Mitigation |
|------|-----------|--------|------------|
| Twilio SDK requires ConnectionService for some features | Low | High | SDK docs confirm standalone mode works; `callInvite.accept(context, listener)` is the core API |
| Background call handling without ConnectionService | Medium | High | Foreground service keeps process alive; FCM delivers push even when app killed |
| Audio routing issues without system integration | Medium | Medium | TVAudioManager wraps AudioManager directly; tested on multiple devices |
| Breaking existing users who rely on phone account | Medium | Medium | Phone account methods return no-op gracefully; document in CHANGELOG |
| 1953-line TwilioVoicePlugin refactor causes regressions | Medium | High | Test each MethodChannel method individually; keep changes minimal in this phase |

## Security Considerations

- Removing `MANAGE_OWN_CALLS` reduces permission surface (good)
- Removing `BIND_TELECOM_CONNECTION_SERVICE` removes privileged service binding (good)
- FCM token handling unchanged; no new attack surface
- Foreground service notification is user-visible (transparency)

## Next Steps

- Phase 03 depends on this: Kotlin modernization targets the new files created here
- Phase 05 depends on this: Dart cleanup removes obsolete phone account method calls
