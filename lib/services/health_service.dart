import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

enum HealthDataProvider { appleHealth, healthConnect, unsupported }

class HealthPlatformStatus {
  final HealthDataProvider provider;
  final String title;
  final String description;

  const HealthPlatformStatus({
    required this.provider,
    required this.title,
    required this.description,
  });

  bool get isSupported => provider != HealthDataProvider.unsupported;
}

class HealthServiceResult {
  final bool success;
  final String message;
  final double sleepHours;
  final int steps;
  final int exerciseMinutes;

  const HealthServiceResult({
    required this.success,
    required this.message,
    required this.sleepHours,
    required this.steps,
    required this.exerciseMinutes,
  });

  factory HealthServiceResult.fromMap(Map<String, dynamic> map) {
    return HealthServiceResult(
      success: map['success'] as bool? ?? false,
      message: map['message'] as String? ?? '',
      sleepHours: (map['sleepHours'] as num?)?.toDouble() ?? 0.0,
      steps: (map['steps'] as num?)?.toInt() ?? 0,
      exerciseMinutes: (map['exerciseMinutes'] as num?)?.toInt() ?? 0,
    );
  }
}

class HealthService {
  static const MethodChannel _channel = MethodChannel('nudge/healthkit');

  static HealthPlatformStatus get platformStatus {
    switch (defaultTargetPlatform) {
      case TargetPlatform.iOS:
        return const HealthPlatformStatus(
          provider: HealthDataProvider.appleHealth,
          title: 'Apple 健康',
          description: 'iPhone 會讀取 Apple 健康中的睡眠、步數與運動資料。',
        );
      case TargetPlatform.android:
        return const HealthPlatformStatus(
          provider: HealthDataProvider.healthConnect,
          title: 'Health Connect',
          description: 'Android 會讀取 Health Connect 中的睡眠、步數與運動資料。',
        );
      case TargetPlatform.fuchsia:
      case TargetPlatform.linux:
      case TargetPlatform.macOS:
      case TargetPlatform.windows:
        return const HealthPlatformStatus(
          provider: HealthDataProvider.unsupported,
          title: '此平台不支援健康同步',
          description: '健康資料同步目前只支援 iOS 與 Android 手機。',
        );
    }
  }

  static Future<bool> requestHealthPermission() async {
    if (!platformStatus.isSupported) return false;
    try {
      final bool? granted = await _channel
          .invokeMethod<bool>('requestHealthAuthorization')
          .timeout(const Duration(seconds: 10));
      return granted ?? false;
    } catch (e) {
      debugPrint('requestHealthPermission error: $e');
      return false;
    }
  }

  static Future<HealthServiceResult> syncHealthData() async {
    final status = platformStatus;
    if (!status.isSupported) {
      return HealthServiceResult(
        success: false,
        message: status.description,
        sleepHours: 0,
        steps: 0,
        exerciseMinutes: 0,
      );
    }

    try {
      final result = await _channel
          .invokeMapMethod<String, dynamic>('getHealthData')
          .timeout(const Duration(seconds: 10));

      if (result == null) {
        return const HealthServiceResult(
          success: false,
          message: '沒有取得資料',
          sleepHours: 0,
          steps: 0,
          exerciseMinutes: 0,
        );
      }

      return HealthServiceResult.fromMap(result);
    } catch (e) {
      debugPrint('syncHealthData error: $e');
      return HealthServiceResult(
        success: false,
        message: '同步失敗：$e',
        sleepHours: 0,
        steps: 0,
        exerciseMinutes: 0,
      );
    }
  }

  static Future<bool> requestAppleHealthPermission() {
    return requestHealthPermission();
  }

  static Future<HealthServiceResult> syncAppleHealthData() {
    return syncHealthData();
  }
}
