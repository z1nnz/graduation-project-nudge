import 'package:cloud_functions/cloud_functions.dart';

import '../models/user_notification.dart';

typedef UserNotificationCallable =
    Future<Object?> Function(Map<String, dynamic> payload);

class UserNotificationException implements Exception {
  const UserNotificationException(this.code, this.message);

  final String code;
  final String message;

  @override
  String toString() => 'UserNotificationException($code): $message';
}

class CloudUserNotificationGateway {
  const CloudUserNotificationGateway.withCallable(UserNotificationCallable call)
    : _call = call;

  final UserNotificationCallable _call;

  factory CloudUserNotificationGateway.firebase({
    FirebaseFunctions? functions,
  }) {
    return CloudUserNotificationGateway.withCallable((payload) async {
      final callable =
          (functions ?? FirebaseFunctions.instanceFor(region: 'asia-east1'))
              .httpsCallable('markNotificationRead');
      final response = await callable.call<dynamic>(payload);
      return response.data;
    });
  }

  Future<MarkNotificationReadResult> markRead(String notificationId) async {
    try {
      final response = await _call({'notificationId': notificationId});
      if (response is! Map) {
        throw const UserNotificationException(
          'protocol-error',
          '站內通知服務回傳了無效資料。',
        );
      }
      final result = MarkNotificationReadResult.fromMap(
        response.map((key, value) => MapEntry(key.toString(), value)),
      );
      if (result.notificationId != notificationId ||
          result.status != 'read' ||
          result.auditEventId.isEmpty) {
        throw const UserNotificationException(
          'protocol-error',
          '站內通知已讀結果無法驗證。',
        );
      }
      return result;
    } on FirebaseFunctionsException catch (error) {
      throw UserNotificationException(error.code, error.message ?? '無法更新站內通知。');
    }
  }
}
