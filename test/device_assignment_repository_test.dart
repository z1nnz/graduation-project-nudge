import 'package:flutter_test/flutter_test.dart';
import 'package:nudge/models/device_assignment.dart';
import 'package:nudge/services/firestore_device_assignment_repository.dart';

Map<String, dynamic> assignment({
  String deviceId = 'nudge-a1b2c3',
  String userId = 'alice',
  String status = 'active',
}) => {
  'schemaVersion': 1,
  'assignmentId': deviceId,
  'deviceId': deviceId,
  'assignedUserId': userId,
  'status': status,
  'allowedRoomIds': ['room-study'],
  'validFrom': '2026-08-15T10:00:00.000Z',
  'validUntil': null,
  'updatedAt': '2026-08-15T10:00:00.000Z',
};

void main() {
  test('repository resolves one account-scoped canonical assignment', () async {
    final repository = FirestoreDeviceAssignmentRepository.withReader(
      (deviceId) async => assignment(),
    );

    final grant = await repository.resolve(
      deviceId: 'nudge-a1b2c3',
      currentUserId: 'alice',
    );

    expect(grant?.deviceId, 'nudge-a1b2c3');
    expect(grant?.userId, 'alice');
    expect(grant?.allowedRoomIds, ['room-study']);
  });

  test(
    'repository rejects another account or a malformed assignment',
    () async {
      final otherAccount = FirestoreDeviceAssignmentRepository.withReader(
        (_) async => assignment(userId: 'bob'),
      );
      final malformed = FirestoreDeviceAssignmentRepository.withReader(
        (_) async => {
          ...assignment(),
          'allowedRoomIds': ['room-study', 'room-study'],
        },
      );

      await expectLater(
        otherAccount.resolve(deviceId: 'nudge-a1b2c3', currentUserId: 'alice'),
        throwsA(isA<DeviceAssignmentException>()),
      );
      await expectLater(
        malformed.resolve(deviceId: 'nudge-a1b2c3', currentUserId: 'alice'),
        throwsA(isA<DeviceAssignmentException>()),
      );
    },
  );

  test('revoked assignment remains parseable but cannot grant activity', () {
    final parsed = DeviceAssignment.fromMap(
      assignment(status: 'revoked'),
      expectedDeviceId: 'nudge-a1b2c3',
      expectedUserId: 'alice',
    );

    expect(parsed.status, DeviceAssignmentStatus.revoked);
    expect(parsed.toGrant().isActive, isFalse);
  });

  test('canonical assignment rejects a non-Nudge device identifier', () {
    expect(
      () => DeviceAssignment.fromMap(
        assignment(deviceId: 'desk-one', userId: 'alice'),
        expectedDeviceId: 'desk-one',
        expectedUserId: 'alice',
      ),
      throwsFormatException,
    );
  });
}
