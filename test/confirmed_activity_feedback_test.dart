import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:nudge/models/confirmed_activity_feedback.dart';

void main() {
  final fixtures =
      jsonDecode(
            File(
              'test/fixtures/confirmed_activity_feedback.json',
            ).readAsStringSync(),
          )
          as List;
  for (final fixture in fixtures) {
    test('receipt feedback: ${fixture['name']}', () {
      final result = ConfirmedActivityFeedback.parse('receipt-1', {
        'receiptId': 'receipt-1',
        'actorUserId': 'user-1',
        'activityType': 'focus',
        'acceptedMetric': 25,
        'verifiedAt': '2026-11-22T06:00:00.000Z',
        ...Map<String, dynamic>.from(fixture['patch'] as Map),
      }, 'user-1');
      expect(result != null, fixture['valid']);
      if (result != null) expect(result.label, fixture['label']);
    });
  }
}
