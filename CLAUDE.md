# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

`twilio_voice` is a Flutter plugin providing cross-platform VoIP calling via Twilio's Programmable Voice SDK. Supports iOS (CallKit + PushKit), Android (custom in-app calling + FCM), Web (twilio-voice.js), and macOS (uses Web SDK via a WKWebView bridge — no native macOS SDK exists).

Current version: `0.3.2+2`. CI pins Flutter `3.27.4` (stable).

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

2. **MethodChannel implementation** (`lib/_internal/method_channel/`) — `MethodChannelTwilioVoice` and `MethodChannelTwilioCall` route calls to native via `MethodChannel('twilio_voice')`. Default implementation used by iOS, Android, and macOS native paths.

3. **Web implementation** (`lib/_internal/twilio_voice_web.dart`) — Registered as the web plugin class. Uses JS interop (`lib/_internal/js/`) to wrap twilio-voice.js. Does **not** use MethodChannel.

**Public API entry point:** `lib/twilio_voice.dart` — exports `TwilioVoice`, `Call`, `ActiveCall`, `CallEvent`.

### Native Platforms

| Platform | Entry point | Key SDK | Notes |
|---|---|---|---|
| Android | `android/.../TwilioVoicePlugin.kt` | Twilio Voice SDK v6.9.0 | Custom in-app calling + FCM, min SDK 26 |
| iOS | `ios/Classes/SwiftTwilioVoicePlugin.swift` | Twilio Voice SDK v6.13.0 | CallKit + PushKit VoIP notifications |
| macOS | `macos/Classes/TwilioVoicePlugin.swift` | twilio-voice.js (Web SDK) | WKWebView bridge; no push support |

**Android** (`android/src/main/kotlin/com/twilio/twilio_voice/`): `TwilioVoicePlugin.kt` wires up method channels and delegates to per-domain handlers under `handler/` (`TVCallMethodHandler`, `TVAudioMethodHandler`, `TVConfigMethodHandler`, `TVPermissionMethodHandler`, `TVRegistrationMethodHandler`). Call state/audio routing live in `service/` (`TVCallManager`, `TVCallState`, `TVCallAudioService` foreground service, `TVAudioManager`). FCM in `fcm/VoiceFirebaseMessagingService.kt`. **Important:** calls now run inside the Flutter app — the previous `ConnectionService` / `TelecomManager` integration was removed (see `MIGRATION.md`); the system dialer no longer appears, and `MANAGE_OWN_CALLS` / phone account setup are no longer required.

**iOS** (`ios/Classes/`): `SwiftTwilioVoicePlugin.swift` is the main `FlutterPlugin` / `PKPushRegistryDelegate` / `CXProviderDelegate` class. Concern-specific helpers sit alongside it: `TVAudioHandler.swift` (AVAudioSession), `TVCallHandler.swift` (call lifecycle), `TVCallKitActions.swift` / `TVCallKitDelegate.swift` (CallKit glue), `TVNotificationDelegate.swift`, `TVPermissionHandler.swift`, `TVRegistrationHandler.swift`.

**macOS** (`macos/Classes/`): `TwilioVoicePlugin.swift` hosts a `TVWebview` (WKWebView) that loads `macos/Resources/index.html` + `twilio.min.js`. The Dart MethodChannel API is bridged into JS through `JsInterop/` and `TwilioVoiceChannelMethods.swift`. Because it's JS-on-Web under the hood, push notifications are unavailable — the app must stay open.

### Web JS Interop

`lib/_internal/js/` wraps the Twilio JS SDK objects:
- `device/` — `TwilioDevice` wrapper
- `call/` — `TwilioCall` wrapper
- `core/` — shared types and promise handling
- `exceptions/` — error types

`lib/_internal/local_storage_web/` handles browser `localStorage` for persisting web config.

The web implementation depends on a **custom patched `twilio.min.js`** (ships in `example/web/` and `macos/Resources/`) — it adds status outputs Flutter uses to track the Twilio `Device`. Don't replace it with the stock CDN build. It also layers `web_callkit` + `js_notifications` on top; the service worker `js_notifications-sw.js` must be present in the consumer app's `web/` directory (see `NOTES.md`).

### Models

- `ActiveCall` (`lib/models/active_call.dart`) — current call state; contains phone number formatting logic
- `CallEvent` (`lib/models/call_event.dart`) — enum of 22 call lifecycle events (incoming, ringing, connected, callEnded, hold, mute, answer, etc.)

### Event Streaming

Native → Dart events flow via an `EventChannel`. The native side emits string event names that are mapped to `CallEvent` enum values on the Dart side in the method channel implementation. On Android, `TVEventEmitter.kt` is the central emitter; on iOS, `SwiftTwilioVoicePlugin.swift` implements `FlutterStreamHandler` directly.

## Platform Registration

`pubspec.yaml` declares the plugin class per platform:
- Android: `com.twilio.twilio_voice.TwilioVoicePlugin`
- iOS/macOS: `TwilioVoicePlugin`
- Web: `TwilioVoiceWeb` in `lib/_internal/twilio_voice_web.dart`

## Localization

Android string resources live in `android/src/main/res/values/` and `values-es/`. When adding new user-facing strings on Android, add them to both `strings.xml` files (English + Spanish Latin American).

For iOS/macOS localization, check `*.lproj` directories under the respective platform folder (example app has `ios/Runner/en.lproj/Localizable.strings`).

## Key Constraints

- **macOS**: Uses Web SDK via WKWebView, not a native SDK. No push notification (`.voip`/`.apns`) support. App must remain open to receive calls.
- **Android min SDK**: 26 (Android 8.0); `compileSdkVersion` 34.
- **iOS**: Requires PushKit entitlement and a VoIP certificate for push notifications.
- The `js: ^0.7.1` dependency is temporary; plan is to migrate to `package:web` + `dart:js_interop` (Dart's newer web interop approach).
- Android breaking change: migrating apps off the old `ConnectionService` flow — see `MIGRATION.md` before touching Android call routing, permissions, or phone-account code.
