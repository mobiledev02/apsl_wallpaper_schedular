## 0.2.1

* `requestBatteryOptimizationExemption()` now returns `Future<bool>` instead of `Future<void>`.
  * Returns `true` if the battery-optimisation exemption is (or was already) granted, `false` if the user declined.
  * Allows callers to react immediately to the user's decision without a follow-up `checkPermissions()` call.

## 0.2.0

* Bumped dependency versions for compatibility with modern Flutter apps:
  * `flutter_local_notifications` upgraded from `^17.2.2` to `^19.5.0`.
  * `permission_handler` upgraded from `^11.3.1` to `^12.0.0+1`.
  * `shared_preferences` upgraded from `^2.2.3` to `^2.5.3`.
  * `path_provider` upgraded from `^2.1.2` to `^2.1.5`.
  * `http` upgraded from `^1.2.1` to `^1.2.2`.

## 0.1.0

* Initial release.
* `createSchedule` — create and activate a daily wallpaper schedule.
* `updateSchedule` — edit an existing schedule.
* `deleteSchedule` / `deleteAllSchedules` — remove schedules.
* `startSchedule` / `stopSchedule` — toggle a schedule on/off.
* `getAllSchedules` / `getActiveSchedules` / `getSchedule` — query schedules.
* Permission helpers: `requestExactAlarmPermission`, `requestBatteryOptimizationExemption`.
* Uses `setExactAndAllowWhileIdle` for truly exact daily alarms.
* Survives app kill and device reboots via `rescheduleOnReboot`.
