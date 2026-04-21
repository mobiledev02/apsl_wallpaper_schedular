// Internal — not exported from the public API.

import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class NotificationService {
  static const String _channelId = 'apsl_wallpaper_updates';
  static const String _channelName = 'Wallpaper Updates';
  static const String _channelDesc =
      'Notifications sent after each automatic wallpaper update.';

  static final _plugin = FlutterLocalNotificationsPlugin();

  /// Call once during [ApslWallpaperScheduler.initialize].
  static Future<void> init() async {
    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    await _plugin
        .initialize(const InitializationSettings(android: androidInit));

    const channel = AndroidNotificationChannel(
      _channelId,
      _channelName,
      description: _channelDesc,
      importance: Importance.defaultImportance,
    );
    await _plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(channel);
  }

  /// Shows a notification for a completed wallpaper update.
  /// Called from the background alarm isolate — re-initialises the plugin
  /// because the isolate does not share state with the main isolate.
  static Future<void> showUpdateNotification({
    required int notifId,
    required String scheduleName,
  }) async {
    // Re-init for background isolate (cheap if already initialised).
    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    await _plugin
        .initialize(const InitializationSettings(android: androidInit));

    await _plugin.show(
      notifId,
      'Auto Wallpaper Setter',
      '"$scheduleName" updated successfully',
      const NotificationDetails(
        android: AndroidNotificationDetails(
          _channelId,
          _channelName,
          channelDescription: _channelDesc,
          importance: Importance.defaultImportance,
          priority: Priority.defaultPriority,
        ),
      ),
    );
  }

  /// Shows a notification when a wallpaper update fails.
  /// Uses the first line of [reason] so the structured error stays readable.
  static Future<void> showFailureNotification({
    required int notifId,
    required String scheduleName,
    required String reason,
  }) async {
    // Re-init for background isolate (cheap if already initialised).
    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    await _plugin
        .initialize(const InitializationSettings(android: androidInit));

    // First line is the short category+summary, e.g. "[NO_INTERNET] Attempt 1/3 — ..."
    final shortReason = reason.split('\n').first;

    await _plugin.show(
      notifId + 10000, // offset to avoid collision with success notification IDs
      'Wallpaper Update Failed — $scheduleName',
      shortReason,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          _channelId,
          _channelName,
          channelDescription: _channelDesc,
          importance: Importance.high,
          priority: Priority.high,
        ),
      ),
    );
  }
}
