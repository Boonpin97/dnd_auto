# Auto DND

Auto DND is a Flutter app with an Android Kotlin host layer for Google Pixel devices. It watches the current foreground app through `UsageStatsManager` and automatically enables Do Not Disturb when a selected trigger app is active.

## Architecture

- `lib/main.dart`: Material 3 Flutter UI, trigger app picker, permission prompts, and Android method-channel bridge.
- `android/app/src/main/kotlin/com/example/dnd_auto/MainActivity.kt`: Flutter method-channel entrypoint.
- `android/app/src/main/kotlin/com/example/dnd_auto/MonitorService.kt`: foreground service that polls the foreground app every second.
- `android/app/src/main/kotlin/com/example/dnd_auto/DndManager.kt`: wraps `NotificationManager` DND control.
- `android/app/src/main/kotlin/com/example/dnd_auto/PrefsManager.kt`: stores selected packages, service state, and DND ownership.
- `android/app/src/main/kotlin/com/example/dnd_auto/BootReceiver.kt`: restarts monitoring after device boot when previously enabled.

## Required Android Permissions

The app declares:

- `FOREGROUND_SERVICE`
- `FOREGROUND_SERVICE_SPECIAL_USE`
- `PACKAGE_USAGE_STATS`
- `ACCESS_NOTIFICATION_POLICY`
- `RECEIVE_BOOT_COMPLETED`
- `REQUEST_IGNORE_BATTERY_OPTIMIZATIONS`

The user must manually grant:

1. Usage access: `Settings > Privacy > Permission manager > Usage access`
2. Do Not Disturb access: `Settings > Apps > Special app access > Do Not Disturb access`
3. Battery optimization exclusion: recommended for service reliability

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
3. Open the app and grant Usage Access and DND Access.
4. Add one or more trigger apps and enable the monitoring service.
