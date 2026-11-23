import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nudge/models/user_model.dart';
import 'package:nudge/services/cloud_home_decor_gateway.dart';
import 'package:nudge/services/cloud_reward_purchase_gateway.dart';
import 'package:nudge/state/app_state.dart';
import 'package:nudge/widgets/home_decor_sheet.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

String _user() {
  final now = DateTime.now();
  return jsonEncode(
    UserModel(
      id: 'user-1',
      username: 'user-1',
      nickname: '測試者',
      signature: '',
      createdAt: now,
      updatedAt: now,
    ).toJson(),
  );
}

Future<void> _open(WidgetTester tester, AppState appState) async {
  await tester.pumpWidget(
    ChangeNotifierProvider<AppState>.value(
      value: appState,
      child: MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () => showHomeDecorSheet(context),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('open'));
  for (var i = 0; i < 40 && find.text('窗簾').evaluate().isEmpty; i++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 50)),
    );
    await tester.pump();
  }
  await tester.pumpAndSettle();
}

Future<void> _tapVariant(WidgetTester tester, String name) async {
  await tester.ensureVisible(find.text(name));
  await tester.pumpAndSettle();
  await tester.tap(find.text(name));
  await tester.runAsync(
    () => Future<void>.delayed(const Duration(milliseconds: 100)),
  );
  await tester.pumpAndSettle();
}

void main() {
  // Asset reads are cached per bundle; a cached future from an earlier
  // test's zone never completes in the next test's fake-async zone.
  setUp(rootBundle.clear);

  testWidgets('decor sheet buys then arranges', (tester) async {
    SharedPreferences.setMockInitialValues({
      'current_user_setting': _user(),
      'discipline_coins_setting': 100,
    });
    final calls = <String>[];
    final appState = AppState(
      rewardPurchaseGateway: CloudRewardPurchaseGateway.withCallable((p) async {
        calls.add('purchase:${p['category']}:${p['index']}');
        return {
          'rewardEntryId': 'purchase-1',
          'itemKey': 'homeDecor:101',
          'disciplineCoins': 75,
          'unlockedAvatarItems': ['homeDecor:101'],
          'alreadyUnlocked': false,
          'replayed': false,
        };
      }),
      homeDecorGateway: CloudHomeDecorGateway.withCallable((p) async {
        calls.add('arrange:${jsonEncode(p['arrangement'])}');
        return {'rewardEntryId': 'decor-1', 'homeDecor': p['arrangement']};
      }),
    );
    await tester.runAsync(appState.loadAllLocalData);
    await _open(tester, appState);

    await _tapVariant(tester, '星點紗簾');
    await tester.ensureVisible(find.text('購買並擺放（25 自律幣）'));
    await tester.tap(find.text('購買並擺放（25 自律幣）'));
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 200)),
    );
    await tester.pumpAndSettle();

    expect(calls, [
      'purchase:homeDecor:101',
      'arrange:{"rug":0,"curtain":1,"lamp":0}',
    ]);
    expect(appState.homeDecor['curtain'], 1);
    expect(appState.disciplineCoins, 75);
  });

  testWidgets('guest decor purchase asks to sign in', (tester) async {
    SharedPreferences.setMockInitialValues({'discipline_coins_setting': 100});
    var purchases = 0;
    final appState = AppState(
      rewardPurchaseGateway: CloudRewardPurchaseGateway.withCallable((_) async {
        purchases += 1;
        return null;
      }),
    );
    await tester.runAsync(appState.loadAllLocalData);
    await _open(tester, appState);

    await _tapVariant(tester, '星點紗簾');

    expect(find.text('登入後才能購買'), findsOneWidget);
    expect(find.textContaining('購買並擺放'), findsNothing);
    expect(purchases, 0);
  });
}
