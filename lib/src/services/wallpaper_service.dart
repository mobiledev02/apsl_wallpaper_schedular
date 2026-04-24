// Internal — not exported from the public API.

import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:wallpaper_manager_flutter/wallpaper_manager_flutter.dart';

class WallpaperService {
  static const int _defaultMaxRetries = 2;
  static const Duration _defaultRetryDelay = Duration(seconds: 20);
  static const int _maxImageBytes = 20 * 1024 * 1024; // 20 MB

  /// Returns a unique cache file per [alarmId] so that concurrent alarm
  /// callbacks (multiple schedules at the same time) never overwrite each
  /// other's downloaded image.
  static Future<File> _cacheFile(int alarmId) async {
    final dir = await getApplicationDocumentsDirectory();
    return File('${dir.path}/apsl_wallpaper_cache_$alarmId.png');
  }

  /// Downloads the image at [url] and saves it to a per-alarm cache file.
  ///
  /// Retries up to [maxRetries] times (with a [retryDelay] pause between
  /// attempts) when the server returns a 5xx error or the request times out.
  /// Throws an [Exception] if all attempts fail.
  static Future<void> downloadAndSave(
    String url,
    int alarmId, {
    int maxRetries = _defaultMaxRetries,
    Duration retryDelay = _defaultRetryDelay,
  }) async {
    final Uri uri;
    try {
      uri = Uri.parse(url);
      if (!uri.hasScheme || !uri.scheme.startsWith('http')) {
        throw Exception(
            '[INVALID_URL] URL is not a valid http/https address.\n'
            'URL: $url\n'
            'Hint: Make sure the image URL starts with http:// or https://.');
      }
    } on FormatException {
      throw Exception(
          '[INVALID_URL] URL is malformed and cannot be parsed.\n'
          'URL: $url\n'
          'Hint: Check the URL for typos or invalid characters.');
    }

    Exception? lastError;
    final total = maxRetries + 1;

    for (int attempt = 0; attempt <= maxRetries; attempt++) {
      if (attempt > 0) await Future.delayed(retryDelay);
      final label = 'Attempt ${attempt + 1}/$total';
      try {
        final response = await http
            .get(uri)
            .timeout(const Duration(seconds: 60));

        if (response.statusCode == 200) {
          // Validate that the response is actually an image.
          final contentType = (response.headers['content-type'] ?? '').toLowerCase();
          if (!contentType.startsWith('image/') && !contentType.contains('octet-stream')) {
            throw Exception(
                '[INVALID_CONTENT_TYPE] $label — Expected an image but got: $contentType\n'
                'URL: $url\n'
                'Hint: The URL must point directly to an image file (PNG, JPG, WebP, etc.), '
                'not a webpage or API endpoint.');
          }

          // Guard against oversized images that could exhaust memory.
          if (response.bodyBytes.length > _maxImageBytes) {
            throw Exception(
                '[IMAGE_TOO_LARGE] $label — Image is ${response.bodyBytes.length ~/ (1024 * 1024)} MB, '
                'which exceeds the 20 MB limit.\n'
                'URL: $url\n'
                'Hint: Use a smaller or compressed image URL.');
          }

          final file = await _cacheFile(alarmId);
          await file.writeAsBytes(response.bodyBytes);
          return; // success — exit immediately
        }

        final category =
            response.statusCode >= 500 ? 'SERVER_ERROR' : 'HTTP_${response.statusCode}';
        final body = response.body.trim();
        final bodySnippet = body.isNotEmpty
            ? '\nServer Response: ${body.length > 300 ? '${body.substring(0, 300)}…' : body}'
            : '';
        lastError = Exception(
            '[$category] $label — Server returned HTTP ${response.statusCode}.$bodySnippet\n'
            'URL: $url\n'
            'Hint: ${_statusHint(response.statusCode)}');

        if (response.statusCode < 500) throw lastError;
      } on TimeoutException {
        lastError = Exception(
            '[DOWNLOAD_TIMEOUT] $label — No response after 60 seconds.\n'
            'URL: $url\n'
            'Hint: The server is too slow or the URL is unreachable. '
            'Check if the URL opens in a browser on the device.');
      } on SocketException catch (e) {
        lastError = Exception(
            '[NO_INTERNET] $label — No network connection available.\n'
            'Reason: ${e.message}\n'
            'Hint: The device had no internet at the scheduled time. '
            'Ensure mobile data or Wi-Fi is enabled and not blocked by battery saver.');
      } on http.ClientException catch (e) {
        lastError = Exception(
            '[CONNECTION_LOST] $label — Connection dropped mid-download.\n'
            'Reason: ${e.message}\n'
            'Hint: Unstable network. The device may have switched from '
            'Wi-Fi to mobile data during the download.');
      }
    }

    throw lastError!;
  }

  /// Sets the cached image as the device wallpaper on [targetValue] screen(s).
  static Future<void> setWallpaper(int targetValue, int alarmId) async {
    final file = await _cacheFile(alarmId);
    if (!await file.exists()) {
      throw Exception(
          '[CACHE_MISSING] Downloaded image file was not found on disk.\n'
          'Hint: Storage may be full or the OS deleted the cache file. '
          'This is usually temporary — it should work on the next scheduled run.');
    }
    final plugin = WallpaperManagerFlutter();
    try {
      if (targetValue == 3) {
        await plugin.setWallpaper(file, WallpaperManagerFlutter.homeScreen);
        await plugin.setWallpaper(file, WallpaperManagerFlutter.lockScreen);
      } else {
        await plugin.setWallpaper(file, _toPluginLocation(targetValue));
      }
    } catch (e) {
      throw Exception(
          '[WALLPAPER_SET_FAILED] Could not apply wallpaper to '
          '${_targetName(targetValue)} screen.\n'
          'Reason: ${e.toString()}\n'
          'Hint: Some OEM devices (MIUI, One UI, ColorOS) block background '
          'wallpaper changes. Grant "Display over other apps" permission or '
          'disable battery optimisation for this app in device settings.');
    } finally {
      await file.delete().catchError((e) {
        debugPrint('[WallpaperService] Failed to delete cache file: $e');
        return file;
      });
    }
  }

  /// Convenience: download then set in one call.
  static Future<void> downloadAndSet(
    String url,
    int targetValue,
    int alarmId, {
    int maxRetries = _defaultMaxRetries,
    Duration retryDelay = _defaultRetryDelay,
  }) async {
    await downloadAndSave(url, alarmId, maxRetries: maxRetries, retryDelay: retryDelay);
    await setWallpaper(targetValue, alarmId);
  }

  /// Sends a HEAD request to [url] to verify it is reachable and returns an
  /// image. Returns `null` on success, or an error message string on failure.
  /// Used by [ApslWallpaperScheduler.createSchedule] when [validateUrl] is true.
  static Future<String?> validateUrl(String url) async {
    try {
      final uri = Uri.parse(url);
      final response = await http.head(uri).timeout(const Duration(seconds: 10));
      if (response.statusCode == 200) return null;
      return 'URL returned HTTP ${response.statusCode}. ${_statusHint(response.statusCode)}';
    } on TimeoutException {
      return 'URL did not respond within 10 seconds. Check if it is accessible.';
    } on SocketException catch (e) {
      return 'Network error while validating URL: ${e.message}';
    } catch (e) {
      return 'Could not validate URL: $e';
    }
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

  static String _targetName(int targetValue) {
    switch (targetValue) {
      case 1:
        return 'Home';
      case 2:
        return 'Lock';
      default:
        return 'Home & Lock';
    }
  }

  static String _statusHint(int code) {
    switch (code) {
      case 400:
        return 'Bad request — the URL may have invalid query parameters.';
      case 401:
        return 'Unauthorised — the image requires a login or API key. Use a publicly accessible URL.';
      case 403:
        return 'Forbidden — access to this image is blocked. Use a public, direct-link URL.';
      case 404:
        return 'Not Found — the image no longer exists at this URL. Update the image URL in the schedule.';
      case 429:
        return 'Rate limited — too many requests to this server. The retry delay should help.';
      case 500:
        return 'Internal server error — the image server has a problem. Will retry automatically.';
      case 502:
        return 'Bad gateway — the image server is temporarily unreachable. Will retry automatically.';
      case 503:
        return 'Service unavailable — the server is overloaded or down. Will retry automatically.';
      default:
        if (code >= 500) return 'Server-side error. Will retry automatically.';
        return 'Unexpected response — check if the URL is correct and publicly accessible.';
    }
  }
}
