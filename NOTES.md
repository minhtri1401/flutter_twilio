# Notes

> **Platform support:** Android + iOS only. Web and macOS support were removed in the `flutter_twilio` refactor. Use a prior `twilio_voice ≤ 0.3.2+2` release for Web/macOS.

### Android

**Package Information:**
> minSdkVersion: 26
> compileSdkVersion: 34

**Gradle:**
> gradle-wrapper: 8.2.1-all

**Permissions:**
* `android.permission.FOREGROUND_SERVICE` — required for foreground audio services on Android 10+.
* `android.permission.RECORD_AUDIO` — microphone for voice calls.
* `android.permission.READ_PHONE_STATE` — reading phone state (e.g. detecting other active calls for audio focus).
* `android.permission.READ_PHONE_NUMBERS` — reading outgoing/incoming number metadata.
* `android.permission.CALL_PHONE` — placing outgoing calls.

The `flutter_twilio` Android implementation uses an **in-app calling** architecture (`TVCallManager` + `TVCallAudioService`) — it does **not** integrate with the system dialer / `ConnectionService`. As a consequence, `MANAGE_OWN_CALLS` and phone-account registration are no longer required (see `MIGRATION.md`).

### iOS

If you encounter this error
> warning: The iOS deployment target 'IPHONEOS_DEPLOYMENT_TARGET' is set to 11.0, but the range of supported deployment target versions is 13.0 to 18.x.99. (in target 'ABCD' from project 'Pods')

To resolve this:
- open XCode
- browse to your Pods project (left `Project Navigator` drawer, select `Pods` project (there is `Pods` or `Runner`, expand and select `Pods` folder)
- for each pod with the above issue, select the `pod` > then select the `General` tab > and set `Minimum Deployments` to at least `13.0`.

You may also add this to your `Podfile` to ensure you don't do this each time:
```
post_install do |installer|
  installer.pods_project.targets.each do |target|
    flutter_additional_ios_build_settings(target)

    target.build_configurations.each do |config|
      config.build_settings['IPHONEOS_DEPLOYMENT_TARGET'] = '13.0'
    end
  end
end
```

## Limitations

### Android

The in-app calling architecture means calls do not appear in the system call log / dialer. If you need the native system call UI, use an older `twilio_voice` release that still bundles the `ConnectionService` integration.
