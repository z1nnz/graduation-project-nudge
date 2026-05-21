import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';

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

  static Future<bool> requestHealthPermission() async {
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
