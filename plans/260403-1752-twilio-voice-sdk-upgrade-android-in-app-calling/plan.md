---
title: "Twilio Voice SDK Upgrade & Android In-App Calling"
description: "Upgrade Twilio SDKs, modernize Kotlin/Swift code style, fix Android in-app calling by replacing ConnectionService with custom call handling"
status: completed
priority: P1
effort: 5-6h
branch: master
tags: [twilio, android, ios, flutter, voip, upgrade]
created: 2026-04-03
---

# Twilio Voice SDK Upgrade & Android In-App Calling

## Problem

Android calls pop to system call UI because `TVConnectionService` extends `ConnectionService` and uses `TelecomManager.addNewIncomingCall()`. iOS already works in-app via CallKit.

## Solution

Replace Android's ConnectionService architecture with a custom `TVCallManager` + foreground `Service` for audio session. Upgrade all SDK/toolchain versions. Modernize Kotlin/Swift code.

## Phases

| # | Phase | Effort | Status | File |
|---|-------|--------|--------|------|
| 1 | Dependency Upgrades | 45m | **complete** | [phase-01](phase-01-dependency-upgrades.md) |
| 2 | Android In-App Calling (critical) | 2.5h | **complete** | [phase-02](phase-02-android-in-app-calling.md) |
| 3 | Android Kotlin Modernization | 1h | **complete** | [phase-03-android-kotlin-modernization.md](phase-03-android-kotlin-modernization.md) |
| 4 | iOS Swift Modernization | 45m | **complete** | [phase-04-ios-swift-modernization.md](phase-04-ios-swift-modernization.md) |
| 5 | Dart Cleanup | 30m | **complete** | [phase-05-dart-cleanup.md](phase-05-dart-cleanup.md) |

## Key Dependencies

- Phase 2 depends on Phase 1 (upgraded SDK needed)
- Phase 3 depends on Phase 2 (refactored files are the modernization targets)
- Phase 4 is independent of Phase 2/3
- Phase 5 runs last (removes obsolete Dart-side phone account methods)

## Research

- [Scout Report](scout/scout-01-codebase-report.md) -- codebase structure, current versions, integration points
- [SDK Versions](research/researcher-01-sdk-versions-report.md) -- AGP 9.1.0, Kotlin 2.3.20, Twilio version TBD
- [In-App Calling](research/researcher-02-android-in-app-calling-report.md) -- ConnectionService removal strategy

## Critical Files (by line count)

| File | Lines | Action |
|------|-------|--------|
| `TwilioVoicePlugin.kt` | 1953 | Refactor, split into <200-line modules |
| `SwiftTwilioVoicePlugin.swift` | 1168 | Modernize, consider splitting |
| `TVConnectionService.kt` | 791 | **Remove** (replace with TVCallManager + TVCallAudioService) |
| `TVConnection.kt` | 514 | **Remove** Connection base; extract Call.Listener logic |
| `VoiceFirebaseMessagingService.kt` | 175 | Refactor to emit directly to Dart |
| `TelecomManagerExtension.kt` | 237 | Mostly removable |

## Unresolved Questions

1. Exact latest Twilio Voice SDK versions (Android + iOS) -- must verify from GitHub releases before Phase 1
2. Whether Twilio Android SDK v7.x has breaking API changes to `CallInvite.accept()` / `Call.Listener`
3. Gradle wrapper version bundled with example app (needs update to 9.3.1 for AGP 9.1.0)
