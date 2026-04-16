# Code Review: Phase 02 Android In-App Calling

**Date:** 2026-04-03
**Scope:** TVCallState, TVAudioManager, TVCallAudioService, TVCallManager (new); TwilioVoicePlugin, VoiceFirebaseMessagingService, TVBroadcastReceiver, AndroidManifest.xml (modified)
**Build:** SUCCESSFUL (deprecation warnings only, acceptable per Phase 03 plan)

---

## Overall Assessment

The architecture is sound. Replacing ConnectionService/TelecomManager with a singleton TVCallManager + foreground service (TVCallAudioService) correctly achieves the in-app calling goal. The build passes. The critical issues below are real bugs that will manifest in production — they are not theoretical.

---

## Critical Issues

### 1. TVCallManager is a Kotlin `object` — not thread-safe for shared mutable state

**File:** `TVCallManager.kt`

`TVCallManager` is a Kotlin `object` (singleton). Its mutable fields `activeCall`, `activeCallInvite`, and `listener` are accessed from at least three different threads:
- The main thread (Flutter method calls via `onMethodCall`)
- The FCM thread (`VoiceFirebaseMessagingService.onCallInvite` runs on a background thread)
- The Twilio SDK callback thread (`Call.Listener` callbacks — `onConnected`, `onDisconnected`, etc. are delivered on a background thread per Twilio SDK docs)

There is no synchronization (`@Synchronized`, `Mutex`, `AtomicReference`, `Handler`, or `volatile`) anywhere on these fields. The result is a data race:

- `activeCall` can be set to non-null by `makeCall`/`acceptCall` on the main thread and cleared by `cleanup` on the SDK callback thread simultaneously.
- `activeCallInvite` is written by `handleCallInvite` (FCM thread) and read/nulled by `acceptCall`/`rejectCall` (main thread) without synchronization.
- The listener replay in the `listener` setter reads `activeCallInvite` — if the FCM thread is simultaneously writing it, this is a read/write race.

**Fix:** Dispatch all `Call.Listener` callbacks and FCM writes to the main thread using a `Handler(Looper.getMainLooper()).post { ... }` wrapper, or annotate the critical sections with `@Synchronized`. The simplest correct approach is to post all callbacks to main:

```kotlin
private val mainHandler = Handler(Looper.getMainLooper())

override fun onDisconnected(call: Call, error: CallException?) {
    mainHandler.post {
        cleanup()
        listener?.onCallDisconnected(call, error)
    }
}
```

Apply this to all `Call.Listener` overrides and to `handleCallInvite`/`handleCancelledCallInvite`.

---

### 2. `TVCallAudioService` uses `START_STICKY` — orphaned service on process death

**File:** `TVCallAudioService.kt`, line 57

`onStartCommand` returns `START_STICKY`. If the process is killed mid-call (OOM killer, user swipes from recents), Android will restart the service with a `null` intent. The code handles the null intent gracefully (falls back to "Unknown"), but the larger problem is:

- The service restarts without an active `Call` object. `TVCallManager.activeCall` is null (the singleton state is gone).
- Audio focus was abandoned implicitly on process death but `TVCallAudioService` is now running again without audio focus.
- The foreground notification says "Active Call" but there is no actual call.

**Fix:** Return `START_NOT_STICKY` instead. The service should only be alive while there is an active call. If the process is killed, the call is dead — the service should not restart.

```kotlin
return START_NOT_STICKY
```

---

### 3. Double-event emission on FCM-arrives-before-plugin-initialized path

**Files:** `VoiceFirebaseMessagingService.kt`, `TVCallManager.kt` (listener setter), `TwilioVoicePlugin.kt` (handleBroadcastIntent + onCallInviteReceived)

When FCM arrives before the plugin is attached:
1. `VoiceFirebaseMessagingService.onCallInvite` calls `TVCallManager.handleCallInvite(invite)` — stores the invite, `listener` is null so no callback fires.
2. A `LocalBroadcast` with `ACTION_INCOMING_CALL` is also sent.
3. Plugin attaches. `TVCallManager.listener = plugin` triggers the replay in the setter → `plugin.onCallInviteReceived(invite)` → emits `Incoming|Ringing` events via `logEvents`.
4. The `LocalBroadcast` from step 2 is also delivered to `handleBroadcastIntent` → emits `Incoming|Ringing` events again.

The Flutter side receives the incoming call notification twice. This will cause duplicate UI states or duplicate call screens depending on how the Dart side handles them.

**Fix:** Pick one notification path for the FCM-arrives-before-plugin case. The simplest fix is: in `handleBroadcastIntent` for `ACTION_INCOMING_CALL`, check whether the event was already emitted via the TVCallManagerListener path (e.g., skip if `TVCallManager.activeCallInvite == null` at this point, meaning the replay already cleared it). Or better: remove the `LocalBroadcast` from `VoiceFirebaseMessagingService` entirely and rely solely on TVCallManagerListener replay + direct callback when the plugin is already attached.

---

## High Priority

### 4. `cleanup()` does not null `activeCallInvite`

**File:** `TVCallManager.kt`, lines 165-170

```kotlin
private fun cleanup() {
    activeCall = null
    _audioManager?.reset()
    _audioManager?.abandonAudioFocus()
    appContext?.let { TVCallAudioService.stopService(it) }
}
```

`activeCallInvite` is not cleared in `cleanup()`. If a connect failure (`onConnectFailure`) or disconnect occurs while an invite is lingering (edge case but possible), `hasActiveCall()` will still return `true` and the service might attempt to stop while the invite is still considered active.

**Fix:** Add `activeCallInvite = null` to `cleanup()`.

---

### 5. `acceptCall` clears `activeCallInvite` before the SDK call completes

**File:** `TVCallManager.kt`, lines 64-75

```kotlin
activeCall = invite.accept(context, this)
activeCallInvite = null   // cleared immediately
TVCallAudioService.startService(...)
_audioManager?.requestAudioFocus()
```

`invite.accept()` is asynchronous. The `Call` object returned may be in a pre-connected state. If `onConnectFailure` fires before `onConnected`, `activeCall` is cleaned up via `cleanup()`, but `activeCallInvite` is already gone — there is no way to retry or surface the original invite. This is acceptable for now as long as the Dart side handles `onCallConnectFailure` correctly and shows an error, but callers should be aware there is no retry path.

More critically: if `invite.accept()` returns `null` (SDK contract allows this), `activeCall` is null, the audio service is started, and audio focus is requested — but there is no actual call. There is no null check.

**Fix:**
```kotlin
val call = invite.accept(context, this)
activeCallInvite = null
if (call == null) {
    Log.e(TAG, "acceptCall: invite.accept() returned null")
    return false
}
activeCall = call
TVCallAudioService.startService(context, invite.from ?: "Unknown")
_audioManager?.requestAudioFocus()
```

---

### 6. Audio mode set before audio focus is granted

**File:** `TVAudioManager.kt`, lines 20-36

`requestAudioFocus()` calls `audioManager.requestAudioFocus(...)` then immediately sets `audioManager.mode = AudioManager.MODE_IN_COMMUNICATION` regardless of whether focus was actually granted. `requestAudioFocus` returns `AUDIOFOCUS_REQUEST_GRANTED`, `AUDIOFOCUS_REQUEST_DELAYED`, or `AUDIOFOCUS_REQUEST_FAILED`. The return value is discarded.

If another app (phone call, navigation) holds audio focus and returns `AUDIOFOCUS_REQUEST_FAILED`, the mode is still changed to `MODE_IN_COMMUNICATION`, corrupting the audio routing for that other app and potentially for this one.

**Fix:** Check the return value before changing mode:
```kotlin
val result = audioManager.requestAudioFocus(focusRequest!!)
if (result == AudioManager.AUDIOFOCUS_REQUEST_GRANTED) {
    audioManager.mode = AudioManager.MODE_IN_COMMUNICATION
}
```

---

### 7. `unregisterReceiver` uses `activity!!` instead of `context!!`

**File:** `TwilioVoicePlugin.kt`, line 1168

```kotlin
LocalBroadcastManager.getInstance(activity!!).unregisterReceiver(broadcastReceiver!!)
```

But `registerReceiver` at line 1158 uses `context!!`:
```kotlin
LocalBroadcastManager.getInstance(context!!)
    .registerReceiver(broadcastReceiver!!, intentFilter)
```

`LocalBroadcastManager.getInstance()` returns a singleton keyed by `Context.getApplicationContext()`. Passing different contexts (Activity vs Application context) will both resolve to the same instance via `getApplicationContext()` internally, so this will not cause a missed unregister in practice. However it is inconsistent and fragile — if the implementation ever changes, it will silently fail to unregister. Use `context!!` consistently in both places.

---

### 8. `TVCallState` data class is defined but never used

**File:** `TVCallState.kt`

This data class is not referenced anywhere in the codebase (not in TVCallManager, TVCallAudioService, or TwilioVoicePlugin). It was presumably intended as a snapshot model but the implementation tracks state via individual boolean fields on TVCallManager and TwilioVoicePlugin instead.

This is dead code. Either use it to replace the scattered boolean fields, or delete it to avoid confusion about the intended design.

---

## Medium Priority

### 9. Duplicate call state tracking between TwilioVoicePlugin and TVCallManager

**File:** `TwilioVoicePlugin.kt`, lines 95-98

```kotlin
private var isSpeakerOn: Boolean = false
private var isBluetoothOn: Boolean = false
private var isMuted: Boolean = false
private var isHolding: Boolean = false
```

`TVAudioManager` already tracks `isSpeakerOn` and `isBluetoothOn` (lines 15-18 of TVAudioManager.kt). `TwilioVoicePlugin` maintains its own copies and updates them in `toggleSpeaker`, `toggleBluetooth`, `toggleMute`, `toggleHold`. If `TVAudioManager.setSpeaker` is ever called from another path (e.g., Bluetooth disconnect SCO callback), the plugin's local copy goes stale.

The `IS_ON_SPEAKER` and `IS_BLUETOOTH_ON` method channel handlers return the plugin's local copy, not TVAudioManager's truth. These can diverge.

**Fix:** Remove `isSpeakerOn`/`isBluetoothOn` from TwilioVoicePlugin and delegate to `TVCallManager.audioManager?.isSpeakerOn` and `TVCallManager.audioManager?.isBluetoothOn` directly.

---

### 10. Stale comment in TVBroadcastReceiver

**File:** `TVBroadcastReceiver.kt`, line 11

```kotlin
/**
 * Broadcast receiver provides communication from [TVConnectionService] to [TwilioVoicePlugin]
 */
```

`TVConnectionService` was deleted. The comment should reference `VoiceFirebaseMessagingService` and `TVCallManager`.

---

### 11. `callListener()` in TwilioVoicePlugin is dead code

**File:** `TwilioVoicePlugin.kt`, lines 84, 161-223

`callListener` is instantiated at line 84 (`private var callListener = callListener()`) but is never passed to any Twilio SDK call. All `Call.Listener` routing is now through `TVCallManager`, which implements `Call.Listener` directly. The `callListener()` function and the `callListener` field are unused.

---

### 12. `requestPermissionForMicrophoneForeground` is a no-op on the rationale path

**File:** `TwilioVoicePlugin.kt`, lines 1376-1393

In `requestPermissionOrShowRationale`, when `shouldShowRationale` is true, `permissionResultHandler[requestCode]` is never set. The dialog's click listener calls `ActivityCompat.requestPermissions` but the result handler is null, so `onPermissionResult` is never called. This affects any permission going through the rationale dialog — the caller never receives the result.

---

## Low Priority

### 13. `hasBluetoothDevice()` checks `TYPE_BLUETOOTH_A2DP` for SCO routing

**File:** `TVAudioManager.kt`, line 76

A2DP (Advanced Audio Distribution Profile) is for media playback (stereo audio). Voice calls use SCO (Synchronous Connection-Oriented). Returning true for A2DP devices when the user asks "is there a Bluetooth device for calls" is misleading and may cause `setBluetooth` to be offered as an option when no SCO-capable device is connected. Keep only `TYPE_BLUETOOTH_SCO`.

---

### 14. `NOTIFICATION_ID = 1001` is hardcoded

**File:** `TVCallAudioService.kt`, line 20

If the host app uses notification ID 1001 for something else, there will be a collision. This is low risk in practice but worth noting.

---

## Edge Cases Found

- **App backgrounded + phone locked during active call:** `TVCallAudioService` foreground notification keeps the process alive. Confirmed correct path.
- **Two rapid FCM messages for the same callSid:** `handleCallInvite` overwrites `activeCallInvite` with the second invite. The first invite is silently dropped without rejection. Twilio's SDK should prevent this at the server level, but there is no guard.
- **`hangUp()` called with no active call:** Returns false, no crash. Correct.
- **`rejectCall()` called after FCM cancellation already cleared `activeCallInvite`:** Returns false (line 78 guard). Correct, but Dart side receives `false` success without an error, so the caller cannot distinguish "rejected" from "nothing to reject."
- **Config change (screen rotate) during active call:** `onDetachedFromActivityForConfigChanges` unregisters the broadcast receiver, `onReattachedToActivityForConfigChanges` re-registers it. The audio service and TVCallManager singleton remain alive. Call survives correctly.
- **Plugin detached (engine destroyed) during active call:** `onDetachedFromEngine` sets `TVCallManager.listener = null`. The call continues in TVCallManager (audio service is still alive), but no events reach Flutter. `cleanup()` will still stop the audio service on disconnect. This is acceptable behavior — the app is being destroyed.

---

## Positive Observations

- The FCM-arrives-before-plugin replay pattern (listener setter triggering `activeCallInvite?.let { value?.onCallInviteReceived(it) }`) is a clean solution to a real initialization race.
- `TVCallAudioService` correctly uses `FOREGROUND_SERVICE_TYPE_MICROPHONE` for Android 14+ compliance with the `foregroundServiceType="microphone"` manifest declaration.
- `PendingIntent.FLAG_IMMUTABLE` is set on Android M+ — correct.
- `exported="false"` on `TVCallAudioService` — correct, no external process should bind to it.
- `onDetachedFromEngine` correctly nulls `TVCallManager.listener` to prevent leaking the plugin reference via the singleton.
- `TVAudioManager.reset()` is called before `abandonAudioFocus()` in `cleanup()` — correct ordering (stop SCO/speaker before releasing focus).

---

## Recommended Actions (Prioritized)

1. **[Critical]** Add `Handler(Looper.getMainLooper()).post { }` wrappers to all `Call.Listener` callbacks in TVCallManager to ensure main-thread access to shared mutable state.
2. **[Critical]** Change `START_STICKY` to `START_NOT_STICKY` in `TVCallAudioService.onStartCommand`.
3. **[Critical]** Fix the double-event emission on FCM-before-plugin path — remove the LocalBroadcast from VoiceFirebaseMessagingService or add a guard in `handleBroadcastIntent`.
4. **[High]** Add null check on `invite.accept()` return value in `acceptCall`.
5. **[High]** Check `requestAudioFocus` return value before setting `MODE_IN_COMMUNICATION`.
6. **[High]** Add `activeCallInvite = null` to `cleanup()`.
7. **[Medium]** Delete `callListener` field and `callListener()` function (dead code).
8. **[Medium]** Delete `TVCallState.kt` or actually use it to consolidate state.
9. **[Medium]** Fix `unregisterReceiver` to use `context!!` consistently.
10. **[Low]** Remove `TYPE_BLUETOOTH_A2DP` from `hasBluetoothDevice()`.
11. **[Low]** Fix rationale dialog path — set `permissionResultHandler[requestCode]` before showing the dialog.
