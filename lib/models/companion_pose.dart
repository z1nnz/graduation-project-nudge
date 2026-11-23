import 'study_room_models.dart';

/// What the companion character is doing right now.
enum CompanionPose {
  idle,
  walk,
  read,
  sleep,
  exercise,
  cheer;

  /// First-stage characters (one per series) have generated pose art.
  static const poseArtIndexes = {0, 3, 6, 9, 12, 15};

  static const _nightStartHour = 22;
  static const _nightEndHour = 6;

  /// Pose for the signed-in user's own companion. A new Cloud-confirmed
  /// result (celebrating) wins, then an active session, then rest or night.
  static CompanionPose resolve({
    required DateTime now,
    bool focusing = false,
    bool resting = false,
    bool celebrating = false,
    StudyRoomType? roomType,
  }) {
    if (celebrating) return CompanionPose.cheer;
    if (focusing) {
      return roomType == StudyRoomType.exercise
          ? CompanionPose.exercise
          : CompanionPose.read;
    }
    final night = now.hour >= _nightStartHour || now.hour < _nightEndHour;
    if (resting || night) return CompanionPose.sleep;
    return CompanionPose.idle;
  }

  /// Pose for a study-room member; offline members have no character shown.
  static CompanionPose? forMember(StudyMemberStatus status, StudyRoomType type) {
    switch (status) {
      case StudyMemberStatus.offline:
        return null;
      case StudyMemberStatus.resting:
        return CompanionPose.sleep;
      case StudyMemberStatus.studying:
        switch (type) {
          case StudyRoomType.exercise:
          case StudyRoomType.steps:
            return CompanionPose.exercise;
          case StudyRoomType.sleep:
            return CompanionPose.sleep;
          case StudyRoomType.study:
          case StudyRoomType.custom:
            return CompanionPose.read;
        }
    }
  }

  /// Generated pose art, or null when the character uses its base sprite
  /// with code-drawn motion instead.
  String? assetFor(int faceShapeIndex) {
    if (this == CompanionPose.idle ||
        this == CompanionPose.walk ||
        !poseArtIndexes.contains(faceShapeIndex)) {
      return null;
    }
    return 'assets/avatar/poses/pose_${faceShapeIndex}_$name.png';
  }

  /// Two-step walk frames for first-stage characters, or null to fall back
  /// to the base sprite with code-drawn steps.
  static List<String>? walkFrames(int faceShapeIndex) {
    if (!poseArtIndexes.contains(faceShapeIndex)) return null;
    final pass = 'assets/avatar/poses/walk_${faceShapeIndex}_p.png';
    // Step, legs passing, other step, legs passing: a smooth 4-frame cycle.
    return [
      'assets/avatar/poses/walk_${faceShapeIndex}_a.png',
      pass,
      'assets/avatar/poses/walk_${faceShapeIndex}_b.png',
      pass,
    ];
  }

  /// The frame shown at [phase] (0–1 per full cycle; wraps around).
  static T walkFrameAt<T>(List<T> frames, double phase) {
    final wrapped = phase - phase.floorToDouble();
    return frames[(wrapped * frames.length).floor() % frames.length];
  }
}
