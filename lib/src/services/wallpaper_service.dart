// Internal — not exported from the public API.

import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:wallpaper_manager_flutter/wallpaper_manager_flutter.dart';

class WallpaperService {
  static const String _fileName = 'apsl_wallpaper_cache.png';

  static Future<File> _cacheFile() async {
    final dir = await getApplicationDocumentsDirectory();
    return File('${dir.path}/$_fileName');
  }

  /// Downloads the image at [url] and saves it to the app's documents dir.
  /// Throws a descriptive [Exception] if the HTTP status is not 200.
  static Future<void> downloadAndSave(String url) async {
    final response = await http.get(Uri.parse(url));
    if (response.statusCode != 200) {
      throw Exception(
          'Image download failed (HTTP ${response.statusCode}): $url');
    }
    final file = await _cacheFile();
    await file.writeAsBytes(response.bodyBytes);
  }

  /// Sets the cached image as the device wallpaper on [targetValue] screen(s).
  ///
  /// [targetValue] must be 1 (home), 2 (lock), or 3 (both) — matching
  /// the values defined by [WallpaperTarget].
  ///
  /// Throws if the cached file does not exist (call [downloadAndSave] first).
  static Future<void> setWallpaper(int targetValue) async {
    final file = await _cacheFile();
    if (!await file.exists()) {
      throw Exception(
          'Wallpaper cache file not found. Call downloadAndSave() first.');
    }

    final location = _toPluginLocation(targetValue);
    await WallpaperManagerFlutter().setWallpaper(file, location);
  }

  /// Convenience: download then set in one call.
  static Future<void> downloadAndSet(String url, int targetValue) async {
    await downloadAndSave(url);
    await setWallpaper(targetValue);
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
