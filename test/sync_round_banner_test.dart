import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nudge/services/room_focus_round.dart';
import 'package:nudge/widgets/sync_round_banner.dart';

Future<List<String>> _pump(
  WidgetTester tester,
  FocusRoundState state, {
  bool joined = false,
  String problem = '',
}) async {
  final taps = <String>[];
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: Center(
          child: SyncRoundBanner(
            state: state,
            busy: false,
            problem: problem,
            joined: joined,
            onStart: () => taps.add('start'),
            onJoin: () => taps.add('join'),
          ),
        ),
      ),
    ),
  );
  return taps;
}

void main() {
  testWidgets('idle room offers to start a shared round', (tester) async {
    final taps = await _pump(
      tester,
      const FocusRoundState(FocusRoundPhase.idle, Duration.zero),
    );
    expect(find.text('同步番茄鐘 25 + 5'), findsOneWidget);
    await tester.tap(find.text('發起一起專注'));
    expect(taps, ['start']);
  });

  testWidgets('running round shows the shared clock and a join button', (
    tester,
  ) async {
    final taps = await _pump(
      tester,
      const FocusRoundState(
        FocusRoundPhase.focus,
        Duration(minutes: 12, seconds: 5),
      ),
    );
    expect(find.text('一起專注中 12:05'), findsOneWidget);
    await tester.tap(find.text('加入這一輪'));
    expect(taps, ['join']);
  });

  testWidgets('no join button once I am already focusing', (tester) async {
    await _pump(
      tester,
      const FocusRoundState(FocusRoundPhase.focus, Duration(minutes: 3)),
      joined: true,
    );
    expect(find.byKey(const Key('room-sync-round-action')), findsNothing);
  });

  testWidgets('break shows the rest countdown only', (tester) async {
    await _pump(
      tester,
      const FocusRoundState(FocusRoundPhase.rest, Duration(minutes: 4)),
    );
    expect(find.text('完成這一輪，休息 5 分鐘 04:00'), findsOneWidget);
    expect(find.byKey(const Key('room-sync-round-action')), findsNothing);
  });

  testWidgets('problems replace the label', (tester) async {
    await _pump(
      tester,
      const FocusRoundState(FocusRoundPhase.idle, Duration.zero),
      problem: '無法同步專注計時器。',
    );
    expect(find.text('無法同步專注計時器。'), findsOneWidget);
  });
}
