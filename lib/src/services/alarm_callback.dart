// Internal — not exported from the public API.
//
// This file MUST be imported (directly or transitively) by the host app's
// build so that @pragma('vm:entry-point') is honoured by the tree shaker.
// ApslWallpaperScheduler.initialize() satisfies this requirement.

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
  // Initialise Flutter binding so plugin MethodChannels work in this isolate.
  WidgetsFlutterBinding.ensureInitialized();

  // Look up the schedule that owns this alarm.
  final record = await ScheduleStorage.findByAlarmId(alarmId);
  if (record == null || !record.isActive) return;

  // Perform the wallpaper update.
  try {
    await WallpaperService.downloadAndSet(record.imageUrl, record.targetValue);
    await ScheduleStorage.updateLastUpdated(record.id);
    await NotificationService.showUpdateNotification(
      notifId: alarmId,
      scheduleName: record.name,
    );
  } catch (e) {
    await ScheduleStorage.updateLastError(record.id, e.toString());
  }

  // Reschedule for the same time tomorrow so the daily chain continues.
  final now = DateTime.now();
  final next = DateTime(now.year, now.month, now.day, record.hour, record.minute)
      .add(const Duration(days: 1));
  await AndroidAlarmManager.oneShotAt(
    next,
    alarmId,
    apslAlarmCallback,
    exact: true,
    wakeup: true,
    allowWhileIdle: true,
    rescheduleOnReboot: true,
  );
}
