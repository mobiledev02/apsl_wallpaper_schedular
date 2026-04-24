// Internal — not exported from the public API.
//
// This file MUST be imported (directly or transitively) by the host app's
// build so that @pragma('vm:entry-point') is honoured by the tree shaker.
// ApslWallpaperScheduler.initialize() satisfies this requirement.

import 'dart:ui' show DartPluginRegistrant;

import 'package:android_alarm_manager_plus/android_alarm_manager_plus.dart';
import 'package:flutter/widgets.dart';
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

  // Stagger each alarm by (alarmId % 10) * 2 seconds (0–18 s).
  // When multiple schedules fire at the same time, this spreads their HTTP
  // requests so they never hit the image server simultaneously, preventing
  // the server from rate-limiting and returning HTTP 500 on the second request.
  await Future.delayed(Duration(seconds: (alarmId % 10) * 2));

  // Look up the schedule that owns this alarm.
  final record = await ScheduleStorage.findByAlarmId(alarmId);
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
        record.imageUrl, record.targetValue, record.alarmId);
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

  // Reschedule for the same time tomorrow so the daily chain continues.
  // Uses `now` captured before the download to avoid midnight-drift bugs.
  final next =
      DateTime(now.year, now.month, now.day, record.hour, record.minute)
          .add(const Duration(days: 1));
  try {
    final scheduled = await AndroidAlarmManager.oneShotAt(
      next,
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
