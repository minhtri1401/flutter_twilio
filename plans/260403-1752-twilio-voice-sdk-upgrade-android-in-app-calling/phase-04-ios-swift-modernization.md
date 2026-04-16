# Phase 04: iOS Swift Modernization

## Context Links

- [Plan Overview](plan.md)
- [SDK Versions Research](research/researcher-01-sdk-versions-report.md)
- [Scout Report](scout/scout-01-codebase-report.md)

## Overview

- **Priority:** P2
- **Status:** complete
- **Effort:** 45m
- **Description:** Modernize Swift code, implement missing Bluetooth toggle, fix deprecation warnings from iOS SDK upgrade. Independent of Android phases.

## Key Insights

- `SwiftTwilioVoicePlugin.swift` is 1168 lines -- exceeds 200-line rule significantly
- Bluetooth toggle at line ~205 is a stub (not implemented)
- iOS in-app calling already works via CallKit -- no architectural changes needed
- If Twilio iOS SDK upgrades to v7.x with async/await APIs, delegate callbacks need migration
- Swift async/await available since Swift 5.5 / iOS 13; current deployment target is 11.0

## Requirements

### Functional
- Bluetooth audio toggle works (currently stub)
- All existing iOS functionality preserved
- No behavioral changes to MethodChannel API

### Non-Functional
- No Swift file exceeds 200 lines
- Async/await where Twilio SDK supports it (conditional on SDK version)
- Minimum iOS deployment target raised to 13.0 (if SDK requires it)

## Architecture

### SwiftTwilioVoicePlugin.swift Split Plan (1168 lines -> ~6 modules)

| New File | Responsibility |
|----------|---------------|
| `SwiftTwilioVoicePlugin.swift` | FlutterPlugin lifecycle, method routing (~150 lines) |
| `TVCallHandler.swift` | Call operations: makeCall, answer, hangUp, hold, sendDigits |
| `TVAudioHandler.swift` | Audio: mute, speaker, bluetooth toggle |
| `TVRegistrationHandler.swift` | Token registration, client register/unregister |
| `TVPermissionHandler.swift` | Permission checks (mic, etc.) |
| `TVCallKitDelegate.swift` | CXProviderDelegate, CXCallController management |

### Bluetooth Toggle Implementation
- Use `AVAudioSession.availableInputs` to find Bluetooth HFP port
- Set preferred input to Bluetooth port or reset to default
- Query current route via `AVAudioSession.currentRoute.inputs`

## Related Code Files

### Files to Create

| File | Purpose |
|------|---------|
| `ios/Classes/TVCallHandler.swift` | Call operation handlers |
| `ios/Classes/TVAudioHandler.swift` | Audio control handlers |
| `ios/Classes/TVRegistrationHandler.swift` | Registration handlers |
| `ios/Classes/TVPermissionHandler.swift` | Permission handlers |
| `ios/Classes/TVCallKitDelegate.swift` | CallKit delegate extraction |

### Files to Modify

| File | Changes |
|------|---------|
| `ios/Classes/SwiftTwilioVoicePlugin.swift` | Split into modules; reduce to ~150 lines |
| `ios/twilio_voice.podspec` | SDK version (Phase 01), possibly deployment target |

## Implementation Steps

1. **Implement Bluetooth toggle** (in current file first, then extract):
   - Find Bluetooth HFP input in `AVAudioSession.sharedInstance().availableInputs`
   - Toggle: if current input is Bluetooth, set to built-in; else set to Bluetooth
   - Return new state via MethodChannel result

2. **Extract TVCallKitDelegate.swift:**
   - Move `CXProviderDelegate` methods
   - Move `CXCallController` call management
   - Pass reference to plugin for event emission

3. **Extract TVCallHandler.swift:**
   - `makeCall`, `answer`, `hangUp`, `holdCall`, `sendDigits`
   - Receives Twilio `Call` reference from plugin state

4. **Extract TVAudioHandler.swift:**
   - `toggleMute`, `toggleSpeaker`, `toggleBluetooth` (newly implemented)
   - `isMuted`, `isOnSpeaker`, `isBluetoothOn` queries

5. **Extract TVRegistrationHandler.swift:**
   - Token-based registration/unregistration
   - Client register/unregister

6. **Extract TVPermissionHandler.swift:**
   - Microphone permission check/request
   - Other permission queries

7. **Refactor SwiftTwilioVoicePlugin.swift:**
   - Keep FlutterPlugin protocol methods
   - `handle(_ call:result:)` becomes a router delegating to handlers
   - Target: <150 lines

8. **If Twilio iOS SDK v7.x uses async/await:**
   - Migrate delegate callbacks to async patterns
   - Use `Task { }` for bridging synchronous FlutterMethodCall to async SDK
   - Raise deployment target to iOS 13.0

9. **Compile and test:**
   - `fvm flutter build ios --no-codesign` succeeds
   - Test Bluetooth toggle on physical device

## Todo List

- [x] Implement Bluetooth audio toggle
- [x] Extract `TVCallKitDelegate.swift`
- [x] Extract `TVCallHandler.swift`
- [x] Extract `TVAudioHandler.swift`
- [x] Extract `TVRegistrationHandler.swift`
- [x] Extract `TVPermissionHandler.swift`
- [x] Refactor `SwiftTwilioVoicePlugin.swift` to router (<150 lines)
- [x] iOS build compiles successfully
- [ ] Test Bluetooth toggle on device

## Success Criteria

- No Swift file exceeds 200 lines
- Bluetooth toggle method works (returns correct boolean state)
- iOS build compiles with zero errors
- All existing MethodChannel methods work on iOS
- No deprecation warnings

## Risk Assessment

| Risk | Likelihood | Impact | Mitigation |
|------|-----------|--------|------------|
| CallKit delegate extraction breaks callback flow | Medium | High | Test incoming/outgoing calls after extraction |
| Bluetooth toggle fails on some devices | Low | Medium | Fallback: return false if no Bluetooth HFP available |
| iOS 13.0 minimum excludes old devices | Low | Low | iOS 13 covers 97%+ of devices; acceptable |
| Async/await migration introduces concurrency bugs | Low | Medium | Keep synchronous fallback for FlutterMethodCall bridge |

## Security Considerations

- No new permissions required
- CallKit delegate handles sensitive call data; ensure no logging of caller info in release builds

## Next Steps

- Independent of Android phases; can be done in parallel
- Phase 05 (Dart cleanup) runs after this
