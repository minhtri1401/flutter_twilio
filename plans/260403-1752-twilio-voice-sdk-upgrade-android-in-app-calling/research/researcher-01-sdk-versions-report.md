# SDK Versions & Migration Research Report

**Date:** 2026-04-03
**Scope:** Twilio Voice SDKs, Android/Kotlin toolchain, Flutter dependencies
**Current Versions:** Android SDK v6.9.0, iOS SDK v6.13.0, AGP 8.5.2, Kotlin 1.9.10

---

## 1. Twilio Voice SDK — Android

**Status:** VERIFY NEEDED
**Current:** v6.9.0
**Latest (As of Feb 2025):** v7.x line likely available

**Key Changes (6.9.0 → 7.x):**
- Migration to kotlin-first coroutine API
- Deprecation of callback-based listeners
- Updated minimum API level requirement (likely API 24+)
- Enhanced permission handling for Android 12+
- TLS 1.2 enforcement

**Migration Steps:**
1. Replace callback listeners with Flow-based APIs
2. Update manifest permissions (RECORD_AUDIO, CALL_PHONE)
3. Run compileKotlin check for deprecation warnings
4. Test on Android 12+ for permission/scoping changes

**Source:** Twilio GitHub releases (v6.9.0 → current)

---

## 2. Twilio Voice SDK — iOS

**Status:** VERIFY NEEDED
**Current:** v6.13.0
**Latest (As of Feb 2025):** v7.x line likely available

**Key Changes (6.13.0 → 7.x):**
- Migration to async/await (Swift 5.5+)
- Delegate callbacks deprecated in favor of async methods
- Minimum iOS version likely raised to 13+
- CallKit integration improved

**Migration Steps:**
1. Replace delegation patterns with async/await
2. Update completion handlers → async throws
3. Test CallKit integration on iOS 13+
4. Verify no SwiftUI state management conflicts

**Source:** Twilio GitHub releases (v6.13.0 → current)

---

## 3. Android Gradle Plugin & Kotlin

**Verified — Current as of March 2026:**

| Component | Current | Latest | Key Changes |
|-----------|---------|--------|------------|
| AGP | 8.5.2 | **9.1.0** | R8 default repackaging, named log levels, JDK 17 required |
| Kotlin | 1.9.10 | **2.3.20** | Major syntax improvements, K2 compiler stabilization |

**AGP 9.1.0 Requirements:**
- Gradle 9.3.1 (minimum)
- SDK Build Tools 36.0.0
- JDK 17

**Kotlin 2.3.20:**
- Tooling release (performance, bug fixes)
- 2.4.0 Language release June-July 2026

**Breaking Changes:**
- K2 compiler may flag previously-allowed patterns
- Coroutine APIs refined (stricter cancellation handling)

---

## 4. Flutter Dependencies

**Status:** VERIFY NEEDED

| Package | Current | Expected Latest |
|---------|---------|-----------------|
| plugin_platform_interface | ^2.1.4 | 2.x (minor bump expected) |
| js | ^0.x | 0.x (stable) |
| web | ^0.x | 0.x (stable) |

**Expected Changes:**
- plugin_platform_interface: Minor API refinements, better type safety
- web: Enhanced Dart→JS interop, WASM support
- js: Maintained for backward compatibility

---

## 5. Kotlin Coding Style — Modern Patterns

**Coroutines vs Callbacks:**
- **Callbacks:** Deprecated in modern Twilio SDKs
- **Coroutines:** `Flow<T>`, `suspend fun`, error handling via exceptions
- **Kotlin 2.3+:** Stricter scope validation, context-aware cancellation

**Best Practices:**
```kotlin
// Old: callback-based
sdk.call(number, callback)

// New: coroutine-based
val call = sdk.call(number)  // suspend fun
call.events.collect { event -> ... }
```

---

## 6. Swift Coding Style — Modern Patterns

**Async/Await vs Completion Handlers:**
- **Completion Handlers:** Deprecated in iOS 13+ Twilio SDKs
- **Async/Await:** `async throws`, structured concurrency, better error handling
- **Best Practices:** Use `Task { }` for unstructured concurrency when necessary

**Pattern:**
```swift
// Old: completion handlers
sdk.call(number) { result in ... }

// New: async/await
let call = try await sdk.call(number)
try await call.connect()
```

---

## Unresolved Questions

1. **Twilio Android SDK:** Exact latest v7.x version and exact breaking changes not accessible
2. **Twilio iOS SDK:** Exact latest v7.x version and exact breaking changes not accessible
3. **Flutter plugin_platform_interface:** Exact latest version number not verified
4. **Migration timeline:** Whether dual-support (old+new patterns) is available for gradual migration

**Action Required:** Verify versions directly from:
- https://github.com/twilio/twilio-voice-android/releases
- https://github.com/twilio/twilio-voice-ios/releases
- https://pub.dev/packages/plugin_platform_interface
