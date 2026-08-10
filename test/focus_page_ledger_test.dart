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

class _RejectingSecondFocusOutbox extends ActivityLedgerOutbox {
  _RejectingSecondFocusOutbox()
    : super(
        gateway: CloudActivityLedgerGateway.withCallable(
          (_) async => throw StateError('Cloud should not be called'),
        ),
      );

  int enqueueAttempts = 0;

  @override
  Future<void> enqueue(ActivityEvidence evidence) async {
    enqueueAttempts++;
    if (enqueueAttempts == 2) {
      throw StateError('focus transition unavailable');
    }
  }

  @override
  Future<ActivityLedgerFlushReport> flush() async {
    return const ActivityLedgerFlushReport(
      succeeded: [],
      permanentlyRejected: 0,
      retryBlocked: false,
    );
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

  testWidgets(
    'focus timer keeps running when its pause event cannot be saved',
    (tester) async {
      final now = DateTime.now();
      final user = UserModel(
        id: 'focus-user-pause-failure',
        username: 'focus-user-pause-failure',
        nickname: '暫停失敗測試者',
        signature: '',
        createdAt: now,
        updatedAt: now,
      );
      SharedPreferences.setMockInitialValues({
        'current_user_setting': jsonEncode(user.toJson()),
      });
      final outbox = _RejectingSecondFocusOutbox();
      final appState = AppState(activityLedgerOutbox: outbox);
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
      expect(find.text('專注中'), findsOneWidget);

      await tester.tap(find.text('暫停'));
      await tester.pump();

      expect(outbox.enqueueAttempts, 2);
      expect(find.text('專注中'), findsOneWidget);
      expect(find.text('暫停事件尚未安全保存，計時會繼續'), findsOneWidget);

      await tester.pumpWidget(const SizedBox.shrink());
      appState.dispose();
    },
  );

  testWidgets(
    'focus reset preserves the running session when discard cannot be saved',
    (tester) async {
      final now = DateTime.now();
      final user = UserModel(
        id: 'focus-user-reset-failure',
        username: 'focus-user-reset-failure',
        nickname: '重設失敗測試者',
        signature: '',
        createdAt: now,
        updatedAt: now,
      );
      SharedPreferences.setMockInitialValues({
        'current_user_setting': jsonEncode(user.toJson()),
      });
      final outbox = _RejectingSecondFocusOutbox();
      final appState = AppState(activityLedgerOutbox: outbox);
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
      await tester.pump(const Duration(seconds: 1));

      await tester.tap(find.text('重設'));
      await tester.pump();

      expect(outbox.enqueueAttempts, 2);
      expect(find.text('專注中'), findsOneWidget);
      expect(find.text('重設事件尚未安全保存，原有計時狀態已保留'), findsOneWidget);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
      appState.dispose();
    },
  );

  testWidgets('focus completion does not project time when Ledger save fails', (
    tester,
  ) async {
    final now = DateTime.now();
    final user = UserModel(
      id: 'focus-user-completion-failure',
      username: 'focus-user-completion-failure',
      nickname: '完成失敗測試者',
      signature: '',
      createdAt: now,
      updatedAt: now,
    );
    SharedPreferences.setMockInitialValues({
      'current_user_setting': jsonEncode(user.toJson()),
    });
    final outbox = _RejectingSecondFocusOutbox();
    final appState = AppState(activityLedgerOutbox: outbox);
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
    await tester.pump(const Duration(seconds: 2));

    await tester.tap(find.text('提前結束'));
    await tester.pump();
    expect(find.text('結束並記錄'), findsOneWidget);
    await tester.tap(find.text('結束並記錄'));
    await tester.pump();

    expect(outbox.enqueueAttempts, 2);
    expect(appState.focusSeconds, 0);
    expect(find.text('完成事件尚未安全保存，專注進度未變更'), findsOneWidget);
    expect(find.text('專注中'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
    appState.dispose();
  });
}
