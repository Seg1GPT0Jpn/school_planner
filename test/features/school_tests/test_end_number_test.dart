import 'package:flutter_test/flutter_test.dart';
import 'package:school_planner/core/japanese_holidays.dart';
import 'package:school_planner/features/recurring/recurring_schedule.dart';
import 'package:school_planner/features/recurring/recurring_test_rule.dart';
import 'package:school_planner/features/school_tests/initial_rules.dart';
import 'package:school_planner/features/school_tests/weekly_lesson_test.dart';
import 'package:school_planner/features/timetable/day_timetable_resolver.dart';
import 'package:school_planner/features/timetable/initial_data.dart';
import 'package:school_planner/features/timetable/school_periods.dart';
import 'package:school_planner/features/timetable/week_cycle.dart';

WeeklyLessonTestCalculator _leap(int? endNumber) => WeeklyLessonTestCalculator(
  rule: WeeklyLessonTestRule(
    id: leapRule.id,
    subject: leapRule.subject,
    title: leapRule.title,
    baseWeekDate: leapRule.baseWeekDate,
    baseRangeStart: leapRule.baseRangeStart,
    rangeStep: leapRule.rangeStep,
    endNumber: endNumber,
  ),
  resolver: DayTimetableResolver(
    weekCalculator: WeekCycleCalculator(
      anchors: initialAnchors,
      weekOverrides: initialWeekOverrides,
    ),
    slots: initialSlots,
    dayOverrides: initialDayOverrides,
    closures: initialClosures.values.toList(),
    holidays: japaneseHolidays,
  ),
);

RecurringSchedule _english(int? end) => RecurringSchedule(
  id: 'e',
  title: '塾 英語',
  weekday: DateTime.friday,
  start: ClockTime(19, 40),
  end: ClockTime(21, 40),
  test: RecurringTestConfig(
    title: 'EEVI',
    baseDate: DateTime(2026, 9, 18),
    baseStart: 1,
    step: 50,
    end: end,
  ),
);

void main() {
  test('LEAP の初期値は 2300 まで', () {
    expect(leapRule.endNumber, 2300);
  });

  test('LEAP：最後の番号を超えた週はテストなし', () {
    final c = _leap(1300);
    expect(c.occurrenceInWeek(DateTime(2026, 9, 28))!.rangeLabel, '1201〜1300');
    expect(c.occurrenceInWeek(DateTime(2026, 10, 5)), isNull);
  });

  test('LEAP：最後の回は最後の番号で止まる', () {
    expect(
      _leap(1250).occurrenceInWeek(DateTime(2026, 9, 28))!.rangeLabel,
      '1201〜1250',
    );
  });

  test('LEAP：終わりなしならそのまま進む', () {
    expect(_leap(null).occurrenceInWeek(DateTime(2026, 10, 5)), isNotNull);
  });

  test('EEVI：最後の番号を超えた回はテストなし', () {
    final s = _english(100);
    expect(recurringTestOn(s, DateTime(2026, 9, 25))!.rangeText, '51〜100');
    expect(recurringTestOn(s, DateTime(2026, 10, 2)), isNull);
  });

  test('EEVI：最後の回は最後の番号で止まる', () {
    expect(
      recurringTestOn(_english(80), DateTime(2026, 9, 25))!.rangeText,
      '51〜80',
    );
  });
}
