# Android In-App Calling Research Report
**Date:** 2026-04-03 | **Focus:** Twilio Voice SDK Android implementation patterns for in-app vs system UI calling

---

## 1. ConnectionService / TelecomManager: Why System UI Pops Up

**Current Project Implementation:** The twilio_voice plugin uses `TVConnectionService extends ConnectionService()` with `android.telecom.ConnectionService` intent filter. This triggers **system telecom integration**, forcing Android to display the native call UI overlay.

**Technical Reason:**
- ConnectionService is Android's official telecom framework designed for VOIP apps. When registered as a callable service, the system automatically manages the call UI lifecycle
- TelecomManager (system service) intercepts calls and displays native incall UI regardless of app state
- This is by design—Google encourages system integration for consistency

**Current Project Code:**
- `TVConnectionService` extends `ConnectionService()`
- Manifest declares service with `android:permission="android.permission.BIND_TELECOM_CONNECTION_SERVICE"`
- Foreground service type: `android:foregroundServiceType="microphone"`
- This forces calls out of app → system takes over UI

---

## 2. In-App Calling Without ConnectionService

**Approach:** Skip ConnectionService entirely. Use direct Twilio Voice SDK call handling with custom Flutter UI.

**Twilio Voice SDK Pattern:**
- Initialize `Twilio.initialize()` directly, not via ConnectionService
- Listen to `CallInvite` via Firebase Cloud Messaging (FCM) push notifications
- Accept/reject via `callInvite.accept(context, listener)` or `callInvite.reject(context)`
- Manage call state (`RINGING` → `CONNECTING` → `CONNECTED` → `DISCONNECTED`) in app code
- Audio routing via `CallAudioState` callbacks in custom listeners

**Code Changes:**
1. Remove ConnectionService binding from manifest
2. Move call lifecycle logic out of `TVConnection extends Connection` → into custom `CallManager` class
3. Handle incoming calls via FCM directly → show custom Flutter overlay widget
4. Twilio SDK still manages signaling/media; you just control the UI presentation

**Limitations:**
- No native system integration (can't show fullscreen system UI if device is locked)
- You must implement call UI, hold, mute, audio routing controls
- Battery drain potential if foreground service not properly configured
- Less familiar UX pattern for users

---

## 3. Receiving Calls Without ConnectionService

**FCM Flow:**
```
FCM Message → VoiceFirebaseMessagingService
  → Extract CallInvite from payload
  → Post in-app notification + show Flutter overlay screen
  → User taps accept/reject in app → CallInvite.accept()/reject()
```

**Code Structure:**
- Keep `VoiceFirebaseMessagingService extends FirebaseMessagingService`
- Parse callInvite; don't register with ConnectionService
- Emit to Dart via MethodChannel event: `onCallInvite(callInvite)`
- Dart shows overlay using `flutter_callkit_incoming` or custom widget
- When user taps accept → Dart calls `TwilioVoice.acceptCall()` → Kotlin calls `callInvite.accept()`

**No System UI Requirement:** The FCM notification can launch your app; custom Flutter UI stays visible.

---

## 4. Flutter VoIP Plugins: Android Comparison

| Plugin | Android Approach | System UI | In-App | Notes |
|--------|-----------------|-----------|--------|-------|
| **flutter_callkit_incoming** | Native MethodChannel + custom notifications | Yes (optional) | Yes (preferred) | Newer; manages CallKit on iOS, custom UI on Android |
| **flutter_voip_kit** | ConnectionService wrapper | Yes (required) | No | Deprecated/unmaintained |
| **twilio_voice (current)** | ConnectionService (TVConnectionService) | Yes (forced) | No (with effort) |Designed for system integration |

**flutter_callkit_incoming Pattern:**
- On Android: Bypasses ConnectionService, uses local notifications + plugin UI overlay
- Sends events to Dart: `onDidActivateAudioSession`, `onDidDeactivateAudioSession`, `onAnswer`, `onReject`
- App controls call UI completely
- Better battery efficiency on Android (no system integration overhead)

---

## 5. Android Foreground Service Requirements

**Android 10+ (API 29+):**
- Requires `FOREGROUND_SERVICE` permission
- `startForegroundService()` must post notification within 5 seconds
- Current code does this via `TVConnectionService.startForeground(notification)`

**Android 14+ (API 34+):**
- New requirement: `FOREGROUND_SERVICE_MICROPHONE` permission (already in manifest)
- Foreground service type declaration in manifest required: `android:foregroundServiceType="microphone"`
- Service must declare capability in manifest, not runtime

**Current Project Compliance:**
- ✅ `FOREGROUND_SERVICE` permission declared
- ✅ `FOREGROUND_SERVICE_MICROPHONE` permission declared
- ✅ Service declares `android:foregroundServiceType="microphone"`
- ✅ Notification posted within lifecycle

**For In-App Only (No System UI):**
- You still need a foreground service to keep audio session alive
- New service class: `CallAudioForegroundService` (not ConnectionService)
- Must post notification during call duration
- Can close notification when call ends

---

## 6. iOS CallKit vs In-App: Design Implications

**iOS CallKit (current gold standard):**
- `CallKit.framework` integrates with system Recents, Phone app
- System displays native incall UI; app supplements via CallKit delegates
- Handles locked-screen calls natively
- Battery efficient (OS manages lifecycle)
- Better UX consistency with native Phone app

**iOS In-App (fallback):**
- Custom overlay widget (similar to Android approach)
- Less integrated with system (no Recents, Phone app history)
- Requires manual locked-screen handling
- Higher battery drain

**Flutter/Dart Implication:**
- iOS uses CallKit delegates → integrate via platform channel
- Android has no CallKit equivalent → must choose: system UI (ConnectionService) OR custom (no system integration)
- **Symmetry:** flutter_callkit_incoming tries to bridge this; provides similar API for both platforms

**Design Decision for twilio_voice:**
- Current: iOS CallKit + Android ConnectionService (consistent system integration)
- Alternative: iOS CallKit + Android in-app custom (divergent UX)
- Recommended: Evaluate use case. If locked-screen calls needed → keep system UI. If full control needed → go in-app both platforms.

---

## Key Implementation Changes for In-App Calling

| Item | Current | In-App Alternative |
|------|---------|-------------------|
| Service | `TVConnectionService extends ConnectionService` | `CallAudioForegroundService extends Service` |
| Manifest | Declares `android.telecom.ConnectionService` | No telecom permissions needed |
| Call Reception | System UI shows; TelecomManager routes | FCM → Custom Flutter overlay |
| Call State | Via Connection.State callbacks | Direct Call.Listener callbacks |
| Audio Management | ConnectionService handles | Manual CallAudioState routing |
| Permissions | `MANAGE_OWN_CALLS` | Remove; keep `FOREGROUND_SERVICE_MICROPHONE` |

---

## Summary & Unresolved Questions

**Key Finding:** System UI popup is caused by ConnectionService registration. Removing it + implementing custom call handling enables in-app-only calling, but requires manual UI/audio management.

**Migration Path:**
1. Create `CallAudioForegroundService` for media session keep-alive
2. Refactor `TVConnection` logic into `CallManager` (non-system-service)
3. Update `VoiceFirebaseMessagingService` to emit call events to Dart
4. Implement Flutter overlay UI layer

**Unresolved:**
- Does Twilio Voice SDK support raw `CallListener` without ConnectionService integration? (Likely yes, but verify SDK docs)
- What's the exact Twilio SDK approach for audio codec negotiation without ConnectionService? (Check Twilio Android SDK source)
- How does flutter_callkit_incoming handle audio session management on Android without system UI? (Likely via native AudioManager API directly)
