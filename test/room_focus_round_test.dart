import 'package:flutter_test/flutter_test.dart';
import 'package:nudge/services/room_focus_round.dart';

void main() {
  final start = DateTime.utc(2026, 11, 24, 10);

  test('no round means idle', () {
    final s = FocusRoundClock.at(null, start);
    expect(s.phase, FocusRoundPhase.idle);
    expect(s.remaining, Duration.zero);
  });

  test('25 minutes of focus, rounded up to the second', () {
    final s = FocusRoundClock.at(
      start,
      start.add(const Duration(minutes: 10, milliseconds: 500)),
    );
    expect(s.phase, FocusRoundPhase.focus);
    expect(s.remaining, const Duration(minutes: 15));
  });

  test('then a 5 minute break', () {
    final s = FocusRoundClock.at(start, start.add(const Duration(minutes: 26)));
    expect(s.phase, FocusRoundPhase.rest);
    expect(s.remaining, const Duration(minutes: 4));
  });

  test('after 30 minutes anyone may start the next round', () {
    final s = FocusRoundClock.at(start, start.add(const Duration(minutes: 30)));
    expect(s.phase, FocusRoundPhase.idle);
  });

  test('new round payload matches the rules', () {
    final data = FocusRoundClock.newRound('uid-1', 'SERVER_TIME');
    expect(data, {
      'startedBy': 'uid-1',
      'startAt': 'SERVER_TIME',
      'durationMin': 25,
      'breakMin': 5,
    });
  });

  test('labels', () {
    expect(FocusRoundClock.label(FocusRoundPhase.idle), '可以發起新一輪');
    expect(FocusRoundClock.label(FocusRoundPhase.focus), '一起專注中');
    expect(FocusRoundClock.label(FocusRoundPhase.rest), '完成這一輪，休息 5 分鐘');
  });
}
