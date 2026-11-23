import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nudge/widgets/cabin_route.dart';

void main() {
  testWidgets('leaving the cabin opens the next page as a growing circle', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () => Navigator.push(
              context,
              CabinRoute<void>(
                builder: (_) => const Scaffold(body: Text('自律房')),
              ),
            ),
            child: const Text('go'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('go'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
    expect(find.byType(ClipPath), findsWidgets);
    await tester.pumpAndSettle();
    expect(find.text('自律房'), findsOneWidget);
  });
}
