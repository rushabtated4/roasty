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
  static const String alarmChannelId = 'roasty_alarms';
  static const String alarmChannelName = 'Roasty Alarms';
  static const String reminderChannelId = 'roasty_reminders';
  static const String reminderChannelName = 'Roasty Reminders';
  bool _isTimeZoneInitialized = false;

  NotificationService._internal();

  factory NotificationService() => _instance;

  Future<void> _initializeTimeZone() async {
    if (!_isTimeZoneInitialized) {
      try {
        tz.initializeTimeZones();
        
        // Get device's timezone name
        final String deviceTimeZone = DateTime.now().timeZoneName;
        
        // Try to set the local timezone based on device timezone
        try {
          final location = tz.getLocation(deviceTimeZone);
          tz.setLocalLocation(location);
        } catch (e) {
          // Fallback: try common timezone mappings
          
          // Common timezone mappings for fallback
          final Map<String, String> timezoneFallbacks = {
            'PST': 'America/Los_Angeles',
            'PDT': 'America/Los_Angeles',
            'MST': 'America/Denver', 
            'MDT': 'America/Denver',
            'CST': 'America/Chicago',
            'CDT': 'America/Chicago',
            'EST': 'America/New_York',
            'EDT': 'America/New_York',
            'GMT': 'Europe/London',
            'BST': 'Europe/London',
            'CET': 'Europe/Paris',
            'CEST': 'Europe/Paris',
          };
          
          final fallbackTimezone = timezoneFallbacks[deviceTimeZone];
          if (fallbackTimezone != null) {
            try {
              final location = tz.getLocation(fallbackTimezone);
              tz.setLocalLocation(location);
            } catch (fallbackError) {
              final utcLocation = tz.getLocation('UTC');
              tz.setLocalLocation(utcLocation);
            }
          } else {
            final utcLocation = tz.getLocation('UTC');
            tz.setLocalLocation(utcLocation);
          }
        }
        
        _isTimeZoneInitialized = true;
      } catch (e, stackTrace) {
        throw Exception('Timezone initialization failed: $e');
      }
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
    }
  }

  Future<void> _requestPermissions() async {
    try {
      // Request permissions on iOS/macOS
      final iosPermissions = await _notifications
          .resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>()
          ?.requestPermissions(
            alert: true,
            badge: true,
            sound: true,
            critical: true,
          );
      
      if (iosPermissions != null) {
      }
          
      final macosPermissions = await _notifications
          .resolvePlatformSpecificImplementation<MacOSFlutterLocalNotificationsPlugin>()
          ?.requestPermissions(
            alert: true,
            badge: true,
            sound: true,
            critical: true,
          );
      
      if (macosPermissions != null) {
      }

      // Request permissions on Android
      final androidPermissions = await _notifications
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
          ?.requestNotificationsPermission();
      
      if (androidPermissions != null) {
      }

      // Request full-screen intent permission on Android
      final exactAlarmPermission = await _notifications
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
          ?.requestExactAlarmsPermission();
      
      if (exactAlarmPermission != null) {
      }
    } catch (e) {
    }
  }

  Future<void> scheduleHabitReminders(HabitModel habit, String roastText, String missedText) async {
    
    await cancelAllNotifications();

    final prefs = await SharedPreferences.getInstance();
    final notificationsEnabled = prefs.getBool('notifications_enabled') ?? true;
    
    
    if (!notificationsEnabled) {
      return;
    }
    
    if (habit.reminderTime == null) {
      return;
    }

    // Check system permissions
    final hasPermissions = await checkNotificationPermissions();
    
    if (!hasPermissions) {
    }

    final reminderTime = _parseTime(habit.reminderTime!);
    if (reminderTime == null) {
      return;
    }


    try {
      // Schedule primary daily reminder
      final scheduledTime = _nextInstanceOfTime(reminderTime);
      
      await _scheduleRecurringNotification(
        id: 1,
        title: 'Roasty',
        body: roastText,
        scheduledTime: scheduledTime,
        useAlarmChannel: true,
      );

      // Schedule secondary reminder (3 hours later)
      final secondaryTime = scheduledTime.add(const Duration(hours: 3));
      await _scheduleRecurringNotification(
        id: 2,
        title: 'Not done, missed',
        body: missedText,
        scheduledTime: secondaryTime,
        useAlarmChannel: false,
      );
      
      // Verify notifications were scheduled
      final pendingNotifications = await _notifications.pendingNotificationRequests();
      
    } catch (e, stackTrace) {
    }
  }

  Future<void> _scheduleRecurringNotification({
    required int id,
    required String title,
    required String body,
    required DateTime scheduledTime,
    required bool useAlarmChannel,
  }) async {
    try {
      
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
      
    } catch (e, stackTrace) {
      rethrow;
    }
  }

  tz.TZDateTime _toTZDateTime(DateTime dateTime) {
    final localTimeZone = tz.local;
    
    // Convert DateTime to TZDateTime in the local timezone
    // This properly handles the timezone conversion
    final tzDateTime = tz.TZDateTime.from(dateTime, localTimeZone);
    
    return tzDateTime;
  }

  DateTime _nextInstanceOfTime(DateTime time) {
    // Use timezone-aware current time
    final now = tz.TZDateTime.now(tz.local);
    var scheduledDate = tz.TZDateTime(
      tz.local,
      now.year,
      now.month,
      now.day,
      time.hour,
      time.minute,
    );

    if (scheduledDate.isBefore(now)) {
      scheduledDate = scheduledDate.add(const Duration(days: 1));
    }

    // Convert back to DateTime for compatibility with existing code
    return DateTime(
      scheduledDate.year,
      scheduledDate.month,
      scheduledDate.day,
      scheduledDate.hour,
      scheduledDate.minute,
    );
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

  Future<bool> checkNotificationPermissions() async {
    try {
      // Check iOS permissions
      final iosPlugin = _notifications.resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>();
      if (iosPlugin != null) {
        final iosPermissions = await iosPlugin.checkPermissions();
        // For iOS, we'll assume permissions are granted if no exception is thrown
        return true;
      }

      // Check Android permissions
      final androidPlugin = _notifications.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
      if (androidPlugin != null) {
        final androidPermissions = await androidPlugin.areNotificationsEnabled();
        return androidPermissions ?? false;
      }

      return false;
    } catch (e) {
      return false;
    }
  }

  void _onNotificationTapped(NotificationResponse response) {
    // Handle notification taps here if needed
  }
}