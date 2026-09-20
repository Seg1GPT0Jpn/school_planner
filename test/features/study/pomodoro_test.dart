import 'package:flutter_test/flutter_test.dart';
import 'package:school_planner/features/study/pomodoro.dart';

void main() {
  test('はじめは集中1回目、のこり25分', () {
    final p = pomodoroPhase(Duration.zero);
    expect(p.focus, isTrue);
    expect(p.round, 1);
    expect(p.remaining, const Duration(minutes: 25));
  });

  test('26分たつと休憩、のこり4分', () {
    final p = pomodoroPhase(const Duration(minutes: 26));
    expect(p.focus, isFalse);
    expect(p.remaining, const Duration(minutes: 4));
  });

  test('31分たつと集中2回目', () {
    final p = pomodoroPhase(const Duration(minutes: 31));
    expect(p.focus, isTrue);
    expect(p.round, 2);
    expect(p.remaining, const Duration(minutes: 24));
  });

  test('記録は休憩を数えない', () {
    expect(pomodoroFocusMinutes(const Duration(minutes: 20)), 20);
    expect(pomodoroFocusMinutes(const Duration(minutes: 28)), 25);
    expect(pomodoroFocusMinutes(const Duration(minutes: 40)), 35);
    expect(pomodoroFocusMinutes(const Duration(minutes: 60)), 50);
  });

  test('お知らせは区切りごと・番号はかぶらない', () {
    final start = DateTime(2026, 9, 20, 20, 0);
    final list = pomodoroNotifications(start, cycles: 2);
    expect(list.map((n) => n.time).toList(), [
      DateTime(2026, 9, 20, 20, 25),
      DateTime(2026, 9, 20, 20, 30),
      DateTime(2026, 9, 20, 20, 55),
      DateTime(2026, 9, 20, 21, 0),
    ]);
    expect(list.map((n) => n.id).toSet().length, 4);
    expect(list.every((n) => n.id >= pomodoroIdBase), isTrue);
  });
}
