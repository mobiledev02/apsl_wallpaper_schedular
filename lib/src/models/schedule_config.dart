import 'package:flutter/material.dart';
import 'wallpaper_target.dart';

/// Configuration passed to [ApslWallpaperScheduler.createSchedule] and
/// [ApslWallpaperScheduler.updateSchedule].
class WallpaperScheduleConfig {
  /// Display name for the schedule (e.g. "Morning Wallpaper").
  final String name;

  /// The direct URL to a PNG/JPG image that will be downloaded and set as
  /// the wallpaper. Must start with `http` or `https`.
  final String imageUrl;

  /// The time of day at which the wallpaper should update every 24 hours.
  final TimeOfDay time;

  /// Which screen(s) to apply the wallpaper to.
  ///
  /// Defaults to [WallpaperTarget.both].
  final WallpaperTarget target;

  /// If `true` (default), the schedule is activated immediately after saving.
  /// If `false`, the schedule is saved but the alarm is not scheduled — you
  /// can activate it later with [ApslWallpaperScheduler.startSchedule].
  final bool activate;

  /// If `true`, a HEAD request is sent to [imageUrl] at schedule creation time
  /// to verify the URL is reachable before saving the schedule.
  /// Defaults to `false` to avoid breaking integrations with servers that do
  /// not support HEAD or require specific headers.
  final bool validateUrl;

  /// Maximum number of retry attempts after the first download failure.
  /// Defaults to 2 (3 total attempts). Only 5xx errors and timeouts are
  /// retried; 4xx errors fail immediately.
  final int maxRetries;

  /// How long to wait between download retry attempts.
  /// Defaults to 20 seconds.
  final Duration retryDelay;

  const WallpaperScheduleConfig({
    required this.name,
    required this.imageUrl,
    required this.time,
    this.target = WallpaperTarget.both,
    this.activate = true,
    this.validateUrl = false,
    this.maxRetries = 2,
    this.retryDelay = const Duration(seconds: 20),
  });
}
