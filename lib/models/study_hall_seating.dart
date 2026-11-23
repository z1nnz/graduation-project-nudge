import 'study_room_models.dart';

/// Who sits where in the study hall scene.
class StudyHallSeating {
  const StudyHallSeating({
    required this.seats,
    required this.overflow,
    required this.activeCount,
    required this.brightness,
  });

  static const capacity = 8;

  /// Seated members in seat order (front row first after the user).
  final List<StudyMemberData> seats;

  /// Approved members who did not fit in a seat.
  final int overflow;

  /// Members currently studying or resting in the room.
  final int activeCount;

  /// 0-1 share of approved members who are active; drives room lighting.
  final double brightness;

  static int _rank(StudyMemberStatus status) => switch (status) {
    StudyMemberStatus.studying => 0,
    StudyMemberStatus.resting => 1,
    StudyMemberStatus.offline => 2,
  };

  static StudyHallSeating assign(
    List<StudyMemberData> members, {
    required String myId,
  }) {
    final approved = members.where((m) => m.isApproved).toList();
    final ordered = [...approved]
      ..sort((a, b) {
        if (a.memberId == myId) return -1;
        if (b.memberId == myId) return 1;
        return _rank(a.status).compareTo(_rank(b.status));
      });
    final active = approved
        .where((m) => m.status != StudyMemberStatus.offline)
        .length;
    return StudyHallSeating(
      seats: ordered.take(capacity).toList(growable: false),
      overflow: ordered.length > capacity ? ordered.length - capacity : 0,
      activeCount: active,
      brightness: approved.isEmpty ? 0 : active / approved.length,
    );
  }
}
