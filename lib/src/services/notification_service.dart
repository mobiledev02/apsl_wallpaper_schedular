// Internal — not exported from the public API.

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';

class NotificationService {
  static const String _channelId = 'apsl_wallpaper_updates';
  static const String _channelName = 'Wallpaper Updates';
  static const String _channelDesc =
      'Notifications sent after each automatic wallpaper update.';
  static const String _errorNotifKey = 'apsl_ws_show_error_notifications';

  static final _plugin = FlutterLocalNotificationsPlugin();

  /// Call once during [ApslWallpaperScheduler.initialize].
  static Future<void> init({bool showErrorNotifications = false}) async {
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

    // Persist the flag so the background isolate can read it from SharedPreferences.
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_errorNotifKey, showErrorNotifications);
  }

  /// Returns whether error notifications are enabled.
  /// Reads from SharedPreferences so it works in both main and background isolates.
  static Future<bool> _isErrorNotificationsEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_errorNotifKey) ?? false;
  }

  static Future<void> _ensureInitialized() async {
    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    await _plugin
        .initialize(const InitializationSettings(android: androidInit));
  }

  /// Shows a notification for a completed wallpaper update.
  /// Called from the background alarm isolate — re-initialises the plugin
  /// because the isolate does not share state with the main isolate.
  static Future<void> showUpdateNotification({
    required int notifId,
    required String scheduleName,
  }) async {
    await _ensureInitialized();
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
    await _ensureInitialized();
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

  /// Shows a notification when the daily alarm reschedule fails.
  /// Only fires if [showErrorNotifications] was `true` in [ApslWallpaperScheduler.initialize].
  /// Uses notifId + 20000 to avoid collisions with wallpaper-update notification IDs.
  static Future<void> showRescheduleFailureNotification({
    required int notifId,
    required String scheduleName,
    required String reason,
  }) async {
    if (!await _isErrorNotificationsEnabled()) return;
    await _ensureInitialized();
    await _plugin.show(
      notifId + 20000,
      'Schedule Broken — $scheduleName',
      reason,
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
