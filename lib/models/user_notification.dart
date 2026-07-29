import 'package:cloud_firestore/cloud_firestore.dart';

DateTime? _parseUserNotificationTimestamp(Object? value) {
  if (value is Timestamp) return value.toDate();
  if (value is DateTime) return value;
  return DateTime.tryParse(value?.toString() ?? '');
}

class UserNotification {
  const UserNotification({
    required this.id,
    required this.recipientUserId,
    required this.category,
    required this.kind,
    required this.sourceType,
    required this.sourceId,
    required this.actorUserId,
    required this.title,
    required this.body,
    required this.route,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
    required this.readAt,
  });

  final String id;
  final String recipientUserId;
  final String category;
  final String kind;
  final String sourceType;
  final String sourceId;
  final String actorUserId;
  final String title;
  final String body;
  final String route;
  final String status;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final DateTime? readAt;

  bool get isUnread => status == 'unread';
  bool get isResolved => status == 'resolved';

  factory UserNotification.fromMap(
    Map<String, dynamic> map, {
    String? documentId,
  }) {
    if ((map['schemaVersion'] as num?)?.toInt() != 1) {
      throw const FormatException('Unsupported user notification schema');
    }
    final id = documentId ?? map['notificationId']?.toString() ?? '';
    final recipientUserId = map['recipientUserId']?.toString() ?? '';
    final title = map['title']?.toString() ?? '';
    if (id.isEmpty || recipientUserId.isEmpty || title.isEmpty) {
      throw const FormatException('Incomplete user notification');
    }
    return UserNotification(
      id: id,
      recipientUserId: recipientUserId,
      category: map['category']?.toString() ?? '',
      kind: map['kind']?.toString() ?? '',
      sourceType: map['sourceType']?.toString() ?? '',
      sourceId: map['sourceId']?.toString() ?? '',
      actorUserId: map['actorUserId']?.toString() ?? '',
      title: title,
      body: map['body']?.toString() ?? '',
      route: map['route']?.toString() ?? '',
      status: map['status']?.toString() ?? 'unread',
      createdAt: _parseUserNotificationTimestamp(map['createdAt']),
      updatedAt: _parseUserNotificationTimestamp(map['updatedAt']),
      readAt: _parseUserNotificationTimestamp(map['readAt']),
    );
  }
}

class MarkNotificationReadResult {
  const MarkNotificationReadResult({
    required this.notificationId,
    required this.status,
    required this.auditEventId,
    required this.replayed,
  });

  final String notificationId;
  final String status;
  final String auditEventId;
  final bool replayed;

  factory MarkNotificationReadResult.fromMap(Map<String, dynamic> map) {
    return MarkNotificationReadResult(
      notificationId: map['notificationId']?.toString() ?? '',
      status: map['status']?.toString() ?? '',
      auditEventId: map['auditEventId']?.toString() ?? '',
      replayed: map['replayed'] as bool? ?? false,
    );
  }
}
