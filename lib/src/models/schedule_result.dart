import 'permission_status.dart';
import 'wallpaper_schedule.dart';

/// The result returned by [ApslWallpaperScheduler.createSchedule],
/// [ApslWallpaperScheduler.updateSchedule], and
/// [ApslWallpaperScheduler.startSchedule].
class ScheduleResult {
  /// Whether the operation completed successfully.
  final bool isSuccess;

  /// The created or updated schedule. Non-null when [isSuccess] is `true`.
  final WallpaperSchedule? schedule;

  /// A human-readable error message. Non-null when [isSuccess] is `false`.
  final String? error;

  /// Non-null when the failure was caused by a missing permission.
  ///
  /// Inspect [PermissionStatus.hasExactAlarm] and
  /// [PermissionStatus.hasBatteryExemption] to know exactly which dialog(s)
  /// to show the user before retrying the operation.
  ///
  /// ```dart
  /// final result = await ApslWallpaperScheduler.createSchedule(config);
  /// if (!result.isSuccess && result.requiredPermissions != null) {
  ///   final p = result.requiredPermissions!;
  ///   if (!p.hasExactAlarm) {
  ///     // Show your own rationale dialog, then:
  ///     await ApslWallpaperScheduler.requestExactAlarmPermission();
  ///   }
  ///   if (!p.hasBatteryExemption) {
  ///     // Show your own rationale dialog, then:
  ///     await ApslWallpaperScheduler.requestBatteryOptimizationExemption();
  ///   }
  /// }
  /// ```
  final PermissionStatus? requiredPermissions;

  const ScheduleResult._({
    required this.isSuccess,
    this.schedule,
    this.error,
    this.requiredPermissions,
  });

  /// Creates a successful result containing [schedule].
  factory ScheduleResult.success(WallpaperSchedule schedule) =>
      ScheduleResult._(isSuccess: true, schedule: schedule);

  /// Creates a failure result with a descriptive [error] message.
  ///
  /// Pass [requiredPermissions] when the failure is due to a missing
  /// permission so callers can react without a second `checkPermissions()` call.
  factory ScheduleResult.failure(
    String error, {
    PermissionStatus? requiredPermissions,
  }) =>
      ScheduleResult._(
        isSuccess: false,
        error: error,
        requiredPermissions: requiredPermissions,
      );

  @override
  String toString() => isSuccess
      ? 'ScheduleResult.success(${schedule?.id})'
      : 'ScheduleResult.failure($error)';
}
