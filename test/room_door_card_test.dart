import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nudge/widgets/room_door_card.dart';

Widget _host(Widget child) => MaterialApp(
  home: Scaffold(body: SingleChildScrollView(child: child)),
);

RoomDoorCard _card({
  int approved = 3,
  int limit = 8,
  int active = 0,
  bool locked = false,
  bool approval = false,
  bool nearFull = false,
  bool pending = false,
  bool joining = false,
  VoidCallback? onTap,
}) => RoomDoorCard(
  name: '期末衝刺房',
  subtitle: '一起讀到考完',
  accent: Colors.teal,
  typeLabel: '專注',
  typeIcon: Icons.menu_book_rounded,
  approvedCount: approved,
  memberLimit: limit,
  activeCount: active,
  progress: 0.4,
  trackedValueText: '120 分鐘',
  leaderLine: '今日領先：小明（60 分鐘）',
  locked: locked,
  needsApproval: approval,
  nearFull: nearFull,
  hasPending: pending,
  isJoining: joining,
  onTap: onTap ?? () {},
);

void main() {
  testWidgets('shows the room name, head count and today total', (
    tester,
  ) async {
    await tester.pumpWidget(_host(_card()));
    expect(find.text('期末衝刺房'), findsOneWidget);
    expect(find.text('3/8 人'), findsOneWidget);
    expect(find.textContaining('120 分鐘'), findsOneWidget);
    expect(find.text('今日領先：小明（60 分鐘）'), findsOneWidget);
  });

  testWidgets('window is lit and shows who is studying when someone is in', (
    tester,
  ) async {
    await tester.pumpWidget(_host(_card(active: 2)));
    expect(find.byKey(const ValueKey('door-light-on')), findsOneWidget);
    expect(find.text('2 人在讀'), findsOneWidget);
  });

  testWidgets('window stays dark when nobody is studying', (tester) async {
    await tester.pumpWidget(_host(_card()));
    expect(find.byKey(const ValueKey('door-light-off')), findsOneWidget);
    expect(find.textContaining('在讀'), findsNothing);
  });

  testWidgets('full room shows 已滿 instead of 快滿', (tester) async {
    await tester.pumpWidget(_host(_card(approved: 8, nearFull: true)));
    expect(find.text('已滿'), findsOneWidget);
    expect(find.text('快滿'), findsNothing);
  });

  testWidgets('locked, approval and pending badges', (tester) async {
    await tester.pumpWidget(
      _host(_card(locked: true, approval: true, pending: true, nearFull: true)),
    );
    expect(find.text('需密碼'), findsOneWidget);
    expect(find.text('需審核'), findsOneWidget);
    expect(find.text('有待審'), findsOneWidget);
    expect(find.text('快滿'), findsOneWidget);
  });

  testWidgets('tapping the door opens the room', (tester) async {
    var taps = 0;
    await tester.pumpWidget(_host(_card(onTap: () => taps++)));
    await tester.tap(find.text('期末衝刺房'));
    expect(taps, 1);
  });

  testWidgets('while joining the door shows a spinner and ignores taps', (
    tester,
  ) async {
    var taps = 0;
    await tester.pumpWidget(_host(_card(joining: true, onTap: () => taps++)));
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    await tester.tap(find.text('期末衝刺房'));
    expect(taps, 0);
  });
}
