import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nudge/widgets/backpack_sheet.dart';

void main() {
  testWidgets('the backpack is an item grid that opens each feature', (
    tester,
  ) async {
    final opened = <String>[];
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () => showBackpack(context, onOpen: opened.add),
            child: const Text('open'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    expect(find.text('背包'), findsOneWidget);
    for (final label in [
      '角色',
      '商城',
      '健康',
      '日曆',
      '分析',
      '錢包',
      '提醒',
      '時光信',
      '設定',
      '帳號',
    ]) {
      expect(find.text(label), findsOneWidget, reason: label);
    }
    await tester.tap(find.text('健康'));
    await tester.pumpAndSettle();
    expect(opened, ['health']);
    expect(find.text('背包'), findsNothing, reason: 'closes after choosing');
  });
}
