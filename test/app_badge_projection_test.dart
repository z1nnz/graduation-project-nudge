import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:nudge/state/app_state.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _FocusedState extends AppState {
  @override
  int get focusMinutes => 25;
}

void main() {
  test('new read-only star projection never writes local unlock dates; legacy badge interface retains its behavior', () async {
    SharedPreferences.setMockInitialValues({});
    final state = _FocusedState();
    final projection = state.confirmedBadgeRecords;
    expect(
      projection.firstWhere((b) => b.badgeKey == 'focus_beginner').isUnlocked,
      false,
    );
    await Future<void>.delayed(Duration.zero);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('unlocked_badges_setting'), isNull);
    final legacy = state.badgeRecords;
    expect(
      legacy.firstWhere((b) => b.badgeKey == 'focus_beginner').isUnlocked,
      true,
    );
    await Future<void>.delayed(Duration.zero);
    expect(
      (jsonDecode(prefs.getString('unlocked_badges_setting')!) as Map)
          .containsKey('focus_beginner'),
      true,
    );
    state.dispose();
  });
}
