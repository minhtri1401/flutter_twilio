# Phase 05 Dart Cleanup — Code Review

**Date:** 2026-04-03
**Scope:** Dart-layer deprecation annotations for 6 methods in `TwilioVoicePlatform` and `MethodChannelTwilioVoice`, plus suppression comments in `PermissionsBlock`.
**Analyzer:** `fvm flutter analyze` — exit 0, zero issues
**Tests:** `fvm flutter test` — all pass

---

## Overall Assessment

The changes are structurally correct and achieve the stated goal: consumers of the plugin who call any of the 6 deprecated methods will now receive IDE warnings. Annotations are present in both the platform interface and the concrete method channel implementation, which is the correct pattern. No regressions were introduced.

Two findings require attention — one is a factual inaccuracy in deprecation messages, the other is an inconsistency in how `deprecated_member_use_from_same_package` is suppressed inside the method channel.

---

## Findings

### High — Inaccurate deprecation message for MANAGE_OWN_CALLS methods

**Files:**
- `lib/_internal/platform_interface/twilio_voice_platform_interface.dart` lines 117, 123
- `lib/_internal/method_channel/twilio_voice_method_channel.dart` lines 191, 203

**Message used:**
```
'MANAGE_OWN_CALLS permission is no longer required. Returns true as no-op.'
```

**Problem:** The "Returns true as no-op" part is not accurate. The method channel implementation still forwards to native on Android. The Android handler (`TVPermissionMethodHandler.kt`) genuinely checks and requests `Manifest.permission.MANAGE_OWN_CALLS` on API <= 33 (Android 13 and below); it only short-circuits to `true` above API 33. A consumer who reads this deprecation message will incorrectly assume the method is completely inert, which may cause them to skip permission prompts they still need on older Android OS versions.

**Recommended fix:** Revise the message to accurately describe the behavior:
```dart
@Deprecated('MANAGE_OWN_CALLS permission check is handled internally. This method will be removed in a future release.')
```
Or, if the intent is to make it a true no-op, the method channel body should also return `Future.value(true)` unconditionally for Android, matching the phone-account methods.

---

### Medium — Missing `deprecated_member_use_from_same_package` suppression for MANAGE_OWN_CALLS in method channel

**File:** `lib/_internal/method_channel/twilio_voice_method_channel.dart` lines 193–210

**Problem:** The four phone-account methods (`hasRegisteredPhoneAccount`, `registerPhoneAccount`, `isPhoneAccountEnabled`, `openPhoneAccountSettings`) each have `// ignore: deprecated_member_use_from_same_package` above their `_channel.invokeMethod(...)` call because the method channel name string matches the deprecated symbol name. The MANAGE_OWN_CALLS pair (`hasManageOwnCallsPermission` at line 197, `requestManageOwnCallsPermission` at line 209) does not have the same suppression, yet the method body also calls `_channel.invokeMethod(...)`. The analyzer passes at exit 0 because the ignore is not needed here (the `_channel.invokeMethod` string argument does not reference a Dart deprecated symbol), but this is an inconsistency in commenting style that may confuse future maintainers.

No code change is strictly required; this is a clarity issue.

---

### Low — Example app still shows phone-account UI when underlying behaviour is a no-op

**File:** `example/lib/screens/widgets/permissions_block.dart`

The example app retains the full phone-account permission tiles and the MANAGE_OWN_CALLS tile with working interaction paths. Now that these methods always return `true`, those tiles will always show as "granted" on Android, which is mildly misleading but acceptable as a demo app. No action required unless the example is used as documentation for end users.

---

## Positive Observations

- The `@Deprecated` annotation text is clear and action-oriented for the four phone-account methods.
- The `// ignore: deprecated_member_use_from_same_package` comments inside `MethodChannelTwilioVoice` use the correct lint identifier (not `deprecated_member_use`) since the call site is inside the same package that declared the deprecation.
- The example app uses the correct `// ignore: deprecated_member_use` identifier (without `_from_same_package`) since it is a consumer of the package, not the package itself. All 8 suppression sites are correctly placed on the line immediately before the deprecated call.
- No other Dart files in `lib/` reference any of the 6 deprecated methods. `twilio_voice_web.dart` does not override these methods, which is consistent with the Web SDK not supporting Android-specific permissions.
- The `twilio_voice.dart` public API re-exports `TwilioVoicePlatform`, so the deprecation is visible to all downstream consumers via the public surface.

---

## Summary of Required Actions

| Priority | Action |
|----------|--------|
| High | Correct the deprecation message for `hasManageOwnCallsPermission` and `requestManageOwnCallsPermission` — either change the message to remove "no-op" language, or make the Dart implementation return `Future.value(true)` unconditionally on Android to match the stated message. |
| Low (optional) | Consider removing or greying out the phone-account and manage-calls tiles in the example app to reflect that these permissions are no longer required, avoiding confusion for plugin evaluators. |
