import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nudge/models/collection_book.dart';
import 'package:nudge/models/daily_summary.dart';
import 'package:nudge/widgets/collection_book_view.dart';

DailySummary _day(String date, int focus) => DailySummary(
  date: date,
  completedTasks: 0,
  totalTasks: 0,
  focusMinutes: focus,
  sleepHours: 0,
  steps: 0,
  exerciseMinutes: 0,
  disciplineScore: 0,
);

void main() {
  test('catalog has 16 common and 8 rare keepsakes with unique ids', () {
    expect(CollectionBook.catalog.where((i) => !i.rare).length, 16);
    expect(CollectionBook.catalog.where((i) => i.rare).length, 8);
    expect(
      CollectionBook.catalog.map((i) => i.id).toSet().length,
      CollectionBook.catalog.length,
    );
  });

  test('a day with 25+ focus minutes drops one keepsake; less drops none', () {
    final book = CollectionBook.fromSummaries([
      _day('2026-11-20', 30),
      _day('2026-11-21', 10),
    ]);
    expect(book.drops.length, 1);
    expect(book.drops.single.date, '2026-11-20');
    expect(book.drops.single.item.rare, isFalse);
  });

  test('a 2-hour day drops a rare keepsake', () {
    final book = CollectionBook.fromSummaries([_day('2026-11-22', 130)]);
    expect(book.drops.single.item.rare, isTrue);
  });

  test('drops are stable for the same day', () {
    final a = CollectionBook.fromSummaries([_day('2026-11-20', 40)]);
    final b = CollectionBook.fromSummaries([_day('2026-11-20', 90)]);
    expect(a.drops.single.item.id, b.drops.single.item.id);
  });

  test('counts each keepsake once even when found again', () {
    final days = [
      for (var d = 1; d <= 60; d++)
        _day('2026-09-${d.toString().padLeft(2, '0')}', 30),
    ];
    final book = CollectionBook.fromSummaries(days);
    expect(book.owned.length, lessThanOrEqualTo(16));
    expect(book.owned.length, greaterThan(8));
    expect(book.countOf(book.owned.first), greaterThanOrEqualTo(1));
  });

  testWidgets('the book shows found items and hides the rest', (tester) async {
    final book = CollectionBook.fromSummaries([_day('2026-11-20', 30)]);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: CollectionBookView(book: book)),
      ),
    );
    expect(find.text('已收集 1 / 24'), findsOneWidget);
    expect(find.text(book.drops.single.item.name), findsOneWidget);
    expect(find.text('？'), findsNWidgets(23));
  });
}
