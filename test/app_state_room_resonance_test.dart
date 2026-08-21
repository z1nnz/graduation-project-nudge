import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nudge/models/room_resonance.dart';
import 'package:nudge/models/study_room_models.dart';
import 'package:nudge/models/task_model.dart';
import 'package:nudge/models/user_model.dart';
import 'package:nudge/services/cloud_room_resonance_gateway.dart';
import 'package:nudge/state/app_state.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('room resonance remains durable-first in AppState', () async {
    // Keep the fixture active regardless of the calendar date on CI.
    final now = DateTime.now().toUtc();
    final user = UserModel(
      id: 'alice',
      username: 'alice',
      nickname: 'Alice',
      signature: '',
      createdAt: now,
      updatedAt: now,
    );
    final room = StudyRoomData(
      id: 'room-study',
      name: '同行讀書房',
      description: '',
      accentColor: const Color(0xFF7C6AE6),
      ownerId: user.id,
      ownerName: user.nickname,
      roomType: StudyRoomType.study,
      goalSourceType: TaskSourceType.focusMinutes,
      dailyGoalValue: 25,
      goalUnitLabel: '分鐘',
      members: [
        StudyMemberData(
          memberId: user.id,
          name: user.nickname,
          roomNickname: user.nickname,
          status: StudyMemberStatus.offline,
          sessionSeconds: 0,
          todayFocusSeconds: 0,
          avatarColor: const Color(0xFF7C6AE6),
          role: 'owner',
        ),
      ],
    );
    SharedPreferences.setMockInitialValues({
      'current_user_setting': jsonEncode(user.toJson()),
      'study_rooms_setting': jsonEncode([room.toJson()]),
    });
    var reject = false;
    final gateway = CloudRoomResonanceGateway.withCallable((payload) async {
      if (reject) throw StateError('Cloud unavailable');
      if (payload['action'] == 'set_preference') {
        return {
          'preference': {
            'schemaVersion': 1,
            'preferenceId': 'room-study--alice',
            'roomId': 'room-study',
            'userId': 'alice',
            'enabled': payload['enabled'],
            'audience': 'room_members_only',
            'shareMode': 'cue_only',
            'updatedAt': now.toIso8601String(),
          },
        };
      }
      return {
        'signal': {
          'schemaVersion': 1,
          'signalId': 'room-study--alice',
          'roomId': 'room-study',
          'ownerUserId': 'alice',
          'generationId': payload['clientRequestId'],
          'cueKey': payload['cueKey'],
          'status': 'active',
          'visibility': 'room_members_only',
          'acknowledgementCount': 0,
          'createdAt': now.toIso8601String(),
          'updatedAt': now.toIso8601String(),
          'expiresAt': now.add(const Duration(hours: 24)).toIso8601String(),
          'withdrawnAt': null,
        },
      };
    });
    final appState = AppState(roomResonanceGateway: gateway);
    await appState.loadAllLocalData();

    await appState.setRoomResonanceSharing(roomId: room.id, enabled: true);
    await appState.publishRoomResonance(
      roomId: room.id,
      cue: RoomResonanceCue.gentleRestart,
    );
    expect(appState.roomResonanceSharingEnabled(room.id), isTrue);
    expect(
      appState.myRoomResonanceSignal(room.id)?.cue,
      RoomResonanceCue.gentleRestart,
    );

    reject = true;
    await expectLater(
      appState.setRoomResonanceSharing(roomId: room.id, enabled: false),
      throwsA(isA<RoomResonanceException>()),
    );
    expect(appState.roomResonanceSharingEnabled(room.id), isTrue);
    expect(appState.myRoomResonanceSignal(room.id), isNotNull);
  });
}
