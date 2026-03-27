import 'package:flutter/material.dart';
import 'wallpaper_target.dart';

/// A read-only snapshot of a wallpaper schedule returned by
/// [ApslWallpaperScheduler] methods.
class WallpaperSchedule {
  /// Unique identifier for this schedule.
  final String id;

  /// Display name chosen by the user.
  final String name;

  /// The URL from which the wallpaper image is downloaded.
  final String imageUrl;

  /// Hour of the day (0–23) at which the wallpaper updates.
  final int hour;

  /// Minute (0–59) at which the wallpaper updates.
  final int minute;

  /// Which screen(s) the wallpaper is applied to.
  final WallpaperTarget target;

  /// Whether this schedule is currently active (alarm is scheduled).
  final bool isActive;

  /// The last time the wallpaper was successfully updated, or null if never.
  final DateTime? lastUpdated;

  /// The last error message if the previous run failed, or null if clean.
  final String? lastError;

  const WallpaperSchedule({
    required this.id,
    required this.name,
    required this.imageUrl,
    required this.hour,
    required this.minute,
    required this.target,
    required this.isActive,
    this.lastUpdated,
    this.lastError,
  });

  /// Convenience getter — returns [hour] and [minute] as a Flutter [TimeOfDay].
  TimeOfDay get time => TimeOfDay(hour: hour, minute: minute);

  /// Human-readable time string, e.g. "8:05 AM".
  String get formattedTime {
    final h = hour == 0 ? 12 : (hour > 12 ? hour - 12 : hour);
    final m = minute.toString().padLeft(2, '0');
    final period = hour >= 12 ? 'PM' : 'AM';
    return '$h:$m $period';
  }

  /// Human-readable target label from [WallpaperTarget.label].
  String get targetLabel => target.label;

  @override
  String toString() =>
      'WallpaperSchedule(id: $id, name: $name, time: $formattedTime, '
      'target: $targetLabel, isActive: $isActive)';
}
