// Internal — not exported from the public API.

import 'dart:async';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:wallpaper_manager_flutter/wallpaper_manager_flutter.dart';

class WallpaperService {
  /// Returns a unique cache file per [alarmId] so that concurrent alarm
  /// callbacks (multiple schedules at the same time) never overwrite each
  /// other's downloaded image.
  static Future<File> _cacheFile(int alarmId) async {
    final dir = await getApplicationDocumentsDirectory();
    return File('${dir.path}/apsl_wallpaper_cache_$alarmId.png');
  }

  /// Downloads the image at [url] and saves it to a per-alarm cache file.
  ///
  /// Retries up to [_maxRetries] times (with a [_retryDelay] pause between
  /// attempts) when the server returns a 5xx error or the request times out.
  /// This handles server-side rate limiting that occurs when multiple schedules
  /// fire at the same time and hit the image server simultaneously.
  ///
  /// Throws an [Exception] if all attempts fail.
  static const int _maxRetries = 2;
  static const Duration _retryDelay = Duration(seconds: 5);

  static Future<void> downloadAndSave(String url, int alarmId) async {
    Exception? lastError;

    for (int attempt = 0; attempt <= _maxRetries; attempt++) {
      if (attempt > 0) await Future.delayed(_retryDelay);
      try {
        final response = await http
            .get(Uri.parse(url))
            .timeout(const Duration(seconds: 30));

        if (response.statusCode == 200) {
          final file = await _cacheFile(alarmId);
          await file.writeAsBytes(response.bodyBytes);
          return; // success — exit immediately
        }

        lastError = Exception(
            'Image download failed (HTTP ${response.statusCode}): $url');

        // Only retry on server-side (5xx) errors; fail fast on 4xx.
        if (response.statusCode < 500) throw lastError;
      } on TimeoutException {
        lastError = Exception('Image download timed out: $url');
      } on http.ClientException {
        lastError = Exception('Connection closed during download: $url');
      }
    }

    throw lastError!;
  }

  /// Sets the cached image as the device wallpaper on [targetValue] screen(s).
  ///
  /// [targetValue] must be 1 (home), 2 (lock), or 3 (both).
  ///
  /// When [targetValue] is 3 (both), the wallpaper is set on home and lock
  /// screens via two separate calls instead of a single combined call.
  /// Many Android OEM implementations (MIUI, One UI, etc.) do not reliably
  /// honour the combined FLAG_SYSTEM|FLAG_LOCK bitmask in a single
  /// WallpaperManager.setStream() call, causing it to silently fail.
  ///
  /// Always deletes the per-alarm cache file after use — whether the
  /// wallpaper set succeeds or throws — to avoid stale files accumulating.
  static Future<void> setWallpaper(int targetValue, int alarmId) async {
    final file = await _cacheFile(alarmId);
    if (!await file.exists()) {
      throw Exception(
          'Wallpaper cache file not found. Call downloadAndSave() first.');
    }
    final plugin = WallpaperManagerFlutter();
    try {
      if (targetValue == 3) {
        // Set home and lock screens separately for reliable OEM compatibility.
        await plugin.setWallpaper(file, WallpaperManagerFlutter.homeScreen);
        await plugin.setWallpaper(file, WallpaperManagerFlutter.lockScreen);
      } else {
        await plugin.setWallpaper(file, _toPluginLocation(targetValue));
      }
    } finally {
      // Delete regardless of success or failure to keep storage clean.
      await file.delete().catchError((_) => file);
    }
  }

  /// Convenience: download then set in one call.
  static Future<void> downloadAndSet(
      String url, int targetValue, int alarmId) async {
    await downloadAndSave(url, alarmId);
    await setWallpaper(targetValue, alarmId);
  }

  static int _toPluginLocation(int targetValue) {
    switch (targetValue) {
      case 1:
        return WallpaperManagerFlutter.homeScreen;
      case 2:
        return WallpaperManagerFlutter.lockScreen;
      default:
        return WallpaperManagerFlutter.bothScreens;
    }
  }
}
