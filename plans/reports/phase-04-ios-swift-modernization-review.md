# Phase 04 iOS Swift Modernization — Code Review Report

**Date:** 2026-04-03
**Scope:** 8 Swift files totaling ~984 lines (split from original 1168-line monolith)
**Build status at review:** iOS Pods BUILD SUCCEEDED

---

## Overall Assessment

The refactor is structurally sound. Protocol conformances are moved to the correct extension files, the `handle()` router is clean, and the Bluetooth toggle is a genuine implementation replacing the original `// TODO` stub. However, there are several correctness issues ranging from a behavioral regression in `isSpeakerOn`, a retained strong self reference pattern in audio blocks, a visibility regression on `clients`, and a subtle double-result call path in `handle()` that was already present in the original but is now more exposed.

---

## Critical Issues

### 1. `isSpeakerOn()` — Logic Regression (`TVAudioHandler.swift` line 6)

**Severity: High**

The original code had a `switch` inside the `for` loop that returned `false` on the *first non-speaker output*, meaning it always returned `false` if the first output was not `.builtInSpeaker` even when a second output was the speaker. The new code fixes this correctly:

```swift
// New — correct
for output in AVAudioSession.sharedInstance().currentRoute.outputs {
    if output.portType == .builtInSpeaker { return true }
}
return false
```

This is a **positive fix** over the original. No action needed, but it should be noted in the changelog because it is a behavior change.

---

## High Priority Issues

### 2. Strong `self` Capture in `audioDevice.block` Closures (`TVAudioHandler.swift` lines 35, 51, 59)

**Severity: High — retain cycle risk**

`audioDevice` is a stored property on `SwiftTwilioVoicePlugin`. The `block` property on `DefaultAudioDevice` is a closure stored on that object. Capturing `self` strongly inside `audioDevice.block = { ... self.sendPhoneCallEvents(...) }` creates a reference cycle:

```
SwiftTwilioVoicePlugin → audioDevice → block → SwiftTwilioVoicePlugin
```

The same pattern exists in `toggleAudioRoute` (line 35) — which was present in the original — but `toggleBluetooth` repeats it twice more (lines 51 and 59). Because `SwiftTwilioVoicePlugin` is a singleton-like plugin instance, the cycle is not destructive in practice (the plugin lives for the app lifetime), but it does prevent the instance from ever being deallocated and will cause issues in unit tests or if the plugin is ever re-registered.

**Fix:** Capture `self` weakly in all three `audioDevice.block` assignments:

```swift
audioDevice.block = { [weak self] in
    DefaultAudioDevice.DefaultAVAudioSessionConfigurationBlock()
    do {
        try AVAudioSession.sharedInstance().setPreferredInput(bluetoothInput)
    } catch {
        self?.sendPhoneCallEvents(description: "LOG|\(error.localizedDescription)", isError: false)
    }
}
```

The same applies to `toggleAudioRoute` (unchanged from original, but worth fixing here since the file is being touched).

### 3. `toggleBluetooth(on:)` Always Returns `true` on the Off-Path (`TVAudioHandler.swift` line 69)

**Severity: High — incorrect return value**

When `on == false`, the function sets `preferredInput` to `nil` and unconditionally returns `true` (line 69). This is correct when the `setPreferredInput` call succeeds. However, if the `do/catch` block throws and the error is logged, the function still returns `true`, telling the caller (and thus the Flutter side) that Bluetooth was successfully turned off when in fact the audio session mutation may have failed.

The `on == true` path correctly returns `false` when no HFP device is available (via `guard`), but the `on == false` path has no failure path at all. A minimal fix is to track the success flag:

```swift
var success = true
audioDevice.block = {
    DefaultAudioDevice.DefaultAVAudioSessionConfigurationBlock()
    do {
        try AVAudioSession.sharedInstance().setPreferredInput(nil)
    } catch {
        success = false
        self.sendPhoneCallEvents(description: "LOG|\(error.localizedDescription)", isError: false)
    }
}
audioDevice.block()
return success
```

### 4. `handle()` — Double `result(true)` Call for Several Methods (`SwiftTwilioVoicePlugin.swift` lines 96–130)

**Severity: High**

The `handle()` method stores `result` in `_result = result` and then falls through to `result(true)` at the bottom (line 129) for cases that do not `return` early. Several handlers that call `result(...)` internally **also** fall through to `result(true)`:

- `handleToggleMute` calls `result(FlutterError(...))` on the error branch but does not return, so the success branch falls through to the bottom `result(true)` — that call is correct, but the error branch will call `result` twice.
- `handleAnswer` calls `result(FlutterError(...))` on the error path without returning, so `result(true)` is also called.
- `handleTokens` calls `result(FlutterError(...))` internally without returning.

Calling a `FlutterResult` callback more than once causes a crash (`FlutterError: Reply already submitted`) in debug builds. This was technically present in the original monolithic file for `handleTokens`/`handleAnswer` (those methods did not guard-return), but it is more visible now.

**Fix:** Each handler that calls `result(...)` on the error branch should `return` immediately, or the handler should itself call `result(true)` on success and the bottom `result(true)` line should be removed in favour of each handler being responsible for its own result.

---

## Medium Priority Issues

### 5. `clients` Visibility Regression (`SwiftTwilioVoicePlugin.swift` line 23)

**Severity: Medium**

The original declared `private var clients: [String: String]!`. The new file declares `var clients: [String: String]!` (no access modifier), making it `internal`. Because all extension files are in the same module, `internal` is functionally equivalent to `private` at the extension level, so this does not cause a runtime issue. However, it is a visibility widening that removes the intent expressed by the original author. It should be restored to `private` since no external type needs to access it.

### 6. `onListen` — `#selector(CallDelegate.callDidDisconnect)` Registers a Selector That Is Never Posted (`SwiftTwilioVoicePlugin.swift` line 137)

**Severity: Medium**

The `NotificationCenter` observer registers for `"PhoneCallEvent"` notifications with `selector: #selector(CallDelegate.callDidDisconnect)`. No code in any of the 8 files posts a `"PhoneCallEvent"` notification, and `CallDelegate.callDidDisconnect` is the Twilio SDK delegate method, not an `@objc` selector exposed for `NotificationCenter`. This means the observer is registered but can never be triggered. This is carried over unchanged from the original and is likely dead code, but the `#selector` expression is surprising — if it compiled, it only works because `CallDelegate` declares the method with an Objective-C-compatible signature. It is effectively a no-op registration.

**Recommendation:** Remove the `NotificationCenter` observer entirely from `onListen`/`onCancel`, or document why it exists.

### 7. `isBluetoothOn()` Checks Inputs, Not Outputs (`TVAudioHandler.swift` line 13)

**Severity: Medium — may give incorrect results in A2DP-only scenarios**

The implementation checks `currentRoute.inputs` for Bluetooth port types. For Bluetooth A2DP (stereo audio, output-only) headphones, there is no matching input — `.bluetoothA2DP` only appears as an output port. Checking `currentRoute.inputs` will return `false` for A2DP-only devices (e.g., standard Bluetooth headphones without a mic). For phone calls using HFP this is correct, but the method name `isBluetoothOn()` implies a broader check.

Since the `toggleBluetooth` implementation only handles `.bluetoothHFP` for the input anyway, the check is internally consistent for the phone-call use case. The issue is the presence of `.bluetoothA2DP` and `.bluetoothLE` in the `isBluetoothOn` check — these cannot appear in `inputs` on iOS in practice, making those cases dead switch arms.

**Recommendation:** Either restrict the check to `.bluetoothHFP` only (matching the capability of `toggleBluetooth`), or check both inputs and outputs for the full Bluetooth-active test and document the distinction.

### 8. `performAnswerVoiceCall` — Force-Unwrap on `theCall.from!` and `theCall.to!` (`TVCallKitActions.swift` line 96)

**Severity: Medium — crash risk**

```swift
sendPhoneCallEvents(description: "Answer|\(theCall.from!)|\(theCall.to!)|Incoming...", isError: false)
```

Both `from` and `to` on a `Call` object are `String?`. Force-unwrapping will crash if either is nil (e.g., server-side misconfiguration). This was present in the original. A safe alternative:

```swift
let from = theCall.from ?? identity
let to = theCall.to ?? callTo
sendPhoneCallEvents(description: "Answer|\(from)|\(to)|Incoming...", isError: false)
```

This matches the pattern used consistently in `callDidStartRinging` and `callDidConnect`.

---

## Low Priority Issues

### 9. `registrationRequired()` — Force Cast on `lastBindingCreated` (`TVRegistrationHandler.swift` line 66)

```swift
let expirationDate = Calendar.current.date(byAdding: components, to: lastBindingCreated as! Date)!
```

`UserDefaults.object(forKey:)` returns `Any?`. If the stored value is not a `Date` (corruption or unexpected type), this will crash. A safe cast (`as? Date`) with a fallback to return `true` would be more defensive.

### 10. `UIWindow.topMostViewController` Force Cast (`SwiftTwilioVoicePlugin.swift` lines 175, 178)

```swift
let nav = presentedViewController as! UINavigationController
let tab = presentedViewController as! UITabBarController
```

These force casts follow a `case is UINavigationController` check, so they are safe, but `as!` could be replaced with `as?` and an early return for future safety.

### 11. `makeCall` — `UIApplication.shared.keyWindow` Deprecated (`TVCallHandler.swift` line 93)

```swift
guard let vc = UIApplication.shared.keyWindow?.topMostViewController() else { return }
```

`keyWindow` is deprecated since iOS 13. For apps with multiple scenes, the correct approach is `UIApplication.shared.connectedScenes`. This was present in the original. It functions correctly on current iOS but will generate a deprecation warning.

### 12. `sendPhoneCallEvents` Visibility Change

The original declared `sendPhoneCallEvents` and `sendEvent` as `private`. The new file declares them without an access modifier (effectively `internal`). Since extension files in the same module need to call these methods, `internal` is the minimum required visibility — but this is a wider exposure than the original. No functional impact, but worth noting.

---

## Missing Cases Compared to Original

All functional paths from the 1168-line original have been accounted for in the new files. Specifically confirmed:

- All 26 `handle()` method cases are present in the new switch statement.
- `PKPushRegistryDelegate` — both the deprecated (no-completion) and current (with-completion) variants of `didReceiveIncomingPushWith` are present in `TVRegistrationHandler.swift`.
- `CXProviderDelegate` — all 8 required methods are present in `TVCallKitDelegate.swift`.
- `CallDelegate` — all 5 methods (`callDidStartRinging`, `callDidConnect`, `isReconnectingWithError`, `callDidReconnect`, `callDidFailToConnect`, `callDidDisconnect`) are present in `TVCallHandler.swift`.
- `NotificationDelegate` — `callInviteReceived` and `cancelledCallInviteReceived` are present in `TVNotificationDelegate.swift`.
- `UNUserNotificationCenterDelegate` — both `didReceive` and `willPresent` are present in `TVNotificationDelegate.swift`.
- `incomingPushHandled()` is present in `TVCallKitDelegate.swift`.
- `deinit { callKitProvider.invalidate() }` is preserved in the main file.
- `registrar.addApplicationDelegate(instance)` is preserved.

No methods appear to have been dropped.

---

## Positive Observations

- The Bluetooth toggle implementation is correct for the HFP (handsfree profile) use case, which is the only relevant profile for in-call audio routing on iOS. Using `availableInputs` rather than `currentRoute.inputs` is the right approach for finding a connectable device.
- The `audioDevice.block()` call pattern (calling the block immediately after setting it) correctly mirrors the pattern used in `toggleAudioRoute`, ensuring consistency in how audio session configuration is applied.
- Protocol conformances are correctly placed in separate extension files. Swift allows protocol conformance to be declared in an extension in any file within the same module, so this is valid and idiomatic.
- `sendEvent` correctly dispatches to `DispatchQueue.main.async` ensuring EventChannel callbacks are always called on the main thread, which is required by the Flutter engine.
- The `handle()` switch statement is a significant readability improvement over the original 26-branch if/else-if chain.
- `isSpeakerOn()` bug from original (returning `false` early on any non-speaker first output) is silently fixed.

---

## Recommended Actions (Prioritized)

1. **Fix double-result calls in `handle()`** — `handleToggleMute` and `handleAnswer` must `return` after calling `result(FlutterError(...))` to prevent duplicate-reply crashes.
2. **Add `[weak self]` to all three `audioDevice.block` closures** in `TVAudioHandler.swift` to break the retain cycle.
3. **Fix `toggleBluetooth` off-path return value** — track success inside the `do/catch` and return the actual outcome.
4. **Fix force-unwrap on `theCall.from!` / `theCall.to!`** in `performAnswerVoiceCall` to use nil-coalescing.
5. **Restore `private` on `clients`** in `SwiftTwilioVoicePlugin.swift`.
6. **Restrict `isBluetoothOn` switch arms** to `.bluetoothHFP` only or document the rationale.
7. **Remove dead `NotificationCenter` observer** from `onListen`/`onCancel` or add documentation explaining its intent.
8. **Fix force-cast in `registrationRequired()`** from `as! Date` to `as? Date` with fallback.

---

## Metrics

| Metric | Value |
|---|---|
| Files reviewed | 8 |
| Total LOC | ~984 |
| Build status | SUCCEEDED |
| Critical issues | 0 |
| High priority | 4 |
| Medium priority | 4 |
| Low priority | 4 |
| Missing cases vs original | 0 |
| Behavior improvements over original | 1 (`isSpeakerOn` fix) |
