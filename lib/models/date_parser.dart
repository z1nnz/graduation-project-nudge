import 'package:cloud_firestore/cloud_firestore.dart';

DateTime? parseDateTime(dynamic value) {
  if (value == null) return null;
  if (value is DateTime) return value;
  if (value is String) return DateTime.tryParse(value);
  if (value is Timestamp) return value.toDate();
  try {
    if (value is Map && value['_seconds'] != null) {
      return DateTime.fromMillisecondsSinceEpoch(
        (value['_seconds'] as int) * 1000 +
            ((value['_nanoseconds'] as int) / 1000000).round(),
      );
    }
    // Try calling toDate dynamic function if object runtime matches
    return (value as dynamic).toDate() as DateTime;
  } catch (_) {}
  return null;
}
