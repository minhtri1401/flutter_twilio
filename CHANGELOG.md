# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.1.0] — 2026-04-17

Initial release of `flutter_twilio`, a ground-up refactor of the original
[`twilio_voice`](https://pub.dev/packages/twilio_voice) plugin. Not API-compatible.

### Added

- **Unified facade.** `FlutterTwilio.instance` exposes both voice and SMS.
  `init(accountSid:, authToken:, twilioNumber:)` shares credentials across
  both subsystems; credentials live in-memory only.
- **Typed voice API.** `FlutterTwilio.instance.voice` is a `VoiceApi` with
  `setAccessToken`, `register`, `unregister`, `place`, `answer`, `reject`,
  `hangUp`, `setMuted`, `setOnHold`, `setSpeaker`, `sendDigits`,
  `getActiveCall`, `hasMicPermission`, `requestMicPermission`, and an
  `events` stream of `Call { event, active }` snapshots.
- **Pure-Dart SMS client.** `FlutterTwilio.instance.sms` wraps the Twilio
  REST messaging API with `send`, `list`, and `get`. Returns `Message`
  values; uses `package:http`.
- **Pigeon-typed native bridge.** All MethodChannel / EventChannel plumbing
  replaced with the generated `VoiceHostApi` + `VoiceFlutterApi`.
  Schema lives in `pigeons/voice_api.dart`; outputs are checked in for
  Dart, Kotlin, and Swift.
- **Structured error taxonomy.** Native failures are translated via
  `FlutterTwilioError.of/.fromTwilio/.unknown` into a stable set of codes
  (`not_initialized`, `missing_permission`, `invalid_token`,
  `no_active_call`, `call_already_active`, `twilio_sdk_error`,
  `audio_session_error`, `registration_error`, `connection_error`,
  `unknown`). Dart surfaces them as `VoiceException` subtypes
  (`VoiceNotInitializedException`, `VoicePermissionDeniedException`,
  `VoiceInvalidTokenException`, `VoiceNoActiveCallException`,
  `VoiceCallAlreadyActiveException`, `TwilioSdkException`). SMS errors
  surface as `TwilioSmsException` carrying `statusCode`, `twilioCode`, and
  `moreInfo`.
- **Example app** exercising init, voice lifecycle, and SMS send through
  a single screen.
- **CI** (`.github/workflows/flutter-build-test.yml`) pinned to Flutter
  `3.41.0`, with a Pigeon-diff guard that fails builds if the generated
  files drift from the schema.

### Changed

- **Package rename.** `twilio_voice` → `flutter_twilio`.
- **Android package rename.** `com.twilio.twilio_voice` → `com.dev.flutter_twilio`.
- **iOS plugin class rename.** `SwiftTwilioVoicePlugin` / `TwilioVoicePlugin`
  → `FlutterTwilioPlugin`. `podspec` renamed.
- **Minimum versions.** Android `minSdk` 26 (unchanged), iOS deployment
  target raised to 13.0.

### Removed

- **Web and macOS platform support.** The JS interop layer, WKWebView
  bridge, and all associated build artefacts are gone. Use
  `twilio_voice <= 0.3.2+2` for those targets.
- **Android `ConnectionService` integration** (already removed pre-rename;
  documented here for completeness). Calls run in-app — no system dialer,
  no `MANAGE_OWN_CALLS`, no `BIND_TELECOM_CONNECTION_SERVICE`, no phone
  account registration.
- **Legacy methods.** `registerClient`/`unregisterClient`/`defaultCaller`,
  `hasRegisteredPhoneAccount`/`registerPhoneAccount`/
  `openPhoneAccountSettings`/`isPhoneAccountEnabled`,
  `toggleBluetooth`/`isBluetoothOn`/`hasBluetoothPermission`,
  `showNotifications`/`updateCallKitIcon`/`enableCallLogging`,
  `backgroundCallUi`/`requiresBackgroundPermissions`/
  `requestBackgroundPermissions`, `rejectCallOnNoPermissions`, and
  direct getters like `isOnCall`/`callSid`. Their concerns are either
  no longer applicable in the in-app calling model or out of scope for
  v0.1. See `MIGRATION.md` for details.

### Migration

See [`MIGRATION.md`](MIGRATION.md) for the full upgrade guide from
`twilio_voice`.

[0.1.0]: https://github.com/minhtri1401/flutter_twilio/releases/tag/v0.1.0
