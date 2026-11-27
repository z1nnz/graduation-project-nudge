import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nudge/models/privacy_data_request.dart';
import 'package:nudge/screens/login_page.dart';
import 'package:nudge/screens/privacy_data_page.dart';
import 'package:nudge/screens/settings_page.dart';
import 'package:nudge/services/cloud_privacy_data_gateway.dart';
import 'package:nudge/services/nudge_device_coordinator.dart';
import 'package:nudge/theme/game_ui.dart';
import 'package:nudge/widgets/game_device_workbench.dart';
import 'package:nudge/widgets/game_pixel_switch.dart';

import 'support/studio_test_fixture.dart';

class _Rights {
  final identities = StreamController<String?>.broadcast();
  final requests = <String, StreamController<List<PrivacyDataRequest>>>{};
  final calls = <Map<String, dynamic>>[];
  Completer<Object?>? pending;
  late final gateway = CloudPrivacyDataGateway.withAdapters(
    watch: (uid) async* {
      final c = requests[uid] ??=
          StreamController<List<PrivacyDataRequest>>.broadcast();
      yield <PrivacyDataRequest>[];
      yield* c.stream;
    },
    call: (name, payload) async {
      calls.add({'name': name, ...payload});
      if (pending != null) return pending!.future;
      return result(
        payload['action'] == 'request_export' ? 'export' : 'account_deletion',
      );
    },
  );
  Map<String, dynamic> result(String type) => {
    'request': {
      'schemaVersion': 1,
      'requestId': 'alice--request-one',
      'userId': 'alice',
      'type': type,
      'status': 'pending',
    },
    'auditEventId': 'privacy-request-audit-001',
    'replayed': false,
  };
  Future<void> dispose() async {
    await identities.close();
    for (final c in requests.values) {
      await c.close();
    }
  }
}

class _SlowLoginState extends StudioTestState {
  final reply = Completer<void>();
  @override
  Future<void> signInWithEmailAndPassword(String email, String password) =>
      reply.future;
}

Future<void> tap(WidgetTester tester, String label) async {
  final target = find.text(label);
  await tester.ensureVisible(target);
  await tester.pumpAndSettle();
  await tester.tap(target);
  await tester.pumpAndSettle();
}

Future<StudioTestState> _rights(WidgetTester tester, _Rights fake) async {
  tester.view.physicalSize = const Size(360, 780);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final state = StudioTestState();
  await tester.pumpWidget(
    shell(
      state,
      PrivacyDataPage(
        dataGateway: fake.gateway,
        identityChanges: fake.identities.stream,
      ),
      GlobalKey(),
      false,
    ),
  );
  fake.identities.add('alice');
  await tester.pump();
  await tap(tester, '打開資料保險箱');
  await tester.scrollUntilVisible(
    find.text('申請刪除帳號'),
    450,
    scrollable: find.byType(Scrollable).first,
  );
  await tester.pumpAndSettle();
  return state;
}

void main() {
  setUpAll(() async {
    await (FontLoader(
      'Cubic11',
    )..addFont(rootBundle.load('assets/fonts/Cubic11.ttf'))).load();
    await (FontLoader(
      'MaterialIcons',
    )..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'))).load();
  });
  testWidgets(
    'two deletion seals cancel safely at either step; optional reason submits exactly once',
    (tester) async {
      final fake = _Rights(), state = await _rights(tester, fake);
      await tap(tester, '申請刪除帳號');
      expect(find.textContaining('7 天冷靜期'), findsOneWidget);
      expect(tester.binding.transientCallbackCount, 0);
      await tap(tester, '返回，保留帳號');
      expect(fake.calls, isEmpty);
      await tap(tester, '申請刪除帳號');
      await tap(tester, '閱讀完成，前往第二步');
      expect(find.text('第二道封印・正式確認'), findsOneWidget);
      expect(find.textContaining('Ledger 保留義務'), findsOneWidget);
      await tap(tester, '返回');
      expect(fake.calls, isEmpty);
      await tap(tester, '申請刪除帳號');
      await tap(tester, '閱讀完成，前往第二步');
      await tester.enterText(find.byType(TextField), '  local reason  ');
      await tap(tester, '送出正式申請');
      expect(fake.calls, hasLength(1));
      expect(fake.calls.single['action'], 'request_account_deletion');
      expect(fake.calls.single['reason'], 'local reason');
      expect(fake.calls.single['sourceSurface'], 'app');
      expect(find.textContaining('刪除申請已受理'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      state.dispose();
      await fake.dispose();
    },
  );
  for (final second in [false, true]) {
    testWidgets(
      'identity change closes ${second ? 'second' : 'first'} seal and cannot submit for a new owner',
      (tester) async {
        final fake = _Rights(), state = await _rights(tester, fake);
        await tap(tester, '申請刪除帳號');
        if (second) await tap(tester, '閱讀完成，前往第二步');
        fake.identities.add('bob');
        await tester.pumpAndSettle();
        expect(find.byType(AlertDialog), findsNothing);
        expect(fake.calls, isEmpty);
        fake.identities.add(null);
        await tester.pumpAndSettle();
        expect(find.text('申請刪除帳號'), findsNothing);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
        state.dispose();
        await fake.dispose();
      },
    );
  }
  testWidgets(
    'export keeps its gateway contract and ignores an old owner reply and list',
    (tester) async {
      final fake = _Rights(), state = await _rights(tester, fake);
      fake.requests['alice']!.add([
        PrivacyDataRequest.fromMap({
          'schemaVersion': 1,
          'requestId': 'alice--old',
          'userId': 'alice',
          'type': 'account_deletion',
          'status': 'pending',
          'caseId': 'PRIVATE ALICE CASE',
        }),
      ]);
      await tester.pumpAndSettle();
      expect(find.textContaining('PRIVATE ALICE CASE'), findsOneWidget);
      fake.pending = Completer<Object?>();
      await tester.ensureVisible(find.text('匯出我的資料'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('匯出我的資料'));
      await tester.pump();
      expect(fake.calls.single['action'], 'request_export');
      fake.identities.add('bob');
      await tester.pumpAndSettle();
      expect(find.textContaining('PRIVATE ALICE CASE'), findsNothing);
      fake.pending!.complete(fake.result('export'));
      await tester.pumpAndSettle();
      expect(find.textContaining('資料匯出已建立'), findsNothing);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      state.dispose();
      await fake.dispose();
    },
  );
  testWidgets(
    'pixel lever preserves callback, disabled state, semantics and 44px target',
    (tester) async {
      bool value = false;
      var changes = 0;
      final semantics = tester.ensureSemantics();
      await tester.pumpWidget(
        MaterialApp(
          home: StatefulBuilder(
            builder: (context, set) => Scaffold(
              body: Column(
                children: [
                  GameSwitchTile(
                    title: const Text('通知'),
                    value: value,
                    onChanged: (v) => set(() {
                      value = v;
                      changes++;
                    }),
                  ),
                  const GamePixelSwitch(
                    value: false,
                    onChanged: null,
                    semanticLabel: 'disabled lever',
                  ),
                ],
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('通知'));
      await tester.pump();
      expect(value, true);
      expect(changes, 1);
      final disabled = find.bySemanticsLabel('disabled lever');
      expect(tester.getSize(disabled).height, greaterThanOrEqualTo(44));
      await tester.tap(disabled);
      await tester.pump();
      expect(changes, 1);
      semantics.dispose();
    },
  );
  test('device light follows actual coordinator states', () {
    expect(
      deviceWorkbenchLight(
        const NudgeDeviceCoordinatorState(
          status: NudgeDeviceConnectionStatus.scanning,
        ),
      ),
      GamePalette.gold,
    );
    expect(
      deviceWorkbenchLight(
        const NudgeDeviceCoordinatorState(
          status: NudgeDeviceConnectionStatus.error,
        ),
      ),
      GamePalette.red,
    );
    expect(
      deviceWorkbenchLight(
        const NudgeDeviceCoordinatorState(
          status: NudgeDeviceConnectionStatus.connected,
          phase: 'focus',
        ),
      ),
      GamePalette.violet,
    );
    expect(
      deviceWorkbenchLight(
        const NudgeDeviceCoordinatorState(
          status: NudgeDeviceConnectionStatus.connected,
          phase: 'idle',
        ),
      ),
      GamePalette.green,
    );
    expect(
      deviceWorkbenchLight(const NudgeDeviceCoordinatorState()),
      GamePalette.inkSoft,
    );
  });
  testWidgets(
    'device scan animation pauses when hidden and reduced motion has a complete first frame',
    (tester) async {
      Widget workbench(bool reduce, bool visible) => MaterialApp(
        home: MediaQuery(
          data: MediaQueryData(disableAnimations: reduce),
          child: TickerMode(
            enabled: visible,
            child: const Scaffold(
              body: GameDeviceWorkbench(
                state: NudgeDeviceCoordinatorState(
                  status: NudgeDeviceConnectionStatus.scanning,
                ),
                label: '搜尋中',
              ),
            ),
          ),
        ),
      );
      await tester.pumpWidget(workbench(false, true));
      await tester.pump(const Duration(milliseconds: 100));
      expect(tester.binding.transientCallbackCount, greaterThan(0));
      await tester.pumpWidget(workbench(false, false));
      await tester.pump();
      expect(tester.binding.transientCallbackCount, 0);
      await tester.pumpWidget(workbench(true, true));
      await tester.pump();
      expect(tester.binding.transientCallbackCount, 0);
      expect(
        find.byKey(const ValueKey('device-connection-led')),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'workshop props open the existing reminder, city, account and privacy routes',
    (tester) async {
      tester.view.physicalSize = const Size(360, 780);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final state = StudioTestState();
      for (final entry in {
        '鈴鐺・提醒': '查看鬧鐘架',
        '鑰匙・帳號': '查看帳號鑰匙',
        '盾牌・隱私': '打開資料保險箱',
      }.entries) {
        await tester.pumpWidget(
          shell(state, const SettingsPage(), GlobalKey(), false),
        );
        await tester.pump();
        await tester.tap(find.text(entry.key));
        await tester.pumpAndSettle();
        expect(find.text(entry.value), findsOneWidget);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
      }
      state.dispose();
    },
  );
  testWidgets('passport retains empty login validation', (tester) async {
    final state = StudioTestState();
    await tester.pumpWidget(
      shell(state, const LoginPage(), GlobalKey(), false),
    );
    await tap(tester, '領取入鎮通行證');
    await tap(tester, '登入');
    expect(find.text('請輸入電子郵件與密碼'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    state.dispose();
  });
  testWidgets('city prop opens the existing location-free picker', (
    tester,
  ) async {
    final state = StudioTestState();
    await tester.pumpWidget(
      shell(state, const SettingsPage(), GlobalKey(), false),
    );
    await tester.tap(find.text('地球儀・城市'));
    await tester.pumpAndSettle();
    expect(find.text('窗外的天氣'), findsOneWidget);
    expect(find.textContaining('不會讀取你的位置'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    state.dispose();
  });
  testWidgets(
    'late failed login after leaving the passport cannot update a disposed page',
    (tester) async {
      final state = _SlowLoginState();
      await tester.pumpWidget(
        shell(state, const LoginPage(), GlobalKey(), false),
      );
      await tap(tester, '領取入鎮通行證');
      await tester.enterText(
        find.byType(TextField).first,
        'local@example.test',
      );
      await tester.enterText(find.byType(TextField).last, 'local-password');
      await tester.ensureVisible(find.text('登入'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('登入'));
      await tester.pump();
      await tester.pumpWidget(const SizedBox.shrink());
      state.reply.completeError(StateError('local delayed failure'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      state.dispose();
    },
  );
}
