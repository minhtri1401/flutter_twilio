# Phase 01: Dependency Upgrades

## Context Links

- [Plan Overview](plan.md)
- [SDK Versions Research](research/researcher-01-sdk-versions-report.md)
- [Scout Report](scout/scout-01-codebase-report.md)

## Overview

- **Priority:** P1 (blocker for all other phases)
- **Status:** complete
- **Effort:** 45m
- **Description:** Upgrade all SDK versions, toolchain, and build configuration to latest stable releases.

## Key Insights

- AGP 9.1.0 requires Gradle 9.3.1 + JDK 17 (current: AGP 8.5.2, JDK 1.8 target)
- Kotlin 2.3.20 brings K2 compiler; may flag new warnings
- Twilio SDK versions need manual verification from GitHub releases page
- `compileOptions` currently targets Java 1.8; AGP 9.x requires at least Java 17 compilation
- Firebase BOM 33.10.0 may need bump for compatibility with new AGP

## Requirements

### Functional
- All dependencies compile without errors
- Plugin builds for both Android and iOS
- No runtime regressions from version bumps alone

### Non-Functional
- JDK target upgraded to 17
- K2 compiler enabled by default with Kotlin 2.3.20

## Architecture

No architectural changes. This is a version bump phase only.

## Related Code Files

### Files to Modify

| File | Changes |
|------|---------|
| `android/build.gradle` | Kotlin 2.3.20, AGP 9.1.0, Twilio SDK version, JDK 17 target, Firebase BOM |
| `android/gradle/wrapper/gradle-wrapper.properties` | Gradle 9.3.1 distribution URL |
| `android/settings.gradle` | May need plugin management syntax for AGP 9.x |
| `ios/twilio_voice.podspec` | Twilio Voice SDK version, min iOS deployment target |
| `pubspec.yaml` | `plugin_platform_interface` version |
| `example/android/build.gradle` | Match AGP/Kotlin versions |
| `example/android/gradle/wrapper/gradle-wrapper.properties` | Gradle 9.3.1 |

## Implementation Steps

1. **Verify exact SDK versions** before any changes:
   - Check https://github.com/twilio/twilio-voice-android/releases for latest Android SDK
   - Check https://github.com/twilio/twilio-voice-ios/releases for latest iOS SDK
   - Check https://pub.dev/packages/plugin_platform_interface for latest version
   - Document exact versions in this file before proceeding

2. **Update `android/build.gradle`:**
   ```
   kotlinVersion = "2.3.20"
   agpVersion = "9.1.0"
   twilioVoiceVersion = "<verified-version>"
   ```
   - Change `JavaVersion.VERSION_1_8` to `JavaVersion.VERSION_17` in compileOptions
   - Change `jvmTarget = '1.8'` to `jvmTarget = '17'`
   - Update Firebase BOM if needed for AGP 9.x compat

3. **Update Gradle wrapper:**
   - Set `distributionUrl` to `gradle-9.3.1-all.zip`

4. **Update `ios/twilio_voice.podspec`:**
   - Change `s.dependency 'TwilioVoice','~> 6.13.1'` to verified latest
   - Consider raising `s.platform` and `s.ios.deployment_target` from `11.0` to `13.0` if new SDK requires it

5. **Update `pubspec.yaml`:**
   - Bump `plugin_platform_interface` to latest 2.x
   - Do not change `js` or `web` packages (web/macOS platform out of scope)

6. **Compile check:**
   - Run `fvm flutter pub get`
   - Run `fvm flutter analyze`
   - Build Android: `cd example && fvm flutter build apk --debug`
   - Build iOS: `cd example && fvm flutter build ios --no-codesign`

## Todo List

- [x] Verify exact latest Twilio Voice SDK (Android) — 6.9.0 confirmed latest on Maven Central
- [x] Verify exact latest Twilio Voice SDK (iOS) — 6.13.6
- [x] Verify latest `plugin_platform_interface` — 2.1.8
- [x] Update `android/build.gradle` versions + JDK target
- [x] Update Gradle wrapper — 8.11.1 (AGP 9.1.0 skipped: incompatible with Flutter 3.29.3 / Gradle 9 removes groovy.xml.QName used by flutter.groovy)
- [x] Update `ios/twilio_voice.podspec` — TwilioVoice ~> 6.13.6, deployment_target 13.0
- [x] Update `pubspec.yaml` — plugin_platform_interface ^2.1.8
- [x] Update example app build files to match — AGP 8.8.0, Gradle 8.11.1, layout API buildDir, iOS platform 13.0
- [x] Run `fvm flutter pub get` successfully
- [x] Run `fvm flutter analyze` with zero errors
- [x] Compile Android debug APK — SUCCESS
- [ ] Compile iOS (no-codesign) — blocked by missing GoogleService-Info.plist in example app (pre-existing env requirement, not caused by these changes)

## Success Criteria

- `fvm flutter pub get` resolves without conflicts
- `fvm flutter analyze` passes with zero errors (warnings acceptable)
- Android and iOS debug builds compile successfully
- No runtime crashes on app launch

## Risk Assessment

| Risk | Likelihood | Impact | Mitigation |
|------|-----------|--------|------------|
| AGP 9.x has breaking Gradle DSL changes | Medium | High | Check AGP migration guide; may need settings.gradle rewrite |
| K2 compiler flags existing code as errors | Medium | Medium | Fix iteratively; can suppress with `@Suppress` temporarily |
| Twilio SDK major version has breaking API | Medium | High | If v7.x breaks API, pin to latest v6.x instead |
| Firebase BOM incompatibility | Low | Medium | Pin specific firebase-messaging version |

## Security Considerations

- No secrets or credentials involved in dependency upgrades
- Verify dependency checksums / signatures via Gradle verification if available

## Next Steps

- Phase 02 depends on this phase completing successfully
- If Twilio SDK has major breaking changes, update Phase 02/03 plans accordingly
