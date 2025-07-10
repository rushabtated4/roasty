import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/habit_model.dart';
import '../services/database_service.dart';
import 'package:flutter/foundation.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz;

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  static final FlutterLocalNotificationsPlugin _notifications = FlutterLocalNotificationsPlugin();
  static const String alarmChannelId = 'savage_streak_alarms';
  static const String alarmChannelName = 'Habit Alarms';
  static const String reminderChannelId = 'savage_streak_reminders';
  static const String reminderChannelName = 'Habit Reminders';
  bool _isTimeZoneInitialized = false;

  NotificationService._internal();

  factory NotificationService() => _instance;

  Future<void> _initializeTimeZone() async {
    if (!_isTimeZoneInitialized) {
      tz.initializeTimeZones();
      _isTimeZoneInitialized = true;
      debugPrint('[DEBUG] Timezone initialized');
    }
  }

  Future<void> initialize() async {
    try {
      // Initialize timezone
      await _initializeTimeZone();
      
      const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
      
      const iosSettings = DarwinInitializationSettings(
        requestSoundPermission: true,
        requestBadgePermission: true,
        requestAlertPermission: true,
      );

      const macosSettings = DarwinInitializationSettings(
        requestSoundPermission: true,
        requestBadgePermission: true,
        requestAlertPermission: true,
      );

      const initializationSettings = InitializationSettings(
        android: androidSettings,
        iOS: iosSettings,
        macOS: macosSettings,
      );

      await _notifications.initialize(
        initializationSettings,
        onDidReceiveNotificationResponse: _onNotificationTapped,
      );
      await _requestPermissions();
    } catch (e) {
      debugPrint('Notification service initialization failed: $e');
    }
  }

  Future<void> _requestPermissions() async {
    try {
      // Request permissions on iOS/macOS
      await _notifications
          .resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>()
          ?.requestPermissions(
            alert: true,
            badge: true,
            sound: true,
            critical: true,
          );
          
      await _notifications
          .resolvePlatformSpecificImplementation<MacOSFlutterLocalNotificationsPlugin>()
          ?.requestPermissions(
            alert: true,
            badge: true,
            sound: true,
            critical: true,
          );

      // Request permissions on Android
      await _notifications
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
          ?.requestNotificationsPermission();

      // Request full-screen intent permission on Android
      await _notifications
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
          ?.requestExactAlarmsPermission();
    } catch (e) {
      debugPrint('Permission request failed: $e');
    }
  }

  Future<void> scheduleHabitReminders(HabitModel habit, String roastText, String missedText) async {
    await cancelAllNotifications();

    final prefs = await SharedPreferences.getInstance();
    final notificationsEnabled = prefs.getBool('notifications_enabled') ?? true;
    
    if (!notificationsEnabled || habit.reminderTime == null) return;

    final reminderTime = _parseTime(habit.reminderTime!);
    if (reminderTime == null) return;

    debugPrint('[DEBUG] Loaded reminderTime from DB: \'${habit.reminderTime}\'');

    try {
      // Schedule primary daily reminder
      final scheduledTime = _nextInstanceOfTime(reminderTime);
      await _scheduleRecurringNotification(
        id: 1,
        title: 'Savage Streak',
        body: roastText,
        scheduledTime: scheduledTime,
        useAlarmChannel: true,
      );
      debugPrint('[DEBUG] Scheduled alarm notification: id=1, time=$scheduledTime');

      // Schedule secondary reminder (3 hours later)
      final secondaryTime = scheduledTime.add(const Duration(hours: 3));
      await _scheduleRecurringNotification(
        id: 2,
        title: 'Not done, missed',
        body: missedText,
        scheduledTime: secondaryTime,
        useAlarmChannel: false,
      );
      debugPrint('[DEBUG] Scheduled reminder notification: id=2, time=$secondaryTime');
    } catch (e) {
      debugPrint('Failed to schedule notifications: $e');
    }
  }

  Future<void> _scheduleRecurringNotification({
    required int id,
    required String title,
    required String body,
    required DateTime scheduledTime,
    required bool useAlarmChannel,
  }) async {
    await _initializeTimeZone();
    final tzDateTime = _toTZDateTime(scheduledTime);

    final androidDetails = AndroidNotificationDetails(
      useAlarmChannel ? alarmChannelId : reminderChannelId,
      useAlarmChannel ? alarmChannelName : reminderChannelName,
      channelDescription: 'Daily habit reminder notifications',
      importance: Importance.high,
      priority: Priority.high,
      fullScreenIntent: useAlarmChannel,
      category: AndroidNotificationCategory.alarm,
    );

    final iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
      interruptionLevel: InterruptionLevel.timeSensitive,
      categoryIdentifier: 'habit_reminder',
    );

    final notificationDetails = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _notifications.zonedSchedule(
      id,
      title,
      body,
      tzDateTime,
      notificationDetails,
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
      matchDateTimeComponents: DateTimeComponents.time, // Makes it repeat daily
    );
  }

  tz.TZDateTime _toTZDateTime(DateTime dateTime) {
    final localTimeZone = tz.local;
    return tz.TZDateTime(
      localTimeZone,
      dateTime.year,
      dateTime.month,
      dateTime.day,
      dateTime.hour,
      dateTime.minute,
    );
  }

  DateTime _nextInstanceOfTime(DateTime time) {
    final now = DateTime.now();
    var scheduledDate = DateTime(
      now.year,
      now.month,
      now.day,
      time.hour,
      time.minute,
    );

    if (scheduledDate.isBefore(now)) {
      scheduledDate = scheduledDate.add(const Duration(days: 1));
    }

    return scheduledDate;
  }

  DateTime? _parseTime(String timeString) {
    try {
      final parts = timeString.split(':');
      if (parts.length != 2) return null;
      
      final hour = int.parse(parts[0]);
      final minute = int.parse(parts[1]);
      
      return DateTime(2024, 1, 1, hour, minute);
    } catch (e) {
      return null;
    }
  }

  Future<void> cancelAllNotifications() async {
    await _notifications.cancelAll();
  }

  Future<void> cancelNotification(int id) async {
    await _notifications.cancel(id);
  }

  Future<void> setNotificationsEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('notifications_enabled', enabled);
    
    if (!enabled) {
      await cancelAllNotifications();
    }
  }

  Future<bool> areNotificationsEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool('notifications_enabled') ?? true;
  }

  void _onNotificationTapped(NotificationResponse response) {
    // Handle notification taps here if needed
  }
}