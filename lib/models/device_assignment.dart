import 'activity_ledger.dart';

enum DeviceAssignmentStatus { active, revoked }

final _identifierPattern = RegExp(r'^[A-Za-z0-9][A-Za-z0-9._-]{1,95}$');
final _deviceIdentifierPattern = RegExp(r'^nudge-[A-Za-z0-9._-]{2,90}$');

String _requiredIdentifier(Object? value, String field) {
  final result = value is String ? value.trim() : '';
  if (result != value || !_identifierPattern.hasMatch(result)) {
    throw FormatException('Invalid $field.');
  }
  return result;
}

String _requiredDeviceIdentifier(Object? value, String field) {
  final result = value is String ? value.trim() : '';
  if (result != value || !_deviceIdentifierPattern.hasMatch(result)) {
    throw FormatException('Invalid $field.');
  }
  return result;
}

DateTime _date(Object? value, String field) {
  if (value is DateTime) return value.toUtc();
  dynamic dynamicTimestamp = value;
  try {
    final converted = dynamicTimestamp?.toDate();
    if (converted is DateTime) return converted.toUtc();
  } catch (_) {}
  final parsed = DateTime.tryParse(value?.toString() ?? '');
  if (parsed == null) throw FormatException('Invalid $field.');
  return parsed.toUtc();
}

class DeviceAssignment {
  const DeviceAssignment({
    required this.assignmentId,
    required this.deviceId,
    required this.assignedUserId,
    required this.status,
    required this.allowedRoomIds,
    required this.validFrom,
    required this.validUntil,
    required this.updatedAt,
  });

  final String assignmentId;
  final String deviceId;
  final String assignedUserId;
  final DeviceAssignmentStatus status;
  final List<String> allowedRoomIds;
  final DateTime validFrom;
  final DateTime? validUntil;
  final DateTime updatedAt;

  factory DeviceAssignment.fromMap(
    Map<String, dynamic> map, {
    required String expectedDeviceId,
    required String expectedUserId,
  }) {
    final assignmentId = _requiredDeviceIdentifier(
      map['assignmentId'],
      'assignmentId',
    );
    final deviceId = _requiredDeviceIdentifier(map['deviceId'], 'deviceId');
    final assignedUserId = _requiredIdentifier(
      map['assignedUserId'],
      'assignedUserId',
    );
    final status = switch (map['status']) {
      'active' => DeviceAssignmentStatus.active,
      'revoked' => DeviceAssignmentStatus.revoked,
      _ => throw const FormatException('Invalid assignment status.'),
    };
    final roomValues = map['allowedRoomIds'];
    if (roomValues is! List || roomValues.length > 20) {
      throw const FormatException('Invalid allowedRoomIds.');
    }
    final roomIds = roomValues
        .map((value) => _requiredIdentifier(value, 'allowedRoomId'))
        .toList(growable: false);
    if (roomIds.toSet().length != roomIds.length) {
      throw const FormatException('Duplicate allowedRoomIds.');
    }
    final validFrom = _date(map['validFrom'], 'validFrom');
    final validUntil = map['validUntil'] == null
        ? null
        : _date(map['validUntil'], 'validUntil');
    final updatedAt = _date(map['updatedAt'], 'updatedAt');
    if (map['schemaVersion'] != 1 ||
        assignmentId != deviceId ||
        deviceId != expectedDeviceId ||
        assignedUserId != expectedUserId ||
        (validUntil != null && validUntil.isBefore(validFrom)) ||
        updatedAt.isBefore(validFrom)) {
      throw const FormatException('Invalid canonical device assignment.');
    }
    return DeviceAssignment(
      assignmentId: assignmentId,
      deviceId: deviceId,
      assignedUserId: assignedUserId,
      status: status,
      allowedRoomIds: List.unmodifiable(roomIds),
      validFrom: validFrom,
      validUntil: validUntil,
      updatedAt: updatedAt,
    );
  }

  DeviceAssignmentGrant toGrant() => DeviceAssignmentGrant(
    deviceId: deviceId,
    userId: assignedUserId,
    isActive: status == DeviceAssignmentStatus.active,
    validFrom: validFrom,
    validUntil: validUntil,
    allowedRoomIds: allowedRoomIds,
  );
}
