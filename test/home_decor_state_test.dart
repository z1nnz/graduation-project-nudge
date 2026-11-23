import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:nudge/models/home_decor_catalog.dart';
import 'package:nudge/models/user_model.dart';
import 'package:nudge/services/cloud_home_decor_gateway.dart';
import 'package:nudge/state/app_state.dart';
import 'package:shared_preferences/shared_preferences.dart';

UserModel _user() {
  final now = DateTime.now();
  return UserModel(
    id: 'user-1',
    username: 'user-1',
    nickname: '測試者',
    signature: '',
    createdAt: now,
    updatedAt: now,
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('parseHomeDecor falls back to the free variant', () {
    expect(
      HomeDecorCatalog.parseHomeDecor({
        'rug': 2,
        'curtain': 'x',
        'lamp': 9,
        'sofa': 1,
      }),
      {'rug': 2, 'curtain': 0, 'lamp': 0},
    );
    expect(HomeDecorCatalog.parseHomeDecor(null), {
      'rug': 0,
      'curtain': 0,
      'lamp': 0,
    });
  });

  test('guest arrangement stays local and owned-only', () async {
    SharedPreferences.setMockInitialValues({});
    var calls = 0;
    final appState = AppState(
      homeDecorGateway: CloudHomeDecorGateway.withCallable((_) async {
        calls += 1;
        return null;
      }),
    );
    await appState.loadAllLocalData();

    expect(
      await appState.arrangeHomeDecor({'rug': 0, 'curtain': 0, 'lamp': 0}),
      isTrue,
    );
    expect(
      await appState.arrangeHomeDecor({'rug': 1, 'curtain': 0, 'lamp': 0}),
      isFalse,
    );
    expect(appState.homeDecor, {'rug': 0, 'curtain': 0, 'lamp': 0});
    expect(calls, 0);
  });

  test('signed-in arrangement applies the Cloud result', () async {
    SharedPreferences.setMockInitialValues({
      'current_user_setting': jsonEncode(_user().toJson()),
      'unlocked_avatar_items_setting': ['homeDecor:1'],
    });
    Map<String, dynamic>? sent;
    final appState = AppState(
      homeDecorGateway: CloudHomeDecorGateway.withCallable((payload) async {
        sent = payload;
        return {
          'rewardEntryId': 'decor_1',
          'homeDecor': {'rug': 1, 'curtain': 0, 'lamp': 0},
          'replayed': false,
        };
      }),
    );
    await appState.loadAllLocalData();

    final ok = await appState.arrangeHomeDecor({
      'rug': 1,
      'curtain': 0,
      'lamp': 0,
    });

    expect(ok, isTrue);
    expect(sent?['arrangement'], {'rug': 1, 'curtain': 0, 'lamp': 0});
    expect(sent?['sourceSurface'], 'app');
    expect(appState.homeDecor, {'rug': 1, 'curtain': 0, 'lamp': 0});
    expect(appState.isHomeDecorOwned('rug', 1), isTrue);
    expect(appState.isHomeDecorOwned('rug', 2), isFalse);
    expect(appState.avatarItemPrice('homeDecor', 101), 25);
  });

  test('sign-out clears the arrangement', () async {
    SharedPreferences.setMockInitialValues({
      'current_user_setting': jsonEncode(_user().toJson()),
      'unlocked_avatar_items_setting': ['homeDecor:1'],
    });
    final appState = AppState(
      homeDecorGateway: CloudHomeDecorGateway.withCallable(
        (_) async => {
          'rewardEntryId': 'decor_1',
          'homeDecor': {'rug': 1, 'curtain': 0, 'lamp': 0},
          'replayed': false,
        },
      ),
    );
    await appState.loadAllLocalData();
    await appState.arrangeHomeDecor({'rug': 1, 'curtain': 0, 'lamp': 0});

    await appState.signOut();

    expect(appState.homeDecor, {'rug': 0, 'curtain': 0, 'lamp': 0});
  });
}
