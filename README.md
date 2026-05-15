# Auto Focus

Auto Focus is a Flutter app with an Android Kotlin host layer for Google Pixel devices. It watches the current foreground app through `UsageStatsManager` and shows when Android Focus Mode should be used for selected trigger apps.

Android does not expose a public SDK API that lets third-party apps toggle Digital Wellbeing Focus Mode directly. This app therefore provides monitoring, status, notifications, and a shortcut into Digital Wellbeing settings instead of silently relying on private device-specific behavior.

## Architecture

- `lib/main.dart`: Material 3 Flutter UI, trigger app picker, permission prompts, Focus Mode shortcut, and Android method-channel bridge.
- `android/app/src/main/kotlin/com/example/dnd_auto/MainActivity.kt`: Flutter method-channel entrypoint.
- `android/app/src/main/kotlin/com/example/dnd_auto/MonitorService.kt`: foreground service that polls the foreground app every second.
- `android/app/src/main/kotlin/com/example/dnd_auto/FocusModeManager.kt`: opens Digital Wellbeing settings when available, with system settings fallback.
- `android/app/src/main/kotlin/com/example/dnd_auto/PrefsManager.kt`: stores selected packages, service state, and Focus Mode recommendation state.
- `android/app/src/main/kotlin/com/example/dnd_auto/BootReceiver.kt`: restarts monitoring after device boot when previously enabled.

## Required Android Permissions

The app declares:

- `FOREGROUND_SERVICE`
- `FOREGROUND_SERVICE_SPECIAL_USE`
- `PACKAGE_USAGE_STATS`
- `RECEIVE_BOOT_COMPLETED`
- `REQUEST_IGNORE_BATTERY_OPTIMIZATIONS`

The user must manually grant:

1. Usage access: `Settings > Privacy > Permission manager > Usage access`
2. Battery optimization exclusion: recommended for service reliability
3. Digital Wellbeing Focus Mode setup: required because Android only allows the user to turn Focus Mode on or off

## Local Setup

1. Install Flutter stable and Android Studio.
2. Set `JAVA_HOME` to your JDK location.
3. Connect a Pixel device with developer mode and USB debugging enabled.
4. Run `flutter pub get`.
5. Run `flutter run`.

## Verification

These checks were completed in this workspace:

- `dart analyze lib test`
- `flutter test`

This check is still required on a machine with Java configured:

- `android\gradlew.bat :app:compileDebugKotlin`

## Sideloading

1. Build with `flutter build apk --debug` or `flutter build apk --release`.
2. Install with `adb install build\app\outputs\flutter-apk\app-debug.apk`
3. Open the app and grant Usage Access.
4. Add one or more trigger apps and enable the monitoring service.
