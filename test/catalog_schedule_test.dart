import 'package:flutter_test/flutter_test.dart';
import 'package:nudge/models/catalog_schedule.dart';

void main() {
  test('catalog starts inclusively and expires exclusively like Cloud', () {
    const schedule = CatalogSchedule(startSeconds: 100, endSeconds: 200);
    expect(schedule.activeAt(99), isFalse);
    expect(schedule.activeAt(100), isTrue);
    expect(schedule.activeAt(199), isTrue);
    expect(schedule.activeAt(200), isFalse);
    expect(schedule.nextBoundaryAfter(99), 100);
    expect(schedule.nextBoundaryAfter(100), 200);
    expect(schedule.nextBoundaryAfter(200), isNull);
  });

  test('permanent and one-sided windows do not invent an expiry', () {
    expect(const CatalogSchedule().activeAt(100), isTrue);
    expect(const CatalogSchedule().nextBoundaryAfter(100), isNull);
    expect(const CatalogSchedule(startSeconds: 200).activeAt(100), isFalse);
    expect(const CatalogSchedule(endSeconds: 200).activeAt(200), isFalse);
  });
}
