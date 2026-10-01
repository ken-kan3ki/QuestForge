import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

import 'reminder_service.dart';

/// Service wrapping [FlutterLocalNotificationsPlugin] for OS notification scheduling,
/// cancellation, and permission handling across Android, Windows, and other platforms.
class NotificationService {
  NotificationService({FlutterLocalNotificationsPlugin? plugin})
      : _plugin = plugin ?? FlutterLocalNotificationsPlugin();

  final FlutterLocalNotificationsPlugin _plugin;
  bool _isInitialized = false;

  bool get isInitialized => _isInitialized;

  /// Deterministically converts a string notification ID into a positive 32-bit integer ID
  /// required by OS notification channels and flutter_local_notifications.
  static int stringToIntId(String id) {
    var hash = 0;
    for (var i = 0; i < id.length; i++) {
      hash = (31 * hash + id.codeUnitAt(i)) & 0x7FFFFFFF;
    }
    return hash;
  }

  /// Initializes timezone data and the underlying notification plugin with default channel configuration.
  Future<bool> initialize() async {
    if (_isInitialized) return true;

    try {
      tz.initializeTimeZones();

      const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
      const darwinSettings = DarwinInitializationSettings(
        requestAlertPermission: false,
        requestBadgePermission: false,
        requestSoundPermission: false,
      );
      const linuxSettings = LinuxInitializationSettings(
        defaultActionName: 'Open notification',
      );

      const initializationSettings = InitializationSettings(
        android: androidSettings,
        iOS: darwinSettings,
        macOS: darwinSettings,
        linux: linuxSettings,
      );

      final initialized = await _plugin.initialize(
        settings: initializationSettings,
      );

      _isInitialized = initialized ?? true;

      if (_isInitialized && !kIsWeb && Platform.isAndroid) {
        await _createNotificationChannel();
      }

      return _isInitialized;
    } catch (e, st) {
      debugPrint('NotificationService initialization failed: $e\n$st');
      _isInitialized = false;
      return false;
    }
  }

  Future<void> _createNotificationChannel() async {
    final androidImplementation = _plugin
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();

    if (androidImplementation != null) {
      await androidImplementation.createNotificationChannel(
        const AndroidNotificationChannel(
          'quest_reminders_channel',
          'Quest Reminders',
          description: 'Notifications for upcoming quests and daily check-ins',
          importance: Importance.high,
        ),
      );
    }
  }

  /// Requests notification permissions on platforms that require runtime permissions (e.g. Android 13+).
  ///
  /// Returns `true` if permissions are granted or not required (e.g., Windows), `false` if denied.
  Future<bool> requestPermission() async {
    if (!_isInitialized) {
      final ok = await initialize();
      if (!ok) return false;
    }

    if (kIsWeb) return false;

    if (Platform.isAndroid) {
      final androidImplementation = _plugin
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
      if (androidImplementation != null) {
        final grantedNotifications =
            await androidImplementation.requestNotificationsPermission();
        return grantedNotifications ?? false;
      }
    } else if (Platform.isIOS || Platform.isMacOS) {
      final darwinImplementation = _plugin
          .resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>();
      if (darwinImplementation != null) {
        final granted = await darwinImplementation.requestPermissions(
          alert: true,
          badge: true,
          sound: true,
        );
        return granted ?? false;
      }
    }

    // Default to true on platforms where explicit runtime permission prompt is not required (Windows, Linux)
    return true;
  }

  /// Checks if notification permissions have been granted.
  Future<bool> hasPermission() async {
    if (!_isInitialized) {
      await initialize();
    }

    if (kIsWeb) return false;

    if (Platform.isAndroid) {
      final androidImplementation = _plugin
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
      if (androidImplementation != null) {
        final granted = await androidImplementation.areNotificationsEnabled();
        return granted ?? false;
      }
    }

    return true;
  }

  /// Schedules an OS notification for a given [ScheduledNotification] object.
  Future<bool> scheduleNotification(ScheduledNotification notification) async {
    if (!_isInitialized) {
      final ok = await initialize();
      if (!ok) return false;
    }

    final int notificationId = stringToIntId(notification.id);
    final DateTime targetTime = notification.scheduledAt;

    if (targetTime.isBefore(DateTime.now())) {
      return false;
    }

    try {
      final tzScheduledAt = tz.TZDateTime.from(targetTime, tz.local);

      const notificationDetails = NotificationDetails(
        android: AndroidNotificationDetails(
          'quest_reminders_channel',
          'Quest Reminders',
          channelDescription: 'Notifications for upcoming quests and daily check-ins',
          importance: Importance.high,
          priority: Priority.high,
        ),
        iOS: DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        ),
        macOS: DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        ),
        linux: LinuxNotificationDetails(),
      );

      await _plugin.zonedSchedule(
        id: notificationId,
        title: notification.title,
        body: notification.body,
        scheduledDate: tzScheduledAt,
        notificationDetails: notificationDetails,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      );

      return true;
    } catch (e, st) {
      debugPrint('Failed to schedule OS notification ${notification.id}: $e\n$st');
      return false;
    }
  }

  /// Cancels an OS notification by its string identifier.
  Future<void> cancelNotification(String id) async {
    if (!_isInitialized) {
      await initialize();
    }
    try {
      final int notificationId = stringToIntId(id);
      await _plugin.cancel(id: notificationId);
    } catch (e) {
      debugPrint('Failed to cancel OS notification $id: $e');
    }
  }

  /// Cancels all OS notifications.
  Future<void> cancelAllNotifications() async {
    if (!_isInitialized) {
      await initialize();
    }
    try {
      await _plugin.cancelAll();
    } catch (e) {
      debugPrint('Failed to cancel all OS notifications: $e');
    }
  }
}
