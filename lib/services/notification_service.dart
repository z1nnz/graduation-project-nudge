import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

class LocalReminderRequest {
  final String channelKey;
  final String title;
  final String body;
  final String timeLabel;

  const LocalReminderRequest({
    required this.channelKey,
    required this.title,
    required this.body,
    required this.timeLabel,
  });
}

class NotificationService {
  static final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  static bool _initialized = false;
  static void Function(String payload)? _payloadHandler;
  static String? _pendingPayload;

  static void setPayloadHandler(void Function(String payload) handler) {
    _payloadHandler = handler;
    final pending = _pendingPayload;
    if (pending != null) {
      _pendingPayload = null;
      handler(pending);
    }
  }

  static void _handlePayload(String? payload) {
    final normalized = payload?.trim() ?? '';
    if (normalized.isEmpty) return;
    final handler = _payloadHandler;
    if (handler == null) {
      _pendingPayload = normalized;
    } else {
      handler(normalized);
    }
  }

  static Future<void> initialize() async {
    if (_initialized || kIsWeb) return;

    try {
      tz_data.initializeTimeZones();
      final localName = DateTime.now().timeZoneName;
      if (localName.isNotEmpty) {
        try {
          tz.setLocalLocation(tz.getLocation(localName));
        } catch (_) {
          tz.setLocalLocation(tz.getLocation('Asia/Taipei'));
        }
      }

      const android = AndroidInitializationSettings('@mipmap/ic_launcher');
      const darwin = DarwinInitializationSettings(
        requestAlertPermission: false,
        requestBadgePermission: false,
        requestSoundPermission: false,
      );

      await _plugin.initialize(
        settings: const InitializationSettings(android: android, iOS: darwin),
        onDidReceiveNotificationResponse: (response) {
          _handlePayload(response.payload);
        },
      );
      final androidPlugin = _plugin
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >();
      await androidPlugin?.createNotificationChannel(
        const AndroidNotificationChannel(
          'nudge_relationship_updates',
          'Nudge 關係動態',
          description: '家庭與團體邀請、邀請結果及成員關係更新',
          importance: Importance.high,
        ),
      );
      final launchDetails = await _plugin.getNotificationAppLaunchDetails();
      if (launchDetails?.didNotificationLaunchApp == true) {
        _handlePayload(launchDetails?.notificationResponse?.payload);
      }
      _initialized = true;
    } catch (error) {
      if (!kDebugMode) {
        debugPrint('Notification init error: $error');
      }
    }
  }

  static Future<bool> requestPermission() async {
    if (kIsWeb) return false;
    await initialize();

    var granted = true;
    try {
      final android = _plugin
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >();
      final androidGranted = await android?.requestNotificationsPermission();
      if (androidGranted != null) granted = granted && androidGranted;

      final ios = _plugin
          .resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin
          >();
      final iosGranted = await ios?.requestPermissions(
        alert: true,
        badge: true,
        sound: true,
      );
      if (iosGranted != null) granted = granted && iosGranted;
    } catch (error) {
      debugPrint('Notification permission error: $error');
      return false;
    }

    return granted;
  }

  static Future<void> scheduleDailyReminders(
    List<LocalReminderRequest> requests,
  ) async {
    if (kIsWeb) return;
    await initialize();

    try {
      await _plugin.cancelAll();
      for (var i = 0; i < requests.length; i++) {
        final request = requests[i];
        final scheduledAt = _nextInstanceOfTime(request.timeLabel);
        await _plugin.zonedSchedule(
          id: _idFor(request.channelKey, i),
          title: request.title,
          body: request.body,
          scheduledDate: scheduledAt,
          notificationDetails: const NotificationDetails(
            android: AndroidNotificationDetails(
              'nudge_daily_reminders',
              'Nudge 自律提醒',
              channelDescription: '任務、睡眠、自律房與截止日提醒',
              importance: Importance.high,
              priority: Priority.high,
            ),
            iOS: DarwinNotificationDetails(),
          ),
          androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
          matchDateTimeComponents: DateTimeComponents.time,
        );
      }
    } catch (error) {
      if (!kDebugMode) {
        debugPrint('Schedule notification error: $error');
      }
    }
  }

  static Future<void> showRemoteNotification({
    required Object? notificationId,
    required String title,
    required String body,
    String? payload,
  }) async {
    if (kIsWeb) return;
    await initialize();
    final source = notificationId?.toString() ?? '$title|$body';
    var stableId = 17;
    for (final codeUnit in source.codeUnits) {
      stableId = ((stableId * 37) + codeUnit) & 0x7fffffff;
    }
    await _plugin.show(
      id: stableId,
      title: title,
      body: body,
      notificationDetails: const NotificationDetails(
        android: AndroidNotificationDetails(
          'nudge_relationship_updates',
          'Nudge 關係動態',
          channelDescription: '家庭與團體邀請、邀請結果及成員關係更新',
          importance: Importance.high,
          priority: Priority.high,
        ),
        iOS: DarwinNotificationDetails(),
      ),
      payload: payload,
    );
  }

  static tz.TZDateTime _nextInstanceOfTime(String timeLabel) {
    final parts = timeLabel.split(':');
    final hour = int.tryParse(parts.isNotEmpty ? parts[0] : '') ?? 20;
    final minute = int.tryParse(parts.length > 1 ? parts[1] : '') ?? 30;
    final now = tz.TZDateTime.now(tz.local);
    var scheduled = tz.TZDateTime(
      tz.local,
      now.year,
      now.month,
      now.day,
      hour,
      minute,
    );
    if (!scheduled.isAfter(now)) {
      scheduled = scheduled.add(const Duration(days: 1));
    }
    return scheduled;
  }

  static int _idFor(String channelKey, int index) {
    final base = switch (channelKey) {
      'tasks' => 1000,
      'sleep' => 2000,
      'rooms' => 3000,
      'deadline' => 4000,
      _ => 9000,
    };
    return base + index;
  }
}
