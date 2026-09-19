import 'package:flutter_test/flutter_test.dart';
import 'package:school_planner/core/japanese_holidays.dart';
import 'package:school_planner/features/belongings/belongings.dart';
import 'package:school_planner/features/recurring/recurring_schedule.dart';
import 'package:school_planner/features/timetable/day_timetable_resolver.dart';
import 'package:school_planner/features/timetable/initial_data.dart';
import 'package:school_planner/features/timetable/school_periods.dart';
import 'package:school_planner/features/timetable/week_cycle.dart';

void main() {
  final resolver = DayTimetableResolver(
    weekCalculator: WeekCycleCalculator(
      anchors: initialAnchors,
      weekOverrides: initialWeekOverrides,
    ),
    slots: initialSlots,
    dayOverrides: initialDayOverrides,
    closures: initialClosures.values.toList(),
    holidays: japaneseHolidays,
  );
  const settings = BelongingSettings(
    daily: ['弁当'],
    bySubject: {
      '体育': ['体操服'],
      'ECⅠ': ['LEAP'],
    },
    byRecurring: {
      'm': ['数学の問題集'],
    },
  );
  final math = RecurringSchedule(
    id: 'm',
    title: '塾 数学',
    weekday: DateTime.monday,
    start: ClockTime(19, 40),
    end: ClockTime(21, 40),
  );

  test('9/7（Ⅰ週・月）：毎日＋体育＋ECⅠ＋塾', () {
    expect(
      belongingsFor(
        day: resolver.resolve(DateTime(2026, 9, 7)),
        recurring: [math],
        settings: settings,
      ),
      ['弁当', '体操服', 'LEAP', '数学の問題集'],
    );
  });

  test('祝日（9/21・月）は学校の持ち物なし、塾の分だけ', () {
    expect(
      belongingsFor(
        day: resolver.resolve(DateTime(2026, 9, 21)),
        recurring: [math],
        settings: settings,
      ),
      ['数学の問題集'],
    );
  });
}
