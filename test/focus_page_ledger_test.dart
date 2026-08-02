import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nudge/models/activity_ledger.dart';
import 'package:nudge/models/user_model.dart';
import 'package:nudge/screens/focus_page.dart';
import 'package:nudge/services/activity_ledger_outbox.dart';
import 'package:nudge/services/cloud_activity_ledger_gateway.dart';
import 'package:nudge/state/app_state.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _RejectingFocusOutbox extends ActivityLedgerOutbox {
  _RejectingFocusOutbox()
    : super(
        gateway: CloudActivityLedgerGateway.withCallable(
          (_) async => throw StateError('Cloud should not be called'),
        ),
      );

  @override
  Future<void> enqueue(ActivityEvidence evidence) {
    return Future<void>.error(StateError('focus outbox unavailable'));
  }
}

void main() {
  testWidgets(
    'focus timer does not start when its Ledger event cannot be saved',
    (tester) async {
      final now = DateTime.now();
      final user = UserModel(
        id: 'focus-user-1',
        username: 'focus-user-1',
        nickname: '專注測試者',
        signature: '',
        createdAt: now,
        updatedAt: now,
      );
      SharedPreferences.setMockInitialValues({
        'current_user_setting': jsonEncode(user.toJson()),
      });
      final appState = AppState(activityLedgerOutbox: _RejectingFocusOutbox());
      await appState.loadAllLocalData();

      await tester.pumpWidget(
        ChangeNotifierProvider<AppState>.value(
          value: appState,
          child: const MaterialApp(home: FocusPage()),
        ),
      );
      await tester.scrollUntilVisible(
        find.text('開始專注'),
        360,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(find.text('開始專注'));
      await tester.pump();

      expect(find.text('開始專注'), findsOneWidget);
      expect(find.text('專注事件尚未安全保存，請稍後重試'), findsOneWidget);
      expect(appState.focusSeconds, 0);

      await tester.pump(const Duration(seconds: 1));
      await tester.pumpWidget(const SizedBox.shrink());
      appState.dispose();
    },
  );
}
