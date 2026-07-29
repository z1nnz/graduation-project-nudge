import 'package:cloud_functions/cloud_functions.dart';

import '../models/notification_preferences.dart';

typedef NotificationPreferenceCallable =
    Future<Object?> Function(Map<String, dynamic> payload);

class NotificationPreferenceException implements Exception {
  const NotificationPreferenceException(this.code, this.message);

  final String code;
  final String message;

  @override
  String toString() => 'NotificationPreferenceException($code): $message';
}

class CloudNotificationPreferenceGateway {
  const CloudNotificationPreferenceGateway.withCallable(
    NotificationPreferenceCallable call,
  ) : _call = call;

  final NotificationPreferenceCallable _call;

  factory CloudNotificationPreferenceGateway.firebase({
    FirebaseFunctions? functions,
  }) {
    return CloudNotificationPreferenceGateway.withCallable((payload) async {
      final callable =
          (functions ?? FirebaseFunctions.instanceFor(region: 'asia-east1'))
              .httpsCallable('updateNotificationPreferences');
      final response = await callable.call<dynamic>(payload);
      return response.data;
    });
  }

  Future<NotificationPreferenceUpdateResult> update({
    required Map<String, NotificationChannelPreference> channels,
    required String clientRequestId,
    String sourceSurface = 'app',
  }) async {
    if (!supportedNotificationChannelKeys.containsAll(channels.keys) ||
        !channels.keys.toSet().containsAll(supportedNotificationChannelKeys)) {
      throw const NotificationPreferenceException(
        'invalid-argument',
        '通知設定必須包含所有支援的提醒種類。',
      );
    }
    try {
      final response = await _call({
        'channels': channels.map((key, value) => MapEntry(key, value.toMap())),
        'clientRequestId': clientRequestId,
        'sourceSurface': sourceSurface,
      });
      if (response is! Map) {
        throw const NotificationPreferenceException(
          'protocol-error',
          '通知設定服務回傳了無效資料。',
        );
      }
      final result = NotificationPreferenceUpdateResult.fromMap(
        response.map((key, value) => MapEntry(key.toString(), value)),
      );
      if (result.auditEventId.isEmpty ||
          !result.preferences.hasCompleteChannelSet) {
        throw const NotificationPreferenceException(
          'protocol-error',
          '通知設定結果缺少必要的稽核資料。',
        );
      }
      return result;
    } on FirebaseFunctionsException catch (error) {
      throw NotificationPreferenceException(
        error.code,
        error.message ?? '無法更新通知設定。',
      );
    }
  }
}
