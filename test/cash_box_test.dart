import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nudge/screens/coin_wallet_page.dart';
import 'package:nudge/widgets/world_life.dart';

Future<void> _pump(
  WidgetTester tester,
  Widget child, {
  Size size = const Size(390, 844),
  bool still = false,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      home: MediaQuery(
        data: MediaQueryData(size: size, disableAnimations: still),
        child: Scaffold(body: SingleChildScrollView(child: child)),
      ),
    ),
  );
}

void main() {
  for (final size in const [Size(390, 844), Size(1280, 800)]) {
    testWidgets('the cash box shows the balance as a pile on ${size.width}px', (
      tester,
    ) async {
      await _pump(
        tester,
        const CashBoxScene(coins: 320, todayEarned: 6, dailyLimit: 15),
        size: size,
      );
      expect(find.byKey(const Key('wallet-cashbox')), findsOneWidget);
      expect(find.text('320 枚 · 今天 +6／15'), findsOneWidget);
      expect(find.bySemanticsLabel(RegExp('錢箱裡有 320 枚')), findsOneWidget);
    });
  }

  testWidgets('the ledger writes one line per day, newest first', (
    tester,
  ) async {
    await _pump(
      tester,
      const LedgerBook(entries: [('2026-11-26', 9), ('2026-11-25', 3)]),
    );
    expect(find.text('＋9 枚'), findsOneWidget);
    expect(find.text('2026-11-25'), findsOneWidget);
    await _pump(tester, const LedgerBook(entries: []));
    expect(find.textContaining('還沒有入帳'), findsOneWidget);
  });

  testWidgets('reduced motion: coins stop falling', (tester) async {
    await _pump(
      tester,
      const CashBoxScene(coins: 10, todayEarned: 3, dailyLimit: 15),
      still: true,
    );
    await tester.pump(const Duration(seconds: 1));
    final clock = tester.state(find.byType(WorldClock));
    expect(clock, isNotNull);
    expect(tester.hasRunningAnimations, isFalse);
  });
}
