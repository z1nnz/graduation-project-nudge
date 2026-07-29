import 'package:flutter_test/flutter_test.dart';
import 'package:nudge/models/notification_preferences.dart';
import 'package:nudge/services/cloud_notification_preference_gateway.dart';

Map<String, dynamic> preferenceResponse() => {
  'replayed': false,
  'auditEventId': 'notification-preferences--user--request',
  'preferences': {
    'schemaVersion': notificationPreferenceSchemaVersion,
    'userId': 'user-one',
    'channels': {
      'tasks': {'enabled': true, 'timeLabel': '20:30'},
      'sleep': {'enabled': true, 'timeLabel': '23:00'},
      'rooms': {'enabled': false, 'timeLabel': '19:30'},
      'deadline': {'enabled': true, 'timeLabel': '09:00'},
    },
    'delivery': {
      'localScheduled': true,
      'inApp': true,
      'pushConfigured': false,
    },
    'updatedAt': '2026-07-29T01:00:00.000Z',
  },
};

void main() {
  test('notification preferences require a complete channel set', () {
    final record = NotificationPreferenceRecord.fromMap(
      Map<String, dynamic>.from(preferenceResponse()['preferences'] as Map),
    );

    expect(record.hasCompleteChannelSet, true);
    expect(record.channels['rooms']?.enabled, false);
    expect(record.pushConfigured, false);
  });

  test('gateway sends all channels and validates the audit result', () async {
    Map<String, dynamic>? captured;
    final gateway = CloudNotificationPreferenceGateway.withCallable((
      payload,
    ) async {
      captured = payload;
      return preferenceResponse();
    });

    final result = await gateway.update(
      channels: {
        for (final entry
            in (preferenceResponse()['preferences'] as Map)['channels'].entries)
          entry.key.toString(): NotificationChannelPreference.fromMap(
            Map<String, dynamic>.from(entry.value as Map),
          ),
      },
      clientRequestId: 'notification-request-001',
    );

    expect(captured?['sourceSurface'], 'app');
    expect((captured?['channels'] as Map).length, 4);
    expect(result.preferences.inApp, true);
  });
}
