import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/room_activity_session.dart';

abstract interface class RoomActivityProjectionGateway {
  Future<void> persistStarted({
    required String userId,
    required RoomActivitySession session,
  });

  Future<void> persistTransition({
    required String userId,
    required RoomActivitySession session,
  });
}

class FirestoreRoomActivityProjectionGateway
    implements RoomActivityProjectionGateway {
  FirestoreRoomActivityProjectionGateway({FirebaseFirestore? firestore})
    : _firestore = firestore;

  final FirebaseFirestore? _firestore;

  FirebaseFirestore get _db => _firestore ?? FirebaseFirestore.instance;

  @override
  Future<void> persistStarted({
    required String userId,
    required RoomActivitySession session,
  }) async {
    final roomRef = _db.collection('rooms').doc(session.roomId);
    final batch = _db.batch();
    batch.update(roomRef.collection('members').doc(userId), {
      'activeSessionId': session.sessionId,
      'updatedAt': session.updatedAt.toIso8601String(),
    });
    batch.set(
      roomRef.collection('activity_sessions').doc(session.sessionId),
      session.toJson(),
    );
    await batch.commit();
  }

  @override
  Future<void> persistTransition({
    required String userId,
    required RoomActivitySession session,
  }) async {
    final roomRef = _db.collection('rooms').doc(session.roomId);
    final sessionRef = roomRef
        .collection('activity_sessions')
        .doc(session.sessionId);
    if (!session.isTerminal) {
      await sessionRef.set(session.toJson());
      return;
    }
    final batch = _db.batch();
    batch.update(roomRef.collection('members').doc(userId), {
      'activeSessionId': null,
      'updatedAt': session.updatedAt.toIso8601String(),
    });
    batch.set(sessionRef, session.toJson());
    await batch.commit();
  }
}
