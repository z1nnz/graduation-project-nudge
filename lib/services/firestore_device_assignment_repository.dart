import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/activity_ledger.dart';
import '../models/device_assignment.dart';

typedef DeviceAssignmentDocumentReader =
    Future<Map<String, dynamic>?> Function(String deviceId);

class DeviceAssignmentException implements Exception {
  const DeviceAssignmentException(this.message);

  final String message;

  @override
  String toString() => 'DeviceAssignmentException: $message';
}

class FirestoreDeviceAssignmentRepository {
  const FirestoreDeviceAssignmentRepository.withReader(this._readDocument);

  factory FirestoreDeviceAssignmentRepository.firebase({
    FirebaseFirestore? firestore,
  }) {
    final db = firestore ?? FirebaseFirestore.instance;
    return FirestoreDeviceAssignmentRepository.withReader((deviceId) async {
      final snapshot = await db
          .collection('device_assignments')
          .doc(deviceId)
          .get();
      return snapshot.exists ? snapshot.data() : null;
    });
  }

  final DeviceAssignmentDocumentReader _readDocument;

  Future<DeviceAssignmentGrant?> resolve({
    required String deviceId,
    required String currentUserId,
  }) async {
    final normalizedDeviceId = deviceId.trim();
    final normalizedUserId = currentUserId.trim();
    if (normalizedDeviceId.isEmpty || normalizedUserId.isEmpty) {
      throw const DeviceAssignmentException('裝置與登入帳號識別不可為空白。');
    }
    try {
      final data = await _readDocument(normalizedDeviceId);
      if (data == null) return null;
      return DeviceAssignment.fromMap(
        data,
        expectedDeviceId: normalizedDeviceId,
        expectedUserId: normalizedUserId,
      ).toGrant();
    } catch (error) {
      if (error is DeviceAssignmentException) rethrow;
      throw const DeviceAssignmentException('Cloud 裝置指派不存在、已失效或不屬於目前帳號。');
    }
  }
}
