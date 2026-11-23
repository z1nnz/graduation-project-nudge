import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nudge/state/app_state.dart';
import 'package:nudge/widgets/quest_scroll.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('the quest scroll lists today\'s quests and ticks them off', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final appState = AppState();
    await tester.runAsync(appState.loadAllLocalData);
    appState.addTask('讀英文 30 分鐘', '讀書', taskType: 'fixed');
    await tester.pumpWidget(
      ChangeNotifierProvider<AppState>.value(
        value: appState,
        child: MaterialApp(
          home: Builder(
            builder: (context) => TextButton(
              onPressed: () => showQuestScroll(context),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    expect(find.text('今日委託'), findsOneWidget);
    expect(find.text('讀英文 30 分鐘'), findsOneWidget);
    final index = appState.taskModels.indexWhere((t) => t.title == '讀英文 30 分鐘');
    expect(appState.taskModels[index].isDone, isFalse);

    await tester.tap(find.text('讀英文 30 分鐘'));
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 100)),
    );
    await tester.pumpAndSettle();

    expect(
      appState.taskModels.firstWhere((t) => t.title == '讀英文 30 分鐘').isDone,
      isTrue,
    );
    expect(find.text('全部委託'), findsOneWidget);
  });
}
