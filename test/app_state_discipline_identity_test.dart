import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:nudge/models/discipline_identity_snapshot.dart';
import 'package:nudge/models/user_model.dart';
import 'package:nudge/services/cloud_discipline_identity_gateway.dart';
import 'package:nudge/state/app_state.dart';
import 'package:shared_preferences/shared_preferences.dart';

Map<String, dynamic> snapshotResponse(String userId) => {
  'snapshot': {
    'schemaVersion': 1,
    'snapshotId': userId,
    'userId': userId,
    'visibility': 'private',
    'window': {
      'days': 28,
      'startedAt': '2026-07-18T21:00:00.000Z',
      'endedAt': '2026-08-15T10:00:00.000Z',
    },
    'persona': {
      'key': 'comeback_builder',
      'title': '復原建築師',
      'description': '中斷後仍願意重新開始。',
    },
    'recovery': {
      'state': 'returning',
      'recommendedFocusMinutes': 15,
      'message': '今天再完成一個小段落就足夠。',
    },
    'metrics': {
      'activeDays': 4,
      'completedSessions': 7,
      'focusMinutes': 120,
      'exerciseMinutes': 30,
      'activityKinds': ['exercise', 'focus'],
      'lastActiveDay': '2026-08-15',
    },
    'updatedAt': '2026-08-15T10:00:00.000Z',
  },
};

void main() {
  test('AppState retains the Cloud-validated discipline identity', () async {
    final now = DateTime.now();
    final user = UserModel(
      id: 'identity-user-1',
      username: 'identity-user-1',
      nickname: '人格測試者',
      signature: '',
      createdAt: now,
      updatedAt: now,
    );
    SharedPreferences.setMockInitialValues({
      'current_user_setting': jsonEncode(user.toJson()),
    });
    final gateway = CloudDisciplineIdentityGateway.withCallable(
      (_) async => snapshotResponse(user.id),
    );
    final appState = AppState(disciplineIdentityGateway: gateway);
    await appState.loadAllLocalData();

    final snapshot = await appState.refreshDisciplineIdentity();

    expect(snapshot.personaKey, DisciplinePersonaKey.comebackBuilder);
    expect(appState.disciplineIdentitySnapshot, same(snapshot));
    expect(appState.disciplineIdentityError, isNull);
    expect(appState.isRefreshingDisciplineIdentity, isFalse);
    appState.dispose();
  });
}
