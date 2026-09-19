import 'package:flutter_test/flutter_test.dart';
import 'package:school_planner/features/recurring/recurring_schedule.dart';
import 'package:school_planner/features/recurring/recurring_test_rule.dart';
import 'package:school_planner/features/timetable/school_periods.dart';

RecurringSchedule _english({Set<String> skipped = const {}}) =>
    RecurringSchedule(
      id: 'e',
      title: '塾 英語',
      weekday: DateTime.friday,
      start: ClockTime(19, 40),
      end: ClockTime(21, 40),
      skippedDates: skipped,
    );

void main() {
  test('9/18 は記述 1〜50 だけ（初回）', () {
    final o = recurringTestOn(_english(), DateTime(2026, 9, 18), eeviRule)!;
    expect(o.rangeText, '記述 1〜50');
  });

  test('9/25 は記述 51〜100・選択 1〜50', () {
    final o = recurringTestOn(_english(), DateTime(2026, 9, 25), eeviRule)!;
    expect(o.rangeText, '記述 51〜100・選択 1〜50');
  });

  test('休みにした週は数えない', () {
    final s = _english(skipped: {'2026-10-02'});
    expect(recurringTestOn(s, DateTime(2026, 10, 2), eeviRule), isNull);
    expect(
      recurringTestOn(s, DateTime(2026, 10, 9), eeviRule)!.rangeText,
      '記述 101〜150・選択 51〜100',
    );
  });

  test('名前に「英語」がない予定は対象外', () {
    final math = RecurringSchedule(
      id: 'm',
      title: '塾 数学',
      weekday: DateTime.monday,
      start: ClockTime(19, 40),
      end: ClockTime(21, 40),
    );
    expect(recurringTestOn(math, DateTime(2026, 9, 21), eeviRule), isNull);
  });

  test('カレンダーの名前に付け足される', () {
    final events = expandRecurringWithTests(
      [_english()],
      DateTime(2026, 9, 25),
      DateTime(2026, 9, 26),
    );
    expect(events.single.title, '塾 英語｜EEVI 記述 51〜100・選択 1〜50');
  });
}
