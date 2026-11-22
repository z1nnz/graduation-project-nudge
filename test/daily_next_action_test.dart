import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:nudge/models/daily_next_action.dart';

void main() {
  final fixtures =
      jsonDecode(
            File('test/fixtures/daily_next_action.json').readAsStringSync(),
          )
          as List;
  for (final fixture in fixtures) {
    test('shared next action: ${fixture['name']}', () {
      final tasks = (fixture['tasks'] as List)
          .map((t) => Map<String, dynamic>.from(t as Map))
          .toList();
      final result = DailyNextAction.resolve(tasks);
      expect(result.kind.name, fixture['kind']);
      expect(result.title, fixture['title']);
    });
  }
}
