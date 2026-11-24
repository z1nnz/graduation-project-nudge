import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nudge/screens/onboarding_page.dart';
import 'package:nudge/state/app_state.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<AppState> _open(WidgetTester tester) async {
  tester.view.physicalSize = const Size(412, 915);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  SharedPreferences.setMockInitialValues({});
  final appState = AppState();
  await tester.runAsync(appState.loadAllLocalData);
  await tester.pumpWidget(
    ChangeNotifierProvider<AppState>.value(
      value: appState,
      child: const MaterialApp(home: OnboardingPage()),
    ),
  );
  await tester.pump(const Duration(milliseconds: 300));
  return appState;
}

void main() {
  setUp(rootBundle.clear);

  testWidgets('the companion welcomes you and guides each step', (
    tester,
  ) async {
    await _open(tester);
    expect(find.text('歡迎來到夥伴小屋'), findsOneWidget);
    expect(find.byKey(const Key('onboarding-guide')), findsOneWidget);
    expect(find.text(OnboardingPage.guideLines.first), findsOneWidget);
    expect(find.byKey(const Key('onboarding-star-0-on')), findsOneWidget);
    expect(find.byKey(const Key('onboarding-star-1-off')), findsOneWidget);

    await tester.tap(find.text('下一步'));
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text(OnboardingPage.guideLines[1]), findsOneWidget);
    expect(find.byKey(const Key('onboarding-star-1-on')), findsOneWidget);
  });

  test('one guide line per step', () {
    expect(OnboardingPage.guideLines.length, 6);
  });
}
