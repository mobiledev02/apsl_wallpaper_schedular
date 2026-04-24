# Known Limitations & Bugs (Resolvable)

All issues below are fixable in Dart/Flutter code. File paths and line numbers reference the current codebase.

---

## 1. Stagger Collision for AlarmIds Divisible by 10

**File:** `lib/src/services/alarm_callback.dart:37-41`

**Problem:** Delay is computed as `(alarmId % 10) * 2`. Any alarmId that is a multiple of 10 (e.g., 10, 20, 30, 100) always maps to 0 seconds delay. If multiple schedules share such IDs and fire at the same time, they all hit the network and wallpaper API simultaneously — no staggering at all.

**Fix:** Use a better hash:
```dart
final stagger = ((alarmId % 10) + (alarmId ~/ 10) % 5) * 2;
await Future.delayed(Duration(seconds: stagger));
```

---

## 2. Alarm ID Counter Overflow

**File:** `lib/src/storage/schedule_storage.dart:89-95`

**Problem:** Counter starts at 100 and increments by 1 on every new schedule. No upper-bound guard. After ~2 billion schedules are created (or if the counter is corrupted to a large value), it overflows. On Android, AlarmManager uses int32 IDs — overflow causes collisions or silent failures.

**Fix:**
```dart
final next = (current >= 2000000000) ? 100 : current + 1;
```

---

## 3. Orphaned Alarm After Mid-Fire Deletion

**File:** `lib/src/services/alarm_callback.dart:44`

**Problem:** If a schedule is deleted while its alarm callback is executing, `loadAll()` returns an empty record for that ID. The callback exits silently — but the reschedule at the end (`lines 97-109`) still runs before the null check stops it (in some flows), registering a ghost alarm in AlarmManager. The next day that alarm fires, finds no record, and silently exits again — but keeps re-registering itself.

**Fix:** Move the record existence check *before* the reschedule call to ensure no reschedule happens when the record is gone.

---

## 4. Cache File Deletion Failure Silently Ignored

**File:** `lib/src/services/wallpaper_service.dart:143`

**Problem:**
```dart
await file.delete().catchError((_) => file);
```
Any deletion error (permission denied, file in use, full storage) is swallowed. Stale image files accumulate silently on disk.

**Fix:** Log the error explicitly:
```dart
await file.delete().catchError((e) {
  debugPrint('[WallpaperService] Failed to delete cache: $e');
  return file;
});
```

---

## 5. No Content-Type Validation on Downloaded Image

**File:** `lib/src/services/wallpaper_service.dart:54-62`

**Problem:** The HTTP response is checked for `statusCode == 200` only. If the URL returns HTML or JSON (still 200 OK), the response bytes are written to disk and passed to `setWallpaper()`, which fails with a cryptic native error about invalid image data.

**Fix:** Check the `Content-Type` header before writing:
```dart
final contentType = response.headers['content-type'] ?? '';
if (!contentType.startsWith('image/')) {
  throw Exception('Invalid content-type: $contentType');
}
```

---

## 6. No Image Size Limit (OOM Risk)

**File:** `lib/src/services/wallpaper_service.dart:54-56`

**Problem:** `response.bodyBytes` loads the entire image into Dart heap memory. A large image (50MB+) can exhaust the isolate's memory, crashing the alarm callback silently with no error logged.

**Fix:** Check `Content-Length` header before downloading:
```dart
final contentLength = int.tryParse(response.headers['content-length'] ?? '');
const maxBytes = 20 * 1024 * 1024; // 20 MB
if (contentLength != null && contentLength > maxBytes) {
  throw Exception('Image too large: $contentLength bytes');
}
```

---

## 7. URL Reachability Not Checked at Schedule Creation

**File:** `lib/src/apsl_wallpaper_scheduler.dart:329-336`

**Problem:** URL is validated for format only (`http://` or `https://` prefix). A 401, 403, rate-limited, or expired URL is only discovered at alarm fire time — potentially days after the schedule was created.

**Fix:** Perform a `HEAD` request at schedule creation time to validate reachability:
```dart
final response = await http.head(Uri.parse(imageUrl));
if (response.statusCode != 200) {
  throw Exception('URL returned ${response.statusCode}');
}
```
*(Can be made optional via a `validateUrl` flag to avoid breaking existing integrations.)*

---

## 8. Retry Count and Delay Hardcoded

**File:** `lib/src/services/wallpaper_service.dart:26-27`

**Problem:** `maxRetries = 2` and `retryDelay = Duration(seconds: 20)` are hardcoded constants. There is no API to configure these per-schedule. Slow image servers can't get more retries; fast servers waste 20s between attempts.

**Fix:** Expose these as optional parameters in `ScheduleConfig` or the top-level `addSchedule()` method.

---

## 9. Invalid hour/minute Values Not Validated

**File:** `lib/src/models/schedule_record.dart:84-95`

**Problem:** `fromJson()` uses default values (`hour: 8, minute: 0`) but does not validate the range. A corrupted SharedPreferences entry with `hour: 25` or `minute: 99` is silently accepted. `DateTime(y, m, d, 25, 99)` wraps to the next day, causing the alarm to fire at an unexpected time.

**Fix:**
```dart
hour: (json['hour'] as int? ?? 8).clamp(0, 23),
minute: (json['minute'] as int? ?? 0).clamp(0, 59),
```

---

## 10. No Offline Backoff — Alarms Fail Every Day Indefinitely

**File:** `lib/src/services/alarm_callback.dart`

**Problem:** When the device is offline, the callback logs `NO_INTERNET`, reschedules for the next day, and repeats. There is no backoff, retry window, or catch-up logic. If the device is offline for 7 days, 7 alarm cycles fail and 7 reschedules happen — no wallpaper is ever set.

**Fix:** On `NO_INTERNET` error, attempt a short-delay retry (e.g., 30 minutes) before falling back to the next-day schedule:
```dart
// On SocketException: retry in 30 min instead of 24 hours
final retryTime = DateTime.now().add(const Duration(minutes: 30));
await AndroidAlarmManager.oneShotAt(retryTime, alarmId, apslAlarmCallback, ...);
```

---

## 11. DST / Timezone Drift in Daily Reschedule

**File:** `lib/src/services/alarm_callback.dart:97-99`

**Problem:** The next alarm time is computed in local time:
```dart
final next = DateTime(now.year, now.month, now.day, record.hour, record.minute)
    .add(const Duration(days: 1));
```
On Daylight Saving Time transitions, a time can occur twice (fall-back → fires twice) or not at all (spring-forward → skips a day). Travelling across time zones also shifts the effective fire time.

**Fix:** Compute the next occurrence in UTC and convert:
```dart
final todayLocal = DateTime.now().toLocal();
final nextLocal = DateTime(todayLocal.year, todayLocal.month,
    todayLocal.day, record.hour, record.minute)
    .add(const Duration(days: 1));
final nextUtc = nextLocal.toUtc();
```

---

## Non-Fixable Constraints (for reference)

These are OS/OEM-level and **cannot** be resolved in code:

| Constraint | Reason |
|------------|--------|
| OEM battery savers (Samsung, Xiaomi, OnePlus) blocking alarms | Proprietary system APIs, no workaround |
| Android 12+ exact alarm requires manual settings toggle | Android OS design — no dialog-based request |
| iOS not supported | Apple does not expose a wallpaper API |
| AlarmManager unavailable on some custom ROMs | ROM-level restriction |
