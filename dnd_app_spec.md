# Android Auto-DND App — Claude Code Spec

## Project Overview

Build an Android app (Kotlin) for Google Pixel that automatically enables Do Not Disturb (DND) when a specified app is in the foreground, and disables DND when the user leaves that app.

---

## Goals

- Let the user pick one or more apps that should trigger DND
- Run a background service that monitors the foreground app
- Toggle DND on/off automatically based on which app is active
- Survive battery optimization (run as a persistent foreground service)

---

## Tech Stack

- **Language:** Kotlin
- **Min SDK:** 26 (Android 8.0)
- **Target SDK:** 34 (Android 14)
- **Build system:** Gradle (Kotlin DSL)
- **IDE:** Android Studio

---

## Required Permissions

Add to `AndroidManifest.xml`:

```xml
<uses-permission android:name="android.permission.FOREGROUND_SERVICE" />
<uses-permission android:name="android.permission.FOREGROUND_SERVICE_SPECIAL_USE" />
<uses-permission android:name="android.permission.PACKAGE_USAGE_STATS" tools:ignore="ProtectedPermissions" />
<uses-permission android:name="android.permission.ACCESS_NOTIFICATION_POLICY" />
```

Both of these permissions require the user to grant them manually in Settings:
- **Usage Stats:** `Settings → Privacy → Permission manager → Usage access`
- **DND Access:** `Settings → Apps → Special app access → Do Not Disturb access`

---

## App Structure

```
app/
└── src/main/
    ├── AndroidManifest.xml
    └── java/com/example/autodnd/
        ├── MainActivity.kt          # UI, permission prompts, app picker
        ├── AppPickerActivity.kt     # List of installed apps to select triggers
        ├── MonitorService.kt        # Foreground service, polls foreground app
        ├── DndManager.kt           # Wraps NotificationManager DND logic
        ├── PrefsManager.kt         # SharedPreferences: stores selected apps
        └── BootReceiver.kt         # Restart service on device boot
```

---

## Feature Spec

### 1. MainActivity
- On launch, check if both permissions are granted
- If not, show explanation and deep-link buttons to grant each permission:
  - Button: "Grant Usage Access" → opens `Settings.ACTION_USAGE_ACCESS_SETTINGS`
  - Button: "Grant DND Access" → opens `Settings.ACTION_NOTIFICATION_POLICY_ACCESS_SETTINGS`
- Once both are granted, show:
  - List of currently selected trigger apps (with app icons)
  - Button: "Add App" → opens AppPickerActivity
  - Toggle: "Service enabled" (starts/stops MonitorService)
  - Status indicator: current foreground app name + DND state

### 2. AppPickerActivity
- Show a scrollable list of all installed, launchable apps (icon + name)
- Allow multi-select
- Save selected package names to SharedPreferences via PrefsManager
- Remove app from list with a swipe or delete button

### 3. MonitorService (Foreground Service)
- Run as a foreground service with a persistent notification (required by Android)
- Every **1000ms**, use `UsageStatsManager` to get the current foreground app:

```kotlin
val usageStatsManager = getSystemService(USAGE_STATS_SERVICE) as UsageStatsManager
val time = System.currentTimeMillis()
val stats = usageStatsManager.queryUsageStats(
    UsageStatsManager.INTERVAL_DAILY, time - 5000, time
)
val foregroundApp = stats?.maxByOrNull { it.lastTimeUsed }?.packageName
```

- Compare foregroundApp against the saved trigger app list
- If match → enable DND via DndManager
- If no match and DND was enabled by this app → disable DND
- Track whether **this app** turned DND on (don't disable DND if user set it manually)

### 4. DndManager
- Use `NotificationManager` to set DND:

```kotlin
val notificationManager = context.getSystemService(NotificationManager::class.java)

fun enableDnd() {
    notificationManager.setInterruptionFilter(
        NotificationManager.INTERRUPTION_FILTER_NONE
    )
}

fun disableDnd() {
    notificationManager.setInterruptionFilter(
        NotificationManager.INTERRUPTION_FILTER_ALL
    )
}

fun isDndEnabled(): Boolean {
    return notificationManager.currentInterruptionFilter !=
        NotificationManager.INTERRUPTION_FILTER_ALL
}
```

### 5. PrefsManager
- Use `SharedPreferences` to persist:
  - `Set<String>` of trigger app package names
  - `Boolean` serviceEnabled
  - `Boolean` dndEnabledByUs (to avoid interfering with manual DND)

### 6. BootReceiver
- `BroadcastReceiver` listening for `ACTION_BOOT_COMPLETED`
- If service was enabled before reboot, restart MonitorService

---

## Foreground Service Notification

The service must show a persistent notification to stay alive:

```kotlin
val notification = NotificationCompat.Builder(this, CHANNEL_ID)
    .setContentTitle("Auto DND Active")
    .setContentText("Monitoring foreground app...")
    .setSmallIcon(R.drawable.ic_dnd)
    .build()

startForeground(1, notification)
```

Create a `NotificationChannel` in `onCreate` (required for Android 8+).

---

## Battery Optimization

To prevent Android from killing the service:
- Guide the user to exempt the app from battery optimization:
  `Settings → Battery → Battery optimization → [Your App] → Don't optimize`
- Request via:

```kotlin
val intent = Intent(Settings.ACTION_REQUEST_IGNORE_BATTERY_OPTIMIZATIONS)
intent.data = Uri.parse("package:$packageName")
startActivity(intent)
```

---

## UI Design Guidelines

- Simple, clean Material 3 design
- Dark mode support
- Main screen fits on one scroll — no complex navigation needed
- Use `MaterialCardView` for the trigger apps list
- Color-coded status chip: green = DND off, red = DND on

---

## Edge Cases to Handle

| Case | Behavior |
|------|----------|
| User manually enables DND | Don't disable it when leaving trigger app |
| No trigger apps selected | Service runs but does nothing |
| Permission revoked mid-session | Show warning notification, pause monitoring |
| Trigger app is uninstalled | Silently remove from list on next launch |
| Screen off / device locked | Continue monitoring (foreground service) |

---

## Deliverables

1. Full Kotlin source for all files listed in App Structure
2. `AndroidManifest.xml` with all permissions and service/receiver declarations
3. `build.gradle.kts` (app level) with correct dependencies
4. Basic `res/layout/` XML files for MainActivity and AppPickerActivity
5. A `README.md` with setup and sideloading instructions for Pixel

---

## Notes for Claude Code

- Do not use deprecated `ActivityManager.getRunningTasks()` for foreground detection — use `UsageStatsManager` instead
- The polling interval can be configurable (default 1000ms)
- Prefer `ViewModel` + `StateFlow` for UI state if time permits, but plain activity logic is acceptable
- Target physical Pixel device sideloading, not emulator-only
