# Phase 03: Android Kotlin Modernization

## Context Links

- [Plan Overview](plan.md)
- [SDK Versions Research](research/researcher-01-sdk-versions-report.md)
- [Scout Report](scout/scout-01-codebase-report.md)

## Overview

- **Priority:** P2
- **Status:** complete
- **Effort:** 1h
- **Description:** Modernize Kotlin code to 2.3.x standards, fix K2 compiler warnings, split oversized files, address existing TODOs.

## Key Insights

- `TwilioVoicePlugin.kt` is 1953 lines -- must be split into <200-line modules
- K2 compiler in Kotlin 2.3.20 may flag previously-allowed patterns
- Existing TODOs in TVConnection.kt will be resolved by Phase 02 deletion; remaining TODOs in TwilioVoicePlugin.kt need attention
- `LocalBroadcastManager` is deprecated; consider direct callback pattern or standard Android `BroadcastReceiver`
- Coroutines useful for async operations (token registration, call setup) but not mandatory everywhere

## Requirements

### Functional
- All existing functionality preserved after refactor
- K2 compiler produces zero errors
- No behavioral changes to MethodChannel API

### Non-Functional
- No file exceeds 200 lines
- Modern Kotlin idioms: data classes, sealed classes for state, `when` expressions, null safety
- Coroutines where they simplify async code (token registration)

## Architecture

### TwilioVoicePlugin.kt Split Plan (1953 lines -> ~10 modules)

| New File | Responsibility | Extracted From |
|----------|---------------|----------------|
| `TwilioVoicePlugin.kt` | FlutterPlugin + ActivityAware lifecycle, onAttach/onDetach | Lines 1-100, plugin registration |
| `handler/TVCallMethodHandler.kt` | MethodChannel handlers for call operations (answer, hangUp, makeCall, etc.) | MethodCall dispatch |
| `handler/TVAudioMethodHandler.kt` | MethodChannel handlers for audio (mute, speaker, bluetooth, hold) | MethodCall dispatch |
| `handler/TVPermissionMethodHandler.kt` | Permission check/request handlers | Permission methods |
| `handler/TVRegistrationMethodHandler.kt` | Token registration, client register/unregister | Token methods |
| `handler/TVConfigMethodHandler.kt` | Config methods (showNotifications, callKitIcon, defaultCaller) | Config methods |
| `TVEventEmitter.kt` | EventChannel setup and event emission to Dart | EventSink management |
| `TVPluginState.kt` | Shared plugin state (context, activity, storage refs) | Scattered state fields |

### Other Refactoring

| Current | Change |
|---------|--------|
| `StorageImpl.kt` TODOs (remove asserts at :78, :87) | Remove unnecessary asserts |
| `CallAudioStateExtension.kt` | Review for API 34+ deprecation; may consolidate into TVAudioManager |
| `CompletionHandler.kt` | Keep; simple typealias |

## Related Code Files

### Files to Create

| File | Purpose |
|------|---------|
| `android/.../handler/TVCallMethodHandler.kt` | Call-related MethodChannel dispatch |
| `android/.../handler/TVAudioMethodHandler.kt` | Audio-related MethodChannel dispatch |
| `android/.../handler/TVPermissionMethodHandler.kt` | Permission MethodChannel dispatch |
| `android/.../handler/TVRegistrationMethodHandler.kt` | Registration MethodChannel dispatch |
| `android/.../handler/TVConfigMethodHandler.kt` | Config MethodChannel dispatch |
| `android/.../TVEventEmitter.kt` | Dart EventChannel wrapper |
| `android/.../TVPluginState.kt` | Shared state container |

### Files to Modify

| File | Changes |
|------|---------|
| `android/.../TwilioVoicePlugin.kt` | Gut to ~150 lines; delegate to handler classes |
| `android/.../storage/StorageImpl.kt` | Remove unnecessary asserts at :78, :87 |
| `android/.../types/CallAudioStateExtension.kt` | Deprecation review |
| `android/.../receivers/TVBroadcastReceiver.kt` | Simplify after Phase 02 changes |

## Implementation Steps

1. **Create TVPluginState** -- data class holding `context`, `activity`, `storage`, `callManager`, `audioManager` references. Passed to all handlers.

2. **Create TVEventEmitter** -- wraps `EventChannel.EventSink`, provides typed methods: `emitCallState(event, data)`, `emitIncomingCall(from, to, sid)`. Thread-safe (post to main looper).

3. **Create handler classes** -- each implements `MethodChannel.MethodCallHandler` or has a `handle(call, result)` method:
   - Extract method handlers from `TwilioVoicePlugin.onMethodCall()` grouped by domain
   - Each handler receives `TVPluginState` and `TVEventEmitter`

4. **Refactor TwilioVoicePlugin.kt** -- reduce to lifecycle management:
   - `onAttachedToEngine` / `onDetachedFromEngine`
   - `onAttachedToActivity` / `onDetachedFromActivity`
   - `onMethodCall` becomes a router that delegates to appropriate handler
   - Target: <150 lines

5. **Fix K2 compiler warnings** -- run `./gradlew compileDebugKotlin` and fix all warnings/errors

6. **Address remaining TODOs:**
   - `TwilioVoicePlugin.kt:184,202` -- outgoing call direction detection (verify after Phase 02 refactor)
   - `StorageImpl.kt:78,87` -- remove asserts

7. **Modernize idioms:**
   - Replace `HashMap` with `mutableMapOf()`
   - Use `sealed class` for call events if beneficial
   - Ensure proper null safety (no `!!` operators)
   - Use `when` exhaustive matching

8. **Compile and test:**
   - `./gradlew compileDebugKotlin` passes
   - `fvm flutter build apk --debug` succeeds
   - All MethodChannel methods still work

## Todo List

- [x] Create `TVPluginState.kt`
- [x] Create `TVEventEmitter.kt`
- [x] Create `handler/TVCallMethodHandler.kt`
- [x] Create `handler/TVAudioMethodHandler.kt`
- [x] Create `handler/TVPermissionMethodHandler.kt`
- [x] Create `handler/TVRegistrationMethodHandler.kt`
- [x] Create `handler/TVConfigMethodHandler.kt`
- [x] Refactor `TwilioVoicePlugin.kt` to router (<150 lines)
- [x] Fix K2 compiler warnings
- [x] Remove StorageImpl assert TODOs
- [x] Fix outgoing call direction detection TODO
- [x] Verify all 51 MethodChannel methods still route correctly
- [x] Compile check passes

## Success Criteria

- No Kotlin file exceeds 200 lines
- `./gradlew compileDebugKotlin` passes with zero errors
- All 51 MethodChannel methods work as before
- No `!!` null assertions in new code
- K2 compiler zero warnings (or documented suppressions)

## Risk Assessment

| Risk | Likelihood | Impact | Mitigation |
|------|-----------|--------|------------|
| Method routing breaks during split | Medium | High | Test each MethodChannel method individually |
| K2 compiler flags non-trivial issues | Low | Medium | Fix incrementally; K2 issues are usually straightforward |
| Handler class interfaces become awkward | Low | Low | Keep simple: each handler takes PluginState + MethodCall + Result |

## Security Considerations

- No security changes; pure refactoring
- Ensure permission checks are preserved in TVPermissionMethodHandler

## Next Steps

- This phase produces clean, modular Kotlin code ready for long-term maintenance
- No downstream dependencies
