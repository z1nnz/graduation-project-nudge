// Offline preview of the whole App shell (real theme, navigation and pages)
// with example data, for screenshots: acceptance evidence and the project
// brief. It never initialises Firebase and writes nothing to Cloud.
//
//   flutter build web -t tool/cabin_art/preview_main.dart -o build/cabin_preview
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:nudge/main.dart';
import 'package:nudge/models/avatar_profile.dart';
import 'package:nudge/models/daily_summary.dart';
import 'package:nudge/models/study_room_models.dart';
import 'package:shared_preferences/shared_preferences.dart';

String _key(DateTime d) =>
    '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

StudyMemberData _member(String id, String nick, StudyMemberStatus status, int face) =>
    StudyMemberData(
      memberId: id,
      name: nick,
      roomNickname: nick,
      status: status,
      sessionSeconds: 900,
      todayFocusSeconds: 3600,
      avatarColor: const Color(0xFF7C6AE6),
      avatarProfile: AvatarProfile.initial().copyWith(faceShapeIndex: face),
    );

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final today = DateTime.now();
  final room = StudyRoomData(
    id: 'preview-room',
    name: '期末衝刺自習室',
    description: '每天一起讀 2 小時',
    accentColor: const Color(0xFF7C6AE6),
    members: [
      _member('local_user', '我', StudyMemberStatus.studying, 0),
      _member('a', '小艾', StudyMemberStatus.studying, 3),
      _member('b', '阿哲', StudyMemberStatus.resting, 6),
      _member('c', '林林', StudyMemberStatus.studying, 15),
      _member('d', '小宇', StudyMemberStatus.offline, 9),
    ],
  );
  // This preview runs on in-memory example data on purpose, so it never
  // touches a real account or browser storage.
  // ignore: invalid_use_of_visible_for_testing_member
  SharedPreferences.setMockInitialValues({
    'onboarding_completed_setting': true,
    'discipline_coins_setting': 128,
    'unlocked_avatar_items_setting': ['homeDecor:101'],
    'study_rooms_setting': jsonEncode([room.toJson()]),
    'dailySummaries': jsonEncode([
      for (var i = 1; i <= 9; i++)
        DailySummary(
          date: _key(today.subtract(Duration(days: i))),
          completedTasks: 3,
          totalTasks: 4,
          focusMinutes: 40,
          sleepHours: 7,
          steps: 6000,
          exerciseMinutes: 20,
          disciplineScore: 78,
        ).toJson(),
    ]),
  });
  runApp(const NudgeApp());
}
