import 'package:flutter_test/flutter_test.dart';
import 'package:nudge/models/user_notification.dart';
import 'package:nudge/services/cloud_user_notification_gateway.dart';

void main() {
  test('parses a Cloud-generated relationship notification', () {
    final notification = UserNotification.fromMap({
      'schemaVersion': 1,
      'notificationId': 'family-request--request-001--pending',
      'recipientUserId': 'child',
      'category': 'relationship',
      'kind': 'family_invitation',
      'sourceType': 'family_request',
      'sourceId': 'request-001',
      'actorUserId': 'guardian',
      'title': '新的家庭連結邀請',
      'body': '你收到一個邀請。',
      'route': 'guardian',
      'status': 'unread',
      'createdAt': '2026-07-29T02:00:00.000Z',
      'updatedAt': '2026-07-29T02:00:00.000Z',
    });

    expect(notification.isUnread, true);
    expect(notification.recipientUserId, 'child');
  });

  test('mark-read gateway validates notification and audit identity', () async {
    Map<String, dynamic>? captured;
    final gateway = CloudUserNotificationGateway.withCallable((payload) async {
      captured = payload;
      return {
        'replayed': false,
        'notificationId': 'family-request--request-001--pending',
        'status': 'read',
        'auditEventId': 'notification-read--child--request-001',
      };
    });

    final result = await gateway.markRead(
      'family-request--request-001--pending',
    );

    expect(captured?['notificationId'], result.notificationId);
    expect(result.status, 'read');
  });
}
