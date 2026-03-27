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
