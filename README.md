# apsl_wallpaper_scheduler

[![pub.dev](https://img.shields.io/pub/v/apsl_wallpaper_scheduler.svg)](https://pub.dev/packages/apsl_wallpaper_scheduler)
[![GitHub](https://img.shields.io/badge/GitHub-mobiledev02%2Fapsl__wallpaper__schedular-blue?logo=github)](https://github.com/mobiledev02/apsl_wallpaper_schedular)

A Flutter package for scheduling automatic daily wallpaper updates on **Android**.

Download an image from any URL and set it as the Home Screen, Lock Screen, or Both at an exact time every day — even when the app is closed or the device reboots.

> **Android only.** iOS does not expose a public API for setting wallpapers programmatically.

---

## Features

- Schedule multiple independent wallpaper updates at different times
- Targets: Home Screen, Lock Screen, or Both
- Uses Android's `setExactAndAllowWhileIdle` — truly exact timing (not the inexact `setRepeating`)
- Survives app kill and device reboots (`rescheduleOnReboot: true`)
- Stores all schedules in `SharedPreferences` — persists across launches
- Shows a local notification after each successful update
- Full CRUD: create, read, update, delete, start, stop
- Permission checks return plain booleans — your app controls all dialogs

---

## Platform Support

| Android | iOS |
|---------|-----|
| ✅ API 21+ | ❌ Not supported |

---

## Installation

Add to your `pubspec.yaml`:

```yaml
dependencies:
  apsl_wallpaper_scheduler: ^0.1.0
```

---

## Android Setup

### 1. `android/app/src/main/AndroidManifest.xml`

Add inside `<manifest>`:

```xml
<uses-permission android:name="android.permission.INTERNET"/>
<uses-permission android:name="android.permission.SET_WALLPAPER"/>
<uses-permission android:name="android.permission.SET_WALLPAPER_HINTS"/>
<uses-permission android:name="android.permission.RECEIVE_BOOT_COMPLETED"/>
<uses-permission android:name="android.permission.FOREGROUND_SERVICE"/>
<uses-permission android:name="android.permission.POST_NOTIFICATIONS"/>
<uses-permission android:name="android.permission.WAKE_LOCK"/>
<uses-permission android:name="android.permission.SCHEDULE_EXACT_ALARM"/>
<uses-permission android:name="android.permission.USE_EXACT_ALARM"/>
<uses-permission android:name="android.permission.REQUEST_IGNORE_BATTERY_OPTIMIZATIONS"/>
```

Add inside `<application>`:

```xml
<service
    android:name="dev.fluttercommunity.plus.androidalarmmanager.AlarmService"
    android:permission="android.permission.BIND_JOB_SERVICE"
    android:exported="false"/>
<receiver
    android:name="dev.fluttercommunity.plus.androidalarmmanager.AlarmBroadcastReceiver"
    android:exported="false"/>
<receiver
    android:name="dev.fluttercommunity.plus.androidalarmmanager.RebootBroadcastReceiver"
    android:enabled="false"
    android:exported="false">
    <intent-filter>
        <action android:name="android.intent.action.BOOT_COMPLETED"/>
    </intent-filter>
</receiver>
```

### 2. `android/app/build.gradle.kts`

Enable core library desugaring (required by `flutter_local_notifications`):

```kotlin
android {
    compileOptions {
        isCoreLibraryDesugaringEnabled = true
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }
    defaultConfig {
        minSdk = 21   // minimum required
    }
}

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
}
```

---

## Usage

### Initialize (once in `main()`)

```dart
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await ApslWallpaperScheduler.initialize();
  runApp(const MyApp());
}
```

---

## Permissions

The package checks permissions internally and surfaces the results as plain
booleans. **Your app is fully responsible for showing dialogs** — the package
never shows UI of its own.

Two permissions are required for reliable alarm delivery:

| Permission | Why needed |
|---|---|
| `SCHEDULE_EXACT_ALARM` | Android 12+ requires explicit permission for exact alarms. |
| Battery optimisation exemption | Without it, aggressive OEM battery savers (Samsung, Xiaomi, OnePlus, Realme…) kill background alarms even when the alarm permission is granted. |

### Proactive check — show dialogs before scheduling

The recommended pattern: check what is missing at app start, show your own
rationale dialogs, then request each permission.

```dart
Future<void> _ensurePermissions(BuildContext context) async {
  final perms = await ApslWallpaperScheduler.checkPermissions();

  if (!perms.hasExactAlarm) {
    // Show YOUR rationale dialog first
    final proceed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Alarm permission needed'),
        content: const Text(
          'To update your wallpaper at the exact time you chose, '
          'this app needs the "Alarms & Reminders" permission.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Not now'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Allow'),
          ),
        ],
      ),
    );
    if (proceed == true) {
      await ApslWallpaperScheduler.requestExactAlarmPermission();
    }
  }

  if (!perms.hasBatteryExemption) {
    // Show YOUR rationale dialog first
    final proceed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Background activity needed'),
        content: const Text(
          'To keep wallpapers updating while the app is closed, '
          'please disable battery optimisation for this app.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Skip'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Allow'),
          ),
        ],
      ),
    );
    if (proceed == true) {
      await ApslWallpaperScheduler.requestBatteryOptimizationExemption();
    }
  }
}
```

### Reactive check — handle denied permissions from a result

Every scheduling method (`createSchedule`, `updateSchedule`, `startSchedule`)
returns a `ScheduleResult`. When the failure is caused by a missing permission,
`result.requiredPermissions` is non-null so you can react without a separate
`checkPermissions()` call.

```dart
final result = await ApslWallpaperScheduler.createSchedule(config);

if (!result.isSuccess) {
  final perms = result.requiredPermissions;

  if (perms != null) {
    // Permission-related failure — ask the user to grant what is missing.
    if (!perms.hasExactAlarm) {
      final proceed = await showDialog<bool>(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('Alarm permission denied'),
          content: const Text(
            'The schedule could not be activated because the '
            '"Alarms & Reminders" permission is not granted.\n\n'
            'Open Settings → Apps → [Your App] → Alarms & Reminders '
            'and enable it, then try again.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Open Settings'),
            ),
          ],
        ),
      );
      if (proceed == true) {
        await ApslWallpaperScheduler.requestExactAlarmPermission();
      }
    }

    if (!perms.hasBatteryExemption) {
      final proceed = await showDialog<bool>(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('Battery optimisation active'),
          content: const Text(
            'The alarm may be suppressed by the battery saver on your device.\n\n'
            'Tap Allow to disable battery optimisation for this app so '
            'wallpapers update reliably in the background.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Skip'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Allow'),
            ),
          ],
        ),
      );
      if (proceed == true) {
        await ApslWallpaperScheduler.requestBatteryOptimizationExemption();
      }
    }
  } else {
    // Non-permission failure (e.g. network error in a different context)
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(result.error ?? 'Unknown error')),
    );
  }
}
```

### Permission status at a glance

```dart
final perms = await ApslWallpaperScheduler.checkPermissions();

print(perms.hasExactAlarm);      // true / false
print(perms.hasBatteryExemption); // true / false
print(perms.isFullyGranted);     // true only when both are granted
```

---

## Schedule Operations

### Create a schedule

```dart
final result = await ApslWallpaperScheduler.createSchedule(
  WallpaperScheduleConfig(
    name: 'Morning Wallpaper',
    imageUrl: 'https://example.com/morning.png',
    time: const TimeOfDay(hour: 8, minute: 0),
    target: WallpaperTarget.both,      // homeScreen | lockScreen | both
    activate: true,                     // schedule alarm immediately (default)
  ),
);

if (result.isSuccess) {
  print('Created: ${result.schedule!.id}');
} else {
  print('Error: ${result.error}');
  // Check result.requiredPermissions — see Permissions section above
}
```

### Get all schedules

```dart
final schedules = await ApslWallpaperScheduler.getAllSchedules();
for (final s in schedules) {
  print('${s.name}  ${s.formattedTime}  active=${s.isActive}');
}
```

### Get a single schedule

```dart
final schedule = await ApslWallpaperScheduler.getSchedule(id);
```

### Get only active schedules

```dart
final active = await ApslWallpaperScheduler.getActiveSchedules();
```

### Update a schedule

```dart
final result = await ApslWallpaperScheduler.updateSchedule(
  id: existingScheduleId,
  config: WallpaperScheduleConfig(
    name: 'Updated Name',
    imageUrl: 'https://example.com/new_image.png',
    time: const TimeOfDay(hour: 9, minute: 30),
    target: WallpaperTarget.homeScreen,
    activate: true,
  ),
);
```

### Stop a schedule (keep but deactivate)

```dart
await ApslWallpaperScheduler.stopSchedule(scheduleId);
```

### Start a stopped schedule

```dart
final result = await ApslWallpaperScheduler.startSchedule(scheduleId);
// result.requiredPermissions is non-null if it failed due to permissions
```

### Delete a schedule

```dart
await ApslWallpaperScheduler.deleteSchedule(scheduleId);
```

### Delete all schedules

```dart
await ApslWallpaperScheduler.deleteAllSchedules();
```

---

## API Reference

### `ApslWallpaperScheduler`

| Method | Returns | Description |
|--------|---------|-------------|
| `initialize()` | `Future<void>` | Must be called once in `main()`. |
| `createSchedule(config)` | `Future<ScheduleResult>` | Creates and optionally activates a schedule. |
| `updateSchedule(id, config)` | `Future<ScheduleResult>` | Updates an existing schedule. |
| `deleteSchedule(id)` | `Future<bool>` | Deletes a schedule and cancels its alarm. |
| `deleteAllSchedules()` | `Future<bool>` | Deletes every schedule. |
| `startSchedule(id)` | `Future<ScheduleResult>` | Activates an inactive schedule. |
| `stopSchedule(id)` | `Future<bool>` | Deactivates an active schedule. |
| `getAllSchedules()` | `Future<List<WallpaperSchedule>>` | Returns all schedules. |
| `getActiveSchedules()` | `Future<List<WallpaperSchedule>>` | Returns active schedules only. |
| `getSchedule(id)` | `Future<WallpaperSchedule?>` | Returns one schedule by ID. |
| `checkPermissions()` | `Future<PermissionStatus>` | Returns current permission state — does **not** request anything. |
| `hasExactAlarmPermission()` | `Future<bool>` | Checks `SCHEDULE_EXACT_ALARM` only. |
| `isBatteryOptimizationExempt()` | `Future<bool>` | Checks battery exemption only. |
| `requestExactAlarmPermission()` | `Future<bool>` | Opens system settings for exact alarm. Call after your dialog. |
| `requestBatteryOptimizationExemption()` | `Future<void>` | Opens system battery exemption dialog. Call after your dialog. |

### `PermissionStatus`

| Property | Type | Description |
|----------|------|-------------|
| `hasExactAlarm` | `bool` | `true` if `SCHEDULE_EXACT_ALARM` is granted (or device < Android 12). |
| `hasBatteryExemption` | `bool` | `true` if the app is exempt from battery optimisation. |
| `isFullyGranted` | `bool` | `true` when both permissions are satisfied. |

### `WallpaperScheduleConfig`

| Field | Type | Default | Description |
|-------|------|---------|-------------|
| `name` | `String` | — | Display name. |
| `imageUrl` | `String` | — | Direct URL to a PNG/JPG image. |
| `time` | `TimeOfDay` | — | Daily trigger time. |
| `target` | `WallpaperTarget` | `both` | Which screen(s) to update. |
| `activate` | `bool` | `true` | Schedule alarm immediately. |

### `WallpaperTarget` enum

| Value | Description |
|-------|-------------|
| `WallpaperTarget.homeScreen` | Home Screen only |
| `WallpaperTarget.lockScreen` | Lock Screen only |
| `WallpaperTarget.both` | Both screens |

### `WallpaperSchedule` (read-only model)

| Property | Type | Description |
|----------|------|-------------|
| `id` | `String` | Unique identifier. |
| `name` | `String` | Display name. |
| `imageUrl` | `String` | Image source URL. |
| `hour` / `minute` | `int` | Trigger time components. |
| `time` | `TimeOfDay` | Trigger time as `TimeOfDay`. |
| `formattedTime` | `String` | e.g. `"8:05 AM"`. |
| `target` | `WallpaperTarget` | Target screen(s). |
| `targetLabel` | `String` | e.g. `"Both Screens"`. |
| `isActive` | `bool` | Whether the alarm is scheduled. |
| `lastUpdated` | `DateTime?` | Last successful update time. |
| `lastError` | `String?` | Last error message, if any. |

### `ScheduleResult`

| Property | Type | Description |
|----------|------|-------------|
| `isSuccess` | `bool` | `true` on success. |
| `schedule` | `WallpaperSchedule?` | The schedule (non-null on success). |
| `error` | `String?` | Error message (non-null on failure). |
| `requiredPermissions` | `PermissionStatus?` | Non-null when failure was caused by a missing permission. |

---

## How it works

1. **Exact alarm** — uses `AlarmManager.setExactAndAllowWhileIdle` (not `setRepeating` which is inexact since Android 4.4).
2. **Self-rescheduling chain** — after each run the callback registers the next day's alarm. This is the only reliable pattern for exact daily scheduling.
3. **Reboot resilience** — `rescheduleOnReboot: true` re-registers the alarm after device restart.
4. **Battery optimisation** — requesting exemption prevents aggressive OEM battery savers (Samsung OneUI, MIUI, ColorOS…) from suppressing the alarm.

---

## Troubleshooting

| Symptom | Fix |
|---------|-----|
| Alarm never fires | Grant `SCHEDULE_EXACT_ALARM` and request battery-optimisation exemption. |
| Works on stock Android but not Samsung/Xiaomi | Request battery-optimisation exemption — these OEMs kill background processes aggressively. |
| `result.requiredPermissions` is non-null after `createSchedule` | Check `hasExactAlarm` and `hasBatteryExemption` and handle each with a dialog. |
| Build fails with `Unresolved reference 'shim'` | You have an old `workmanager` version. Remove it. |
| `isCoreLibraryDesugaringEnabled` error | Add the desugaring config to `build.gradle.kts` as shown in setup. |
| `ApslWallpaperScheduler is not initialised` | Call `ApslWallpaperScheduler.initialize()` in `main()` before `runApp`. |
