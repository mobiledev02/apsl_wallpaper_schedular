## 0.2.4

**Bug fixes**

* **Fixed: setting wallpaper on "Both Screens" always failed.**
  Many Android OEM implementations (Samsung One UI, Xiaomi, etc.) do not
  reliably honour the combined `FLAG_SYSTEM | FLAG_LOCK` bitmask when passed
  as a single `WallpaperManager.setStream()` call, causing it to silently
  fail. The wallpaper is now applied via two separate calls — one for the
  Home Screen and one for the Lock Screen — which works correctly across all
  tested devices. Individual Home Screen and Lock Screen targets are unchanged.

---

## 0.2.3

**Bug fixes**

* **Fixed: `ClientException: connection closed while receiving data` not retried.**
  Added `http.ClientException` to the retry-eligible exceptions in the image
  download logic. Previously, if the server dropped the connection mid-transfer,
  the error propagated immediately with no retry. Now it retries up to 2 times
  (with a 5-second pause between attempts), consistent with how timeouts and
  HTTP 5xx errors are handled.

---

## 0.2.2

**Bug fixes & reliability improvements**

* **Fixed: wallpaper stops updating after app is killed and reopened.**
  Added `DartPluginRegistrant.ensureInitialized()` in the background alarm
  callback. Without it, Dart-side plugin registrations (`SharedPreferences`,
  `path_provider`) never ran when the app process was dead, causing the
  callback to exit silently with no wallpaper update.

* **Fixed: wrong wallpaper set when multiple schedules fire at the same time.**
  Each alarm now downloads to its own isolated cache file
  (`apsl_wallpaper_cache_<alarmId>.png`) instead of a single shared file.
  Previously the last download always overwrote earlier ones, so only one
  schedule's image was ever applied.

* **Fixed: alarm chain could skip a day near midnight.**
  `DateTime.now()` is now captured as the very first line of the callback,
  before any `await`. Previously it was captured after a potentially slow
  image download, which could drift past midnight and schedule the next alarm
  two days ahead instead of one.

* **Fixed: slow or unreachable server could permanently break the alarm chain.**
  Added a 30-second timeout on every image download. Previously an unresponsive
  server caused the background isolate to hang indefinitely, blocking the
  self-reschedule step that maintains the daily chain.

* **Fixed: uncaught exception in self-reschedule permanently broke the alarm chain.**
  The `AndroidAlarmManager.oneShotAt` call is now wrapped in its own
  `try-catch`. Any failure is recorded in `lastError` and the chain survives.

* **Fixed: JSON corruption silently wiped all schedules.**
  `ScheduleStorage` now writes the current valid snapshot as a backup key
  before every save. On next load, if the primary entry is corrupt, it
  automatically recovers from the backup instead of returning an empty list.

* **Fixed: invalid image URLs only discovered at alarm fire time (hours later).**
  `createSchedule` and `updateSchedule` now validate the URL immediately —
  must be non-empty and start with `http://` or `https://`. A clear error is
  returned at creation time instead of a silent failure during the background
  alarm callback.

**New features**

* **Retry on server errors.** The image download now retries up to 2 times
  (with a 5-second pause between attempts) when the server returns an HTTP
  5xx error or the request times out. 4xx errors (bad URL, not found) are not
  retried. This makes background updates resilient to transient server issues.

* **Stagger for same-time schedules.** Each alarm callback now waits
  `(alarmId % 10) × 2` seconds (0–18 s) before making its HTTP request.
  When multiple schedules are set to the same time, their requests are spread
  out so the image server never receives simultaneous hits, preventing the
  rate-limiting HTTP 500 errors that caused one of every two same-time
  schedules to fail.

* **Cache cleanup.** The per-alarm image cache file is always deleted after
  `setWallpaper` completes (success or failure), preventing stale files from
  accumulating in the app's documents directory.

---

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
