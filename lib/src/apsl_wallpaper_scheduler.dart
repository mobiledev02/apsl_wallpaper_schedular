import 'package:android_alarm_manager_plus/android_alarm_manager_plus.dart';
import 'models/permission_status.dart';
import 'models/schedule_config.dart';
import 'models/schedule_record.dart';
import 'models/schedule_result.dart';
import 'models/wallpaper_schedule.dart';
import 'services/alarm_callback.dart'; // ensures apslAlarmCallback is compiled in
import 'services/alarm_service.dart';
import 'services/notification_service.dart';
import 'services/wallpaper_service.dart';
import 'storage/schedule_storage.dart';

/// The main entry point for the `apsl_wallpaper_scheduler` package.
///
/// All methods are static. Call [initialize] once inside `main()` before
/// using any other method.
///
/// **Typical setup:**
/// ```dart
/// void main() async {
///   WidgetsFlutterBinding.ensureInitialized();
///   await ApslWallpaperScheduler.initialize();
///   runApp(const MyApp());
/// }
/// ```
class ApslWallpaperScheduler {
  ApslWallpaperScheduler._();

  static bool _initialized = false;

  // ── Lifecycle ──────────────────────────────────────────────────────────────

  /// Initialises the AlarmManager and notification channel.
  ///
  /// Must be called once in `main()` **after**
  /// `WidgetsFlutterBinding.ensureInitialized()` and **before** `runApp`.
  /// Safe to call multiple times — subsequent calls are no-ops.
  /// [showErrorNotifications] — when `true`, a local notification is shown
  /// whenever the daily alarm reschedule fails (e.g. permission revoked,
  /// Android rejects the alarm). Useful during development or for surfacing
  /// failures to the user so they can take corrective action.
  /// Defaults to `false`.
  static Future<void> initialize({bool showErrorNotifications = false}) async {
    if (_initialized) return;
    // Touch apslAlarmCallback so the tree shaker keeps it in the binary.
    // ignore: unnecessary_statements
    apslAlarmCallback;
    await AndroidAlarmManager.initialize();
    await NotificationService.init(showErrorNotifications: showErrorNotifications);
    _initialized = true;
  }

  // ── CRUD ──────────────────────────────────────────────────────────────────

  /// Creates a new schedule from [config].
  ///
  /// If [WallpaperScheduleConfig.activate] is `true` (default), the alarm is
  /// scheduled immediately. Returns a [ScheduleResult] with the created
  /// [WallpaperSchedule] on success, or an error on failure.
  ///
  /// When the failure is caused by a missing permission,
  /// [ScheduleResult.requiredPermissions] is non-null — use it to decide
  /// which rationale dialog(s) to show before retrying.
  static Future<ScheduleResult> createSchedule(
      WallpaperScheduleConfig config) async {
    _assertInitialized();
    final urlValidationError = _validateUrl(config.imageUrl);
    if (urlValidationError != null) return ScheduleResult.failure(urlValidationError);
    if (config.validateUrl) {
      final reachabilityError = await WallpaperService.validateUrl(config.imageUrl.trim());
      if (reachabilityError != null) return ScheduleResult.failure(reachabilityError);
    }
    try {
      final alarmId = await ScheduleStorage.nextAlarmId();
      final id = DateTime.now().millisecondsSinceEpoch.toString();

      var record = ScheduleRecord(
        id: id,
        name: config.name.trim(),
        imageUrl: config.imageUrl.trim(),
        hour: config.time.hour,
        minute: config.time.minute,
        targetValue: config.target.value,
        isActive: false,
        alarmId: alarmId,
        maxRetries: config.maxRetries,
        retryDelaySeconds: config.retryDelay.inSeconds,
      );

      if (config.activate) {
        final ok = await AlarmService.schedule(record);
        if (!ok) {
          final perms = await checkPermissions();
          return ScheduleResult.failure(
            'Alarm scheduling failed. '
            'Grant the "Alarms & Reminders" permission (SCHEDULE_EXACT_ALARM) '
            'and try again.',
            requiredPermissions: perms.isFullyGranted ? null : perms,
          );
        }
        record = record.copyWith(isActive: true);
      }

      await ScheduleStorage.upsert(record);
      return ScheduleResult.success(record.toSchedule());
    } catch (e) {
      return ScheduleResult.failure(e.toString());
    }
  }

  /// Updates an existing schedule identified by [id].
  ///
  /// Cancels the current alarm (if any), applies [config], and reschedules
  /// if [WallpaperScheduleConfig.activate] is `true`.
  ///
  /// Returns [ScheduleResult.failure] if no schedule with [id] exists.
  /// [ScheduleResult.requiredPermissions] is non-null when the failure is
  /// permission-related.
  static Future<ScheduleResult> updateSchedule({
    required String id,
    required WallpaperScheduleConfig config,
  }) async {
    _assertInitialized();
    final urlValidationError = _validateUrl(config.imageUrl);
    if (urlValidationError != null) return ScheduleResult.failure(urlValidationError);
    if (config.validateUrl) {
      final reachabilityError = await WallpaperService.validateUrl(config.imageUrl.trim());
      if (reachabilityError != null) return ScheduleResult.failure(reachabilityError);
    }
    try {
      final existing = await ScheduleStorage.findById(id);
      if (existing == null) {
        return ScheduleResult.failure('Schedule not found: $id');
      }

      // Always cancel the existing alarm before rescheduling.
      await AlarmService.cancel(existing.alarmId);

      var record = existing.copyWith(
        name: config.name.trim(),
        imageUrl: config.imageUrl.trim(),
        hour: config.time.hour,
        minute: config.time.minute,
        targetValue: config.target.value,
        isActive: false,
        // Keep last update history.
        lastUpdated: existing.lastUpdated,
        lastError: existing.lastError,
        maxRetries: config.maxRetries,
        retryDelaySeconds: config.retryDelay.inSeconds,
      );

      if (config.activate) {
        final ok = await AlarmService.schedule(record);
        if (!ok) {
          final perms = await checkPermissions();
          return ScheduleResult.failure(
            'Alarm rescheduling failed. Check SCHEDULE_EXACT_ALARM permission.',
            requiredPermissions: perms.isFullyGranted ? null : perms,
          );
        }
        record = record.copyWith(isActive: true);
      }

      await ScheduleStorage.upsert(record);
      return ScheduleResult.success(record.toSchedule());
    } catch (e) {
      return ScheduleResult.failure(e.toString());
    }
  }

  /// Deletes the schedule with [id] and cancels its alarm.
  ///
  /// Returns `true` on success, `false` if not found or an error occurred.
  static Future<bool> deleteSchedule(String id) async {
    _assertInitialized();
    try {
      final record = await ScheduleStorage.findById(id);
      if (record != null) await AlarmService.cancel(record.alarmId);
      await ScheduleStorage.delete(id);
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Deletes **all** schedules and cancels all alarms.
  ///
  /// Returns `true` on success.
  static Future<bool> deleteAllSchedules() async {
    _assertInitialized();
    try {
      final records = await ScheduleStorage.loadAll();
      for (final r in records) {
        await AlarmService.cancel(r.alarmId);
      }
      await ScheduleStorage.deleteAll();
      return true;
    } catch (_) {
      return false;
    }
  }

  // ── Start / Stop ──────────────────────────────────────────────────────────

  /// Activates an existing inactive schedule — schedules its daily alarm.
  ///
  /// Returns a [ScheduleResult] with the updated [WallpaperSchedule] on
  /// success, or an error on failure.
  /// [ScheduleResult.requiredPermissions] is non-null when the failure is
  /// permission-related.
  static Future<ScheduleResult> startSchedule(String id) async {
    _assertInitialized();
    try {
      final record = await ScheduleStorage.findById(id);
      if (record == null) {
        return ScheduleResult.failure('Schedule not found: $id');
      }
      if (record.isActive) {
        return ScheduleResult.success(record.toSchedule()); // already active
      }

      final ok = await AlarmService.schedule(record);
      if (!ok) {
        final perms = await checkPermissions();
        return ScheduleResult.failure(
          'Failed to start alarm. Check SCHEDULE_EXACT_ALARM permission.',
          requiredPermissions: perms.isFullyGranted ? null : perms,
        );
      }
      final active = record.copyWith(isActive: true);
      await ScheduleStorage.upsert(active);
      return ScheduleResult.success(active.toSchedule());
    } catch (e) {
      return ScheduleResult.failure(e.toString());
    }
  }

  /// Deactivates an active schedule — cancels its alarm but keeps the record.
  ///
  /// Returns `true` on success.
  static Future<bool> stopSchedule(String id) async {
    _assertInitialized();
    try {
      final record = await ScheduleStorage.findById(id);
      if (record == null) return false;
      await AlarmService.cancel(record.alarmId);
      await ScheduleStorage.upsert(record.copyWith(isActive: false));
      return true;
    } catch (_) {
      return false;
    }
  }

  // ── Queries ───────────────────────────────────────────────────────────────

  /// Returns all saved schedules (active and inactive).
  static Future<List<WallpaperSchedule>> getAllSchedules() async {
    _assertInitialized();
    final records = await ScheduleStorage.loadAll();
    return records.map((r) => r.toSchedule()).toList();
  }

  /// Returns only the currently active (alarm-scheduled) schedules.
  static Future<List<WallpaperSchedule>> getActiveSchedules() async {
    _assertInitialized();
    final records = await ScheduleStorage.loadAll();
    return records.where((r) => r.isActive).map((r) => r.toSchedule()).toList();
  }

  /// Returns the schedule with [id], or `null` if not found.
  static Future<WallpaperSchedule?> getSchedule(String id) async {
    _assertInitialized();
    return (await ScheduleStorage.findById(id))?.toSchedule();
  }

  // ── Permissions ───────────────────────────────────────────────────────────

  /// Returns a [PermissionStatus] snapshot — does **not** request anything.
  ///
  /// Use this to proactively check which permissions are missing and decide
  /// which rationale dialog(s) to show in your app **before** calling the
  /// corresponding `request*` methods.
  ///
  /// ```dart
  /// final perms = await ApslWallpaperScheduler.checkPermissions();
  /// if (!perms.hasExactAlarm) {
  ///   // show your dialog, then:
  ///   await ApslWallpaperScheduler.requestExactAlarmPermission();
  /// }
  /// if (!perms.hasBatteryExemption) {
  ///   // show your dialog, then:
  ///   await ApslWallpaperScheduler.requestBatteryOptimizationExemption();
  /// }
  /// ```
  static Future<PermissionStatus> checkPermissions() async {
    final hasAlarm = await AlarmService.hasExactAlarmPermission();
    final hasBattery = await AlarmService.isBatteryOptimizationExempt();
    return PermissionStatus(
      hasExactAlarm: hasAlarm,
      hasBatteryExemption: hasBattery,
    );
  }

  /// Returns `true` if `SCHEDULE_EXACT_ALARM` is granted (or Android < 12).
  static Future<bool> hasExactAlarmPermission() =>
      AlarmService.hasExactAlarmPermission();

  /// Returns `true` if the app is exempt from battery optimisation.
  static Future<bool> isBatteryOptimizationExempt() =>
      AlarmService.isBatteryOptimizationExempt();

  /// Opens the system "Alarms & Reminders" settings page and returns `true`
  /// if the permission is granted after the user returns to the app.
  ///
  /// Call this **after** showing your own rationale dialog.
  static Future<bool> requestExactAlarmPermission() =>
      AlarmService.requestExactAlarmPermission();

  /// Opens the system battery-optimisation exemption dialog.
  ///
  /// Returns `true` if the exemption is (or was already) granted after the
  /// user returns from the system dialog, `false` if they declined.
  ///
  /// Call this **after** showing your own rationale dialog.
  /// Without this exemption, Doze mode on aggressive OEMs (Samsung, Xiaomi,
  /// OnePlus, Realme…) may suppress alarms even when the alarm permission is
  /// granted.
  static Future<bool> requestBatteryOptimizationExemption() =>
      AlarmService.requestBatteryExemption();

  // ── Internal ──────────────────────────────────────────────────────────────

  static void _assertInitialized() {
    if (!_initialized) {
      throw StateError(
        'ApslWallpaperScheduler is not initialised.\n'
        'Call ApslWallpaperScheduler.initialize() inside main() '
        'after WidgetsFlutterBinding.ensureInitialized().',
      );
    }
  }

  /// Returns an error message if [url] is invalid, or `null` if it is valid.
  /// Catches bad URLs at schedule-creation time rather than silently failing
  /// hours later when the alarm fires in the background.
  static String? _validateUrl(String url) {
    final trimmed = url.trim();
    if (trimmed.isEmpty) return 'Image URL cannot be empty.';
    if (!trimmed.startsWith('http://') && !trimmed.startsWith('https://')) {
      return 'Image URL must start with http:// or https://.';
    }
    return null;
  }
}
