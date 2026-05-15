# Agents

## Primary Agent Responsibilities

### UI Agent

- Own `lib/main.dart`
- Maintain a single-screen dashboard plus picker flow
- Keep the UI Android-focused and operational without extra navigation layers

### Android Host Agent

- Own `android/app/src/main/kotlin/com/example/dnd_auto/`
- Preserve method-channel compatibility with Flutter
- Keep settings intents, preference handling, and service lifecycle coherent

### Service Agent

- Own `MonitorService.kt`, `DndManager.kt`, and `BootReceiver.kt`
- Protect the manual-DND edge case
- Keep polling logic simple, deterministic, and easy to reason about

### Build and Release Agent

- Own `AndroidManifest.xml`, `android/app/build.gradle.kts`, and `README.md`
- Keep SDK targets aligned with the spec: min SDK 26, target SDK 34
- Document any extra environment prerequisites such as `JAVA_HOME`

## Operating Rules

- Do not replace the Flutter shell with a native-only Android app.
- Do not use deprecated foreground-task detection APIs.
- Prefer incremental changes to the existing method-channel contract over ad hoc new bridges.
- Any change to DND ownership behavior must preserve: manual DND must not be disabled by this app.

## Handoff Checklist

- Run `dart analyze lib test`
- Run `flutter test`
- Run `android\gradlew.bat :app:compileDebugKotlin`
- Confirm manifest permissions and foreground service declarations still match the feature set
