# Scout Report: Twilio Voice SDK Upgrade & Android In-App Calling

**Date:** 2026-04-03 | **Status:** Codebase Analysis Complete

## 1. Current Dependency Versions

| Component | Version | File |
|-----------|---------|------|
| **Twilio Voice SDK (Android)** | 6.9.0 | `android/build.gradle:8` |
| **Twilio Voice SDK (iOS)** | ~> 6.13.1 | `ios/twilio_voice.podspec:18` |
| **Kotlin** | 1.9.10 | `android/build.gradle:6` |
| **AGP (Android Gradle Plugin)** | 8.5.2 | `android/build.gradle:7` |
| **Compile SDK** | 35 | `android/build.gradle:34` |
| **Min SDK (Android)** | 26 | `android/build.gradle:49` |
| **Firebase Messaging** | 24.1.0 | `android/build.gradle:64` |
| **Firebase BOM** | 33.10.0 | `android/build.gradle:62` |

## 2. Android ConnectionService Wiring

**Registration:** `android/src/main/AndroidManifest.xml`
- Service: `.service.TVConnectionService` extends `ConnectionService`
- Intent filter: `android.telecom.ConnectionService`
- Required permissions: `BIND_TELECOM_CONNECTION_SERVICE`, `FOREGROUND_SERVICE_MICROPHONE`

**Core Classes:**
- **TVConnectionService** (`service/TVConnectionService.kt`): Singleton managing `activeConnections: HashMap<String, TVCallConnection>`. Handles ACTION_CALL_INVITE, ACTION_PLACE_OUTGOING_CALL, ACTION_HANGUP via `onStartCommand()`. Triggers system UI via `TelecomManager.addNewIncomingCall()` at line 309.
- **TVCallConnection** (`service/TVConnection.kt`): Extends `Connection`, implements `Call.Listener`. Two subclasses: TVCallInviteConnection (incoming) and TVCallConnection (outgoing).
- **TVBroadcastReceiver** (`receivers/TVBroadcastReceiver.kt`): Receives local broadcasts for call state changes.

**Flow:** VoiceFirebaseMessagingService → Intent ACTION_CALL_INVITE → TVConnectionService.onStartCommand() → TelecomManager.addNewIncomingCall() → System Call UI → onCreateIncomingConnection()

## 3. Key Methods for In-App Calling Changes

| Method | Location | Purpose | Critical |
|--------|----------|---------|---------|
| onCreateIncomingConnection() | TVConnectionService:483 | Route to system/in-app UI | YES |
| onCreateOutgoingConnection() | TVConnectionService | Create outgoing connection | YES |
| ACTION_PLACE_OUTGOING_CALL | TVConnectionService:341 | Outgoing call initiation | YES |
| callInvite.accept() | TVCallInviteConnection:50 | Answer incoming calls | YES |
| CallInvite.reject() | TVConnection:70 | Reject calls | YES |
| onAnswer() | TVConnection:334 | SystemUI callback | CHANGE |
| onDisconnect() | TVConnection:269 | SystemUI callback | CHANGE |

## 4. MethodChannel Method Names (Complete List)

**51 Total Methods** defined in `types/TVMethodChannels.kt`:
- Core: tokens, unregister, makeCall, connect, answer, hangUp, sendDigits
- State: isOnCall, call-sid, holdCall, isHolding, toggleMute, isMuted, toggleSpeaker, isOnSpeaker, toggleBluetooth, isBluetoothOn
- Account (Android): registerPhoneAccount, isPhoneAccountEnabled, openPhoneAccountSettings, hasRegisteredPhoneAccount
- Permissions: hasMicPermission, requestMicPermission, hasReadPhoneStatePermission, requestReadPhoneStatePermission, hasCallPhonePermission, requestCallPhonePermission, hasManageOwnCallsPermission, requestManageOwnCallsPermission, hasReadPhoneNumbersPermission, requestReadPhoneNumbersPermission
- Management: registerClient, unregisterClient, defaultCaller
- Config: updateCallKitIcon, showNotifications, enableCallLogging
- Deprecated: requiresBackgroundPermissions, requestBackgroundPermissions, backgroundCallUi, rejectCallOnNoPermissions, isRejectingCallOnNoPermissions

## 5. TODO/FIXME/HACK Comments

**High Priority:**
- TVConnection.kt:1-2 — Twilio parameter interpretation & contact creation
- TVConnection.kt:246 — Conditional disconnect handling (remote vs local)
- TVConnection.kt:424,465 — API 34+ mute/endpoint listeners (CallAudioState deprecated)

**Medium Priority:**
- TwilioVoicePlugin.kt:184,202 — Outgoing call direction detection
- TwilioVoicePlugin.kt:381 — Phone account permission rationale flow
- SwiftTwilioVoicePlugin.swift:205 — Bluetooth toggle stub (not implemented)

**Low Priority:**
- StorageImpl.kt:78,87 — Remove unnecessary asserts

## 6. Critical Integration Points

- **System UI Coupling:** TelecomManager.addNewIncomingCall() must be bypassed for in-app UI
- **Incoming Call Event:** Currently routed through system; needs direct EventChannel for in-app mode
- **Answer/Reject:** Currently use ConnectionService callbacks; need Dart method routing
- **Call State:** LocalBroadcasts used; consider EventChannel-only approach for in-app

## 7. Android Intent Constants

All defined in TVConnectionService companion object:
ACTION_CALL_INVITE, ACTION_CANCEL_CALL_INVITE, ACTION_PLACE_OUTGOING_CALL, ACTION_INCOMING_CALL, ACTION_ANSWER, ACTION_HANGUP, ACTION_SEND_DIGITS, ACTION_TOGGLE_SPEAKER, ACTION_TOGGLE_BLUETOOTH, ACTION_TOGGLE_HOLD, ACTION_TOGGLE_MUTE, ACTION_ACTIVE_HANDLE, plus 14 EXTRA_* constants

## 8. iOS Architecture Summary

SwiftTwilioVoicePlugin.swift: Uses CallKit (CXProvider, CXCallController) with in-app UI already implemented. PKPushRegistry for VoIP. No system call UI trigger needed. In-app calling works correctly on iOS.

## 9. Dart Layer

`lib/_internal/platform_interface/twilio_voice_platform_interface.dart` — abstract contract
`lib/_internal/method_channel/twilio_voice_method_channel.dart` — MethodChannel bridge
`lib/models/call_event.dart` — 22 CallEvent enum values
`lib/models/active_call.dart` — call state model

**Unresolved Questions:**
- Should in-app calling be a runtime flag (opt-in) or replace ConnectionService entirely?
- What happens to existing users who rely on system call UI for background calls?
