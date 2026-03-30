// Internal — not exported from the public API.

import 'dart:io';
import 'package:android_alarm_manager_plus/android_alarm_manager_plus.dart';
import 'package:permission_handler/permission_handler.dart';
import '../models/schedule_record.dart';
import 'alarm_callback.dart';

class AlarmService {
  /// Returns the next [DateTime] for [hour]:[minute].
  /// If the time has already passed today, returns the same time tomorrow.
  static DateTime nextAlarmTime(int hour, int minute) {
    final now = DateTime.now();
    var next = DateTime(now.year, now.month, now.day, hour, minute);
    if (!next.isAfter(now)) next = next.add(const Duration(days: 1));
    return next;
  }

  /// Schedules a one-shot exact alarm for [record].
  ///
  /// Uses [setExactAndAllowWhileIdle] (via `exact + allowWhileIdle`) so the
  /// alarm fires at precisely the configured time even during Doze mode.
  /// The callback self-reschedules for the next day after each run.
  ///
  /// Returns `true` on success, `false` if the platform rejected the alarm
  /// (typically a missing SCHEDULE_EXACT_ALARM permission on Android 12+).
  static Future<bool> schedule(ScheduleRecord record) {
    return AndroidAlarmManager.oneShotAt(
      nextAlarmTime(record.hour, record.minute),
      record.alarmId,
      apslAlarmCallback,
      exact: true,
      wakeup: true,
      allowWhileIdle: true,
      rescheduleOnReboot: true,
    );
  }

  /// Cancels the alarm for [alarmId].
  static Future<void> cancel(int alarmId) =>
      AndroidAlarmManager.cancel(alarmId);

  // ── Permissions ─────────────────────────────────────────────────────────────

  /// Returns `true` if [SCHEDULE_EXACT_ALARM] is granted (or not required).
  static Future<bool> hasExactAlarmPermission() async {
    if (!Platform.isAndroid) return true;
    return (await Permission.scheduleExactAlarm.status).isGranted;
  }

  /// Returns `true` if the app is exempt from battery optimisation.
  static Future<bool> isBatteryOptimizationExempt() async {
    if (!Platform.isAndroid) return true;
    return (await Permission.ignoreBatteryOptimizations.status).isGranted;
  }

  /// Requests [SCHEDULE_EXACT_ALARM] permission.
  /// Returns `true` if the permission is (or was already) granted.
  static Future<bool> requestExactAlarmPermission() async {
    if (!Platform.isAndroid) return true;
    final status = await Permission.scheduleExactAlarm.status;
    if (status.isGranted) return true;
    return (await Permission.scheduleExactAlarm.request()).isGranted;
  }

  /// Requests battery-optimisation exemption (shows system dialog).
  /// Without this, aggressive OEM battery savers (Samsung, Xiaomi, etc.)
  /// may suppress alarms even when [SCHEDULE_EXACT_ALARM] is granted.
  static Future<bool> requestBatteryExemption() async {
    if (!Platform.isAndroid) return true;
    final status = await Permission.ignoreBatteryOptimizations.status;
    if (status.isGranted) return true;
    return (await Permission.ignoreBatteryOptimizations.request()).isGranted;
  }
}
