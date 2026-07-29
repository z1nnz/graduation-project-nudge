import 'package:cloud_firestore/cloud_firestore.dart';

const notificationPreferenceSchemaVersion = 1;
const supportedNotificationChannelKeys = <String>{
  'tasks',
  'sleep',
  'rooms',
  'deadline',
};

DateTime? _parseNotificationTimestamp(Object? value) {
  if (value is Timestamp) return value.toDate();
  if (value is DateTime) return value;
  return DateTime.tryParse(value?.toString() ?? '');
}

class NotificationChannelPreference {
  const NotificationChannelPreference({
    required this.enabled,
    required this.timeLabel,
  });

  final bool enabled;
  final String timeLabel;

  Map<String, dynamic> toMap() => {'enabled': enabled, 'timeLabel': timeLabel};

  factory NotificationChannelPreference.fromMap(Map<String, dynamic> map) {
    final enabled = map['enabled'];
    final timeLabel = map['timeLabel']?.toString() ?? '';
    if (enabled is! bool ||
        !RegExp(r'^(?:[01]\d|2[0-3]):[0-5]\d$').hasMatch(timeLabel)) {
      throw const FormatException('Invalid notification channel preference');
    }
    return NotificationChannelPreference(
      enabled: enabled,
      timeLabel: timeLabel,
    );
  }
}

class NotificationPreferenceRecord {
  const NotificationPreferenceRecord({
    required this.userId,
    required this.channels,
    required this.localScheduled,
    required this.inApp,
    required this.pushConfigured,
    required this.updatedAt,
  });

  final String userId;
  final Map<String, NotificationChannelPreference> channels;
  final bool localScheduled;
  final bool inApp;
  final bool pushConfigured;
  final DateTime? updatedAt;

  bool get hasCompleteChannelSet =>
      channels.keys.toSet().containsAll(supportedNotificationChannelKeys) &&
      supportedNotificationChannelKeys.containsAll(channels.keys);

  factory NotificationPreferenceRecord.fromMap(Map<String, dynamic> map) {
    if ((map['schemaVersion'] as num?)?.toInt() !=
        notificationPreferenceSchemaVersion) {
      throw const FormatException('Unsupported notification preference schema');
    }
    final rawChannels = Map<String, dynamic>.from(
      map['channels'] as Map? ?? const <String, dynamic>{},
    );
    final parsedChannels = rawChannels.map(
      (key, value) => MapEntry(
        key,
        NotificationChannelPreference.fromMap(
          Map<String, dynamic>.from(value as Map? ?? const {}),
        ),
      ),
    );
    final delivery = Map<String, dynamic>.from(
      map['delivery'] as Map? ?? const <String, dynamic>{},
    );
    final record = NotificationPreferenceRecord(
      userId: map['userId']?.toString() ?? '',
      channels: Map.unmodifiable(parsedChannels),
      localScheduled: delivery['localScheduled'] as bool? ?? false,
      inApp: delivery['inApp'] as bool? ?? false,
      pushConfigured: delivery['pushConfigured'] as bool? ?? false,
      updatedAt: _parseNotificationTimestamp(map['updatedAt']),
    );
    if (!record.hasCompleteChannelSet) {
      throw const FormatException('Incomplete notification channel set');
    }
    return record;
  }
}

class NotificationPreferenceUpdateResult {
  const NotificationPreferenceUpdateResult({
    required this.preferences,
    required this.auditEventId,
    required this.replayed,
  });

  final NotificationPreferenceRecord preferences;
  final String auditEventId;
  final bool replayed;

  factory NotificationPreferenceUpdateResult.fromMap(Map<String, dynamic> map) {
    return NotificationPreferenceUpdateResult(
      preferences: NotificationPreferenceRecord.fromMap(
        Map<String, dynamic>.from(
          map['preferences'] as Map? ?? const <String, dynamic>{},
        ),
      ),
      auditEventId: map['auditEventId']?.toString() ?? '',
      replayed: map['replayed'] as bool? ?? false,
    );
  }
}
