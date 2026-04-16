# Phase 05: Dart Cleanup

## Context Links

- [Plan Overview](plan.md)
- [Scout Report](scout/scout-01-codebase-report.md)

## Overview

- **Priority:** P2
- **Status:** complete
- **Effort:** 30m
- **Description:** Update Dart layer to reflect Android ConnectionService removal. Phone account methods become no-ops. Ensure all 51 MethodChannel methods still have implementations on Android and iOS.
- **Scope:** Android and iOS only. Do not modify web/macOS platform files (`twilio_voice_web.dart`, JS interop layer).

## Key Insights

- Phone account methods were Android-only (iOS never used them): `registerPhoneAccount`, `hasRegisteredPhoneAccount`, `isPhoneAccountEnabled`, `openPhoneAccountSettings`
- Permission methods `hasManageOwnCallsPermission` and `requestManageOwnCallsPermission` are now unnecessary
- Dart platform interface defines the contract; implementations must match
- The `connect` method is a newer alias for `makeCall`; both must route correctly
- Deprecated methods in TVMethodChannels.kt (`backgroundCallUi`, `requiresBackgroundPermissions`, `requestBackgroundPermissions`) already have `@Deprecated` annotations

## Requirements

### Functional
- Phone account methods return graceful defaults (true/no-op) instead of errors
- Deprecated methods marked with `@Deprecated` annotation in Dart
- All 51 MethodChannel methods have corresponding native implementations on both platforms

### Non-Functional
- Backward compatibility: apps using phone account methods don't crash
- Clean deprecation warnings for removed features
- All user-facing strings translated to Latin American Spanish

## Architecture

No architectural changes. API contract preserved with deprecation annotations.

## Related Code Files

### Files to Modify

| File | Changes |
|------|---------|
| `lib/_internal/platform_interface/twilio_voice_platform_interface.dart` | Add `@Deprecated` to phone account methods |
| `lib/_internal/method_channel/twilio_voice_method_channel.dart` | Phone account methods return hardcoded defaults |
| `lib/_internal/method_channel/twilio_call_method_channel.dart` | Review for completeness (Android + iOS only) |
| `lib/_internal/method_channel/shared_platform_method_channel.dart` | Review for completeness (Android + iOS only) |
| `pubspec.yaml` | Version bump (already in Phase 01) |

### Files to Review (no changes expected)

| File | Purpose |
|------|---------|
| `lib/models/call_event.dart` | 22 CallEvent enum values; verify all still used |
| `lib/models/active_call.dart` | Call state model; no changes needed |
| `lib/twilio_voice.dart` | Public API; verify exports |

## Implementation Steps

1. **Mark phone account methods as deprecated in platform interface:**
   ```dart
   @Deprecated('Phone account registration is no longer required. Returns true as no-op.')
   Future<bool?> registerPhoneAccount();
   ```
   Apply to: `registerPhoneAccount`, `hasRegisteredPhoneAccount`, `isPhoneAccountEnabled`, `openPhoneAccountSettings`

2. **Mark permission methods as deprecated:**
   ```dart
   @Deprecated('MANAGE_OWN_CALLS permission is no longer required. Returns true as no-op.')
   Future<bool?> hasManageOwnCallsPermission();
   ```

3. **Update method channel implementations** to return defaults without native call (optional -- can also let native side return the default):
   - `registerPhoneAccount()` -> return `true`
   - `hasRegisteredPhoneAccount()` -> return `true`
   - `isPhoneAccountEnabled()` -> return `true`
   - `openPhoneAccountSettings()` -> no-op, return `null`
   - `hasManageOwnCallsPermission()` -> return `true`
   - `requestManageOwnCallsPermission()` -> return `true`
   - Decision: better to keep the MethodChannel call and have native return defaults, so behavior is consistent and future-proof

4. **Verify all 51 MethodChannel method names** match between:
   - `TVMethodChannels.kt` (Android)
   - `SwiftTwilioVoicePlugin.swift` (iOS)
   - `twilio_voice_method_channel.dart` (Dart)
   - Create a checklist comparing all three

5. **Localization check:**
   - Scan for any new user-facing strings added during this upgrade
   - Ensure Spanish (Latin American) translations exist
   - Focus on: notification text in TVCallAudioService, deprecation messages (these are developer-facing, not user-facing -- skip)

6. **Run analysis:**
   - `fvm flutter pub get`
   - `fvm flutter analyze`
   - Fix any warnings

## Todo List

- [x] Add `@Deprecated` annotations to phone account methods in platform interface
- [x] Add `@Deprecated` annotations to manage-own-calls permission methods
- [x] Verify native side returns defaults for deprecated methods
- [x] Cross-check all 43 MethodChannel method names across platforms
- [x] Verify CallEvent enum completeness
- [x] Check for user-facing strings needing Spanish translation (none new)
- [x] Run `fvm flutter analyze` -- zero errors
- [x] Run `fvm flutter pub get` -- resolves cleanly

## Success Criteria

- `fvm flutter analyze` passes with zero errors
- Deprecated methods produce Dart deprecation warnings when used
- Deprecated methods still work (return defaults, no crash)
- All 51 MethodChannel methods accounted for across all platforms
- No orphaned method names

## Risk Assessment

| Risk | Likelihood | Impact | Mitigation |
|------|-----------|--------|------------|
| Breaking change for apps relying on phone account flow | Medium | Medium | Deprecation + graceful defaults; document in CHANGELOG |
| Missing MethodChannel method causes runtime NoSuchMethodError | Low | High | Systematic cross-check of all 51 methods |
| Stale CallEvent values after refactor | Low | Low | Review enum against new TVCallManager states |

## Security Considerations

- No new security surface
- Removing MANAGE_OWN_CALLS requirement reduces attack surface for consuming apps

## Next Steps

- After this phase: all work is complete
- Update CHANGELOG.md with breaking changes and deprecations
- Bump plugin version in pubspec.yaml
- Consider writing migration guide for users upgrading
