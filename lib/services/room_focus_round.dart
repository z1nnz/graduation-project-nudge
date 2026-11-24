import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

enum FocusRoundPhase { idle, focus, rest }

class FocusRoundState {
  const FocusRoundState(this.phase, this.remaining);
  final FocusRoundPhase phase;
  final Duration remaining;
}

/// The shared 25 + 5 room round, same maths as Web `focus_round_core.js`.
class FocusRoundClock {
  FocusRoundClock._();

  static const focus = Duration(minutes: 25);
  static const rest = Duration(minutes: 5);

  static FocusRoundState at(DateTime? startAt, DateTime now) {
    if (startAt == null) {
      return const FocusRoundState(FocusRoundPhase.idle, Duration.zero);
    }
    final focusEnd = startAt.add(focus);
    final restEnd = focusEnd.add(rest);
    Duration ceil(Duration d) =>
        Duration(seconds: (d.inMilliseconds / 1000).ceil());
    if (now.isBefore(focusEnd)) {
      return FocusRoundState(
        FocusRoundPhase.focus,
        ceil(focusEnd.difference(now)),
      );
    }
    if (now.isBefore(restEnd)) {
      return FocusRoundState(
        FocusRoundPhase.rest,
        ceil(restEnd.difference(now)),
      );
    }
    return const FocusRoundState(FocusRoundPhase.idle, Duration.zero);
  }

  static Map<String, Object?> newRound(String uid, Object startAt) => {
    'startedBy': uid,
    'startAt': startAt,
    'durationMin': 25,
    'breakMin': 5,
  };

  static String label(FocusRoundPhase phase) => switch (phase) {
    FocusRoundPhase.idle => '可以發起新一輪',
    FocusRoundPhase.focus => '一起專注中',
    FocusRoundPhase.rest => '完成這一輪，休息 5 分鐘',
  };
}

/// Live view of `rooms/{id}/focus_rounds/current`, ticking every second.
class RoomFocusRound extends ChangeNotifier {
  RoomFocusRound({required this.roomId, FirebaseFirestore? firestore})
    : _db = firestore ?? FirebaseFirestore.instance {
    _sub = _ref.snapshots().listen(
      (snapshot) {
        if (snapshot.metadata.hasPendingWrites) return;
        _startAt = (snapshot.data()?['startAt'] as Timestamp?)?.toDate();
        ready = true;
        problem = '';
        notifyListeners();
      },
      onError: (_) {
        ready = false;
        problem = '無法同步專注計時器。';
        notifyListeners();
      },
    );
    _tick = Timer.periodic(
      const Duration(seconds: 1),
      (_) => notifyListeners(),
    );
  }

  final String roomId;
  final FirebaseFirestore _db;
  late final StreamSubscription<DocumentSnapshot<Map<String, dynamic>>> _sub;
  late final Timer _tick;
  DateTime? _startAt;
  bool ready = false;
  bool busy = false;
  String problem = '';

  DocumentReference<Map<String, dynamic>> get _ref => _db
      .collection('rooms')
      .doc(roomId)
      .collection('focus_rounds')
      .doc('current');

  DateTime? get startAt => _startAt;
  FocusRoundState get state => FocusRoundClock.at(_startAt, DateTime.now());

  Future<bool> start(String uid) async {
    if (busy) return false;
    busy = true;
    problem = '';
    notifyListeners();
    try {
      await _db.runTransaction((tx) async {
        final current = await tx.get(_ref);
        final start = (current.data()?['startAt'] as Timestamp?)?.toDate();
        if (FocusRoundClock.at(start, DateTime.now()).phase !=
            FocusRoundPhase.idle) {
          throw StateError('已有一輪專注或休息正在進行。');
        }
        tx.set(
          _ref,
          FocusRoundClock.newRound(uid, FieldValue.serverTimestamp()),
        );
      });
      return true;
    } catch (error) {
      problem = error is StateError ? error.message : '無法發起新一輪，請稍後再試。';
      return false;
    } finally {
      busy = false;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _sub.cancel();
    _tick.cancel();
    super.dispose();
  }
}
