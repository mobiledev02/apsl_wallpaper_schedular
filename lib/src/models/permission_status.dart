/// Snapshot of the two permissions required by [ApslWallpaperScheduler].
///
/// Returned by [ApslWallpaperScheduler.checkPermissions] and embedded in a
/// [ScheduleResult] whenever a scheduling call fails because a permission is
/// missing. Use the flags to decide which rationale dialog(s) to show in your
/// app before calling the corresponding `request*` method.
class PermissionStatus {
  /// `true` if `SCHEDULE_EXACT_ALARM` (or `USE_EXACT_ALARM`) is granted,
  /// or the device runs Android < 12 (where the permission is not required).
  final bool hasExactAlarm;

  /// `true` if the app is exempt from battery optimisation (Doze mode).
  ///
  /// Without this exemption, aggressive OEM battery savers (Samsung OneUI,
  /// MIUI, ColorOS…) may suppress alarms even when [hasExactAlarm] is `true`.
  final bool hasBatteryExemption;

  const PermissionStatus({
    required this.hasExactAlarm,
    required this.hasBatteryExemption,
  });

  /// `true` when both permissions are satisfied and scheduling will succeed.
  bool get isFullyGranted => hasExactAlarm && hasBatteryExemption;

  @override
  String toString() =>
      'PermissionStatus(hasExactAlarm: $hasExactAlarm, '
      'hasBatteryExemption: $hasBatteryExemption)';
}
