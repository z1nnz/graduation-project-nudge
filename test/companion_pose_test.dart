import 'package:flutter_test/flutter_test.dart';
import 'package:nudge/models/companion_pose.dart';
import 'package:nudge/models/study_room_models.dart';

void main() {
  final noon = DateTime(2026, 11, 23, 12);
  final night = DateTime(2026, 11, 23, 23);

  test('celebration wins over every other state', () {
    expect(
      CompanionPose.resolve(now: night, focusing: true, celebrating: true),
      CompanionPose.cheer,
    );
  });

  test('focusing reads, or exercises in an exercise room', () {
    expect(CompanionPose.resolve(now: night, focusing: true), CompanionPose.read);
    expect(
      CompanionPose.resolve(
        now: noon,
        focusing: true,
        roomType: StudyRoomType.exercise,
      ),
      CompanionPose.exercise,
    );
  });

  test('night or resting sleeps, otherwise idle', () {
    expect(CompanionPose.resolve(now: night), CompanionPose.sleep);
    expect(CompanionPose.resolve(now: DateTime(2026, 11, 23, 5, 59)), CompanionPose.sleep);
    expect(CompanionPose.resolve(now: DateTime(2026, 11, 23, 6)), CompanionPose.idle);
    expect(CompanionPose.resolve(now: noon, resting: true), CompanionPose.sleep);
    expect(CompanionPose.resolve(now: noon), CompanionPose.idle);
  });

  test('room member status maps to a pose', () {
    expect(CompanionPose.forMember(StudyMemberStatus.studying, StudyRoomType.study), CompanionPose.read);
    expect(CompanionPose.forMember(StudyMemberStatus.studying, StudyRoomType.exercise), CompanionPose.exercise);
    expect(CompanionPose.forMember(StudyMemberStatus.studying, StudyRoomType.sleep), CompanionPose.sleep);
    expect(CompanionPose.forMember(StudyMemberStatus.resting, StudyRoomType.study), CompanionPose.sleep);
    expect(CompanionPose.forMember(StudyMemberStatus.offline, StudyRoomType.study), isNull);
  });

  test('pose art exists only for first-stage characters', () {
    expect(CompanionPose.read.assetFor(0), 'assets/avatar/poses/pose_0_read.png');
    expect(CompanionPose.sleep.assetFor(15), 'assets/avatar/poses/pose_15_sleep.png');
    expect(CompanionPose.read.assetFor(1), isNull);
    expect(CompanionPose.idle.assetFor(0), isNull);
  });
}
