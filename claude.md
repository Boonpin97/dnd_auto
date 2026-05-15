# Claude Notes

## Project Intent

Build an Android-first Auto DND app for Pixel devices. The app should enable Do Not Disturb when a configured app is in the foreground and disable it when leaving that app, without overriding user-managed DND state.

## Implementation Shape

- Keep Flutter as the product UI surface.
- Keep Android-specific behavior in Kotlin under `android/app/src/main/kotlin/com/example/dnd_auto/`.
- Use a single method channel, `auto_dnd/methods`, as the bridge between Flutter and Android.

## Current Architecture

- `lib/main.dart`
  - Material 3 dashboard
  - permission CTA cards
  - app picker route
  - periodic status refresh from Android
- `MainActivity.kt`
  - handles method-channel calls
  - opens Android settings screens
  - starts and stops the monitor service
  - returns installed apps and current status
- `MonitorService.kt`
  - foreground service with persistent notification
  - polls `UsageStatsManager` every 1000ms
  - enables DND only when needed
  - disables DND only if this app turned it on
- `PrefsManager.kt`
  - selected packages
  - service enabled flag
  - DND ownership flag
  - last foreground package
  - paused reason

## Behavior Constraints

- Never mark `dndEnabledByUs` true unless the app actually enabled DND.
- If permissions are revoked mid-session, pause monitoring and clear app-owned DND.
- Remove uninstalled trigger apps from preferences when detected.
- Keep the service `START_STICKY` and restart it after boot if it was previously enabled.

## Verification Expectations

- Flutter-level checks: `dart analyze lib test`, `flutter test`
- Android host check: `android\gradlew.bat :app:compileDebugKotlin`

## Known Environment Constraint

Kotlin compilation is blocked in the current workspace until `JAVA_HOME` is set.
