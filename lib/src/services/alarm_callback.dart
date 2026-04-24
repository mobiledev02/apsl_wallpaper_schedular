// Internal — not exported from the public API.
//
// This file MUST be imported (directly or transitively) by the host app's
// build so that @pragma('vm:entry-point') is honoured by the tree shaker.
// ApslWallpaperScheduler.initialize() satisfies this requirement.

import 'dart:ui' show DartPluginRegistrant;

import 'package:android_alarm_manager_plus/android_alarm_manager_plus.dart';
import 'package:flutter/widgets.dart';
import '../models/schedule_record.dart';
import '../storage/schedule_storage.dart';
import '../services/wallpaper_service.dart';
import '../services/notification_service.dart';

/// Top-level callback invoked by Android's AlarmManager in a background
/// isolate whenever a scheduled alarm fires.
///
/// Pattern: one-shot + self-reschedule (instead of `periodic`) because
/// [AlarmManager.setRepeating] has been **inexact** since Android 4.4.
/// [setExactAndAllowWhileIdle] (used when `exact + allowWhileIdle` are both
/// `true`) is the only truly exact alarm API available.
@pragma('vm:entry-point')
void apslAlarmCallback(int alarmId) async {
  // Capture time immediately — before any awaits — so the next-day reschedule
  // is computed relative to when the alarm actually fired, not after a
  // potentially slow image download that could drift past midnight.
  final now = DateTime.now();

  // Both calls are required for plugins (SharedPreferences, path_provider,
  // wallpaper_manager_flutter, etc.) to work in a background isolate when
  // the app process has been killed. Without DartPluginRegistrant the Dart-side
  // plugin registrations never run, causing SharedPreferences to return null
  // and the callback to exit silently with no wallpaper update.
  WidgetsFlutterBinding.ensureInitialized();
  DartPluginRegistrant.ensureInitialized();

  // Improved stagger: combines both digits of the alarmId so that IDs that
  // are multiples of 10 (e.g. 100, 110, 120) no longer all map to 0 seconds.
  // Spreads simultaneous alarms across 0–18 s without any two sharing the
  // same delay unless there are more than 10 concurrent schedules.
  await Future.delayed(Duration(seconds: ((alarmId % 10) + (alarmId ~/ 10) % 5) * 2));

  // Look up the schedule that owns this alarm.
  // Wrapped in try-catch: if SharedPreferences throws (storage full, corrupted
  // file, Android I/O error), we still reschedule 24 h from now so the chain
  // is preserved even though we can't set the wallpaper this cycle.
  ScheduleRecord? record;
  try {
    record = await ScheduleStorage.findByAlarmId(alarmId);
  } catch (_) {
    try {
      await AndroidAlarmManager.oneShotAt(
        now.add(const Duration(hours: 24)),
        alarmId,
        apslAlarmCallback,
        exact: true,
        wakeup: true,
        allowWhileIdle: true,
        rescheduleOnReboot: true,
      );
    } catch (_) {}
    return;
  }
  if (record == null || !record.isActive) return;

  // ── CORE ──────────────────────────────────────────────────────────────────
  // Isolated try-catch: ONLY the wallpaper download+set is here.
  // Notifications and storage updates are intentionally outside so that a
  // failure in any helper can never make the core appear to have failed, and
  // a helper crash can never prevent tomorrow's reschedule from running.
  bool wallpaperSuccess = false;
  Object? coreError;
  try {
    // Pass alarmId so each schedule uses its own isolated cache file,
    // preventing race conditions when multiple schedules fire at the same time.
    await WallpaperService.downloadAndSet(
      record.imageUrl,
      record.targetValue,
      record.alarmId,
      maxRetries: record.maxRetries,
      retryDelay: Duration(seconds: record.retryDelaySeconds),
    );
    wallpaperSuccess = true;
  } catch (e) {
    coreError = e;
  }

  // ── STORAGE (helper — must never affect core result) ──────────────────────
  try {
    if (wallpaperSuccess) {
      await ScheduleStorage.updateLastUpdated(record.id);
    } else {
      final timestamp = DateTime.now().toLocal().toString().substring(0, 19);
      await ScheduleStorage.updateLastError(
          record.id, '[$timestamp] ${coreError.toString()}');
    }
  } catch (_) {
    // Storage failure is non-fatal; swallow silently.
  }

  // ── NOTIFICATION (helper — must never affect core result) ─────────────────
  // A 10-second timeout guards against flutter_local_notifications'
  // initialize() hanging in the background isolate, which would block the
  // reschedule below and permanently break the daily chain.
  try {
    if (wallpaperSuccess) {
      await NotificationService.showUpdateNotification(
        notifId: alarmId,
        scheduleName: record.name,
      ).timeout(const Duration(seconds: 10));
    } else {
      await NotificationService.showFailureNotification(
        notifId: alarmId,
        scheduleName: record.name,
        reason: coreError.toString(),
      ).timeout(const Duration(seconds: 10));
    }
  } catch (_) {
    // Notification failure or timeout is non-fatal; swallow silently.
  }

  // ── RESCHEDULE ────────────────────────────────────────────────────────────
  // Re-fetch the record to guard against a deletion that happened while the
  // download or notification was running — avoids registering an orphaned
  // alarm that fires forever with no matching schedule record.
  // On storage failure, proceed conservatively: it is safer to fire one extra
  // alarm than to permanently break the chain by skipping the reschedule.
  try {
    final currentRecord = await ScheduleStorage.findByAlarmId(alarmId);
    if (currentRecord == null || !currentRecord.isActive) return;
  } catch (_) {
    // Storage read failed — assume still active and fall through to reschedule.
  }

  // Determine next fire time:
  // • Offline error → retry in 30 minutes so the wallpaper is set as soon as
  //   connectivity is restored, rather than waiting a full 24 hours.
  // • Any other outcome → schedule for the same clock time tomorrow.
  //   Uses day+1 construction (not Duration arithmetic) so the result is
  //   always the correct calendar day regardless of DST transitions.
  final bool isOffline = coreError?.toString().contains('[NO_INTERNET]') == true;
  final DateTime nextTime = isOffline
      ? DateTime.now().add(const Duration(minutes: 30))
      : DateTime(now.year, now.month, now.day + 1, record.hour, record.minute);

  try {
    final scheduled = await AndroidAlarmManager.oneShotAt(
      nextTime,
      alarmId,
      apslAlarmCallback,
      exact: true,
      wakeup: true,
      allowWhileIdle: true,
      rescheduleOnReboot: true,
    );
    if (!scheduled) {
      // oneShotAt returns false when Android rejects the alarm — most commonly
      // a missing SCHEDULE_EXACT_ALARM permission on Android 12+.
      await ScheduleStorage.updateLastError(record.id,
          'Reschedule failed: Android rejected the alarm (SCHEDULE_EXACT_ALARM permission may have been revoked)');
    }
  } catch (e) {
    // If rescheduling fails the daily chain would break permanently, so log it.
    await ScheduleStorage.updateLastError(
        record.id, 'Reschedule failed: ${e.toString()}');
  }
}
