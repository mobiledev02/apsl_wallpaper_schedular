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

  // Perform the wallpaper update.
  try {
    // Pass alarmId so each schedule uses its own isolated cache file,
    // preventing race conditions when multiple schedules fire at the same time.
    await WallpaperService.downloadAndSet(
        record.imageUrl, record.targetValue, record.alarmId);
    await ScheduleStorage.updateLastUpdated(record.id);
    await NotificationService.showUpdateNotification(
      notifId: alarmId,
      scheduleName: record.name,
    );
  } catch (e) {
    await ScheduleStorage.updateLastError(record.id, e.toString());
  }

  // Reschedule for the same time tomorrow so the daily chain continues.
  // Uses `now` captured before the download to avoid midnight-drift bugs.
  final next =
      DateTime(now.year, now.month, now.day, record.hour, record.minute)
          .add(const Duration(days: 1));
  try {
    await AndroidAlarmManager.oneShotAt(
      next,
      alarmId,
      apslAlarmCallback,
      exact: true,
      wakeup: true,
      allowWhileIdle: true,
      rescheduleOnReboot: true,
    );
  } catch (e) {
    // If rescheduling fails the daily chain would break permanently, so log it.
    await ScheduleStorage.updateLastError(
        record.id, 'Reschedule failed: ${e.toString()}');
  }
}
