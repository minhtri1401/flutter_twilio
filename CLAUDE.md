# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

`twilio_voice` is a Flutter plugin providing cross-platform VoIP calling via Twilio's Programmable Voice SDK. Supports iOS (CallKit + PushKit), Android (ConnectionService + FCM), Web (twilio-voice.js), and macOS (uses Web SDK as a temporary workaround — no native macOS SDK exists).

Current version: `0.3.2+2`

## Commands

```bash
# Install dependencies
fvm flutter pub get

# Analyze/lint
fvm flutter analyze

# Run tests
fvm flutter test

# Run a single test file
fvm flutter test test/twilio_voice_test.dart

# Run example app
cd example && fvm flutter run
```

## Architecture

### Platform Interface Pattern

The plugin follows Flutter's federated plugin pattern with three layers:

1. **Abstract interface** (`lib/_internal/platform_interface/`) — `TwilioVoicePlatform` and `TwilioCallPlatform` define all public methods. Never modify these without updating all implementations.

2. **MethodChannel implementation** (`lib/_internal/method_channel/`) — `MethodChannelTwilioVoice` and `MethodChannelTwilioCall` route calls to native via `MethodChannel('twilio_voice')`. This is the default implementation used by iOS, Android, and macOS native paths.

3. **Web implementation** (`lib/_internal/twilio_voice_web.dart`) — Registered as the web plugin class. Uses JS interop (`lib/_internal/js/`) to wrap twilio-voice.js. Does **not** use MethodChannel.

**Public API entry point:** `lib/twilio_voice.dart` — exports `TwilioVoice`, `Call`, `ActiveCall`, `CallEvent`.

### Native Platforms

| Platform | Native entry point | Key SDK | Notes |
|---|---|---|---|
| Android | `android/.../TwilioVoicePlugin.kt` | Twilio Voice SDK v6.9.0 | Uses `ConnectionService` + FCM, min SDK 26 |
| iOS | `ios/Classes/SwiftTwilioVoicePlugin.swift` | Twilio Voice SDK v6.13.0 | CallKit + PushKit VoIP notifications |
| macOS | `macos/Classes/` | twilio-voice.js (Web SDK) | Temporary; no push notification support |

Android call handling: `TVConnectionService.kt` implements `android.telecom.ConnectionService` for native system call UI. `TVBroadcastReceiver.kt` handles incoming broadcasts. FCM is in `VoiceFirebaseMessagingService.kt`.

iOS/macOS call handling: `SwiftTwilioVoicePlugin.swift` implements `PKPushRegistryDelegate` (PushKit) and `CXProviderDelegate` (CallKit). Audio device management is here.

### Web JS Interop

`lib/_internal/js/` wraps the Twilio JS SDK objects:
- `device/` — `TwilioDevice` wrapper
- `call/` — `TwilioCall` wrapper
- `core/` — shared types and promise handling
- `exceptions/` — error types

`lib/_internal/local_storage_web/` handles browser `localStorage` for persisting web config.

### Models

- `ActiveCall` (`lib/models/active_call.dart`) — current call state; contains phone number formatting logic
- `CallEvent` (`lib/models/call_event.dart`) — enum of 22 call lifecycle events (incoming, ringing, connected, callEnded, hold, mute, answer, etc.)

### Event Streaming

Native → Dart events flow via an `EventChannel`. The native side emits string event names that are mapped to `CallEvent` enum values on the Dart side in the method channel implementation.

## Platform Registration

`pubspec.yaml` declares the plugin class per platform:
- Android: `com.twilio.twilio_voice.TwilioVoicePlugin`
- iOS/macOS: `TwilioVoicePlugin`
- Web: `TwilioVoiceWeb` in `lib/_internal/twilio_voice_web.dart`

## Localization

Android string resources live in `android/src/main/res/values/` and `values-es/`. When adding new user-facing strings on Android, add them to both `strings.xml` files (English + Spanish Latin American).

For iOS/macOS localization, check `*.lproj` directories under the respective platform folder.

## Key Constraints

- **macOS**: Uses Web SDK (JS interop), not a native SDK. No push notification (`.voip`/`.apns`) support. App must remain open to receive calls.
- **Android min SDK**: 26 (Android 8.0).
- **iOS SDK**: Requires PushKit entitlement and a VoIP certificate for push notifications.
- The `js` package dependency is a temporary measure; plan is to migrate to `js_interop` (Dart's newer web interop approach).
