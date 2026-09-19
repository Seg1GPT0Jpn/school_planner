import 'package:flutter_test/flutter_test.dart';
import 'package:school_planner/core/japanese_holidays.dart';
import 'package:school_planner/features/school_tests/initial_rules.dart';
import 'package:school_planner/features/school_tests/lesson_test_annotation.dart';
import 'package:school_planner/features/school_tests/weekly_lesson_test.dart';
import 'package:school_planner/features/timetable/day_timetable_resolver.dart';
import 'package:school_planner/features/timetable/initial_data.dart';
import 'package:school_planner/features/timetable/week_cycle.dart';

DayTimetableResolver _base() => DayTimetableResolver(
  weekCalculator: WeekCycleCalculator(
    anchors: initialAnchors,
    weekOverrides: initialWeekOverrides,
  ),
  slots: initialSlots,
  dayOverrides: initialDayOverrides,
  closures: initialClosures.values.toList(),
  holidays: japaneseHolidays,
);

DayTimetableResolver _annotated() {
  final base = _base();
  final calculators = [
    WeeklyLessonTestCalculator(rule: leapRule, resolver: base),
  ];
  return DayTimetableResolver(
    weekCalculator: base.weekCalculator,
    slots: initialSlots,
    dayOverrides: initialDayOverrides,
    closures: initialClosures.values.toList(),
    holidays: japaneseHolidays,
    postProcess: (day) => annotateLessonTests(day, calculators),
  );
}

void main() {
  test('9/28 の2限（ECⅠ）に LEAP の印が付く', () {
    final day = _annotated().resolve(DateTime(2026, 9, 28));
    expect(day.hasTests, isTrue);
    expect(day.lessons[1].subject, 'ECⅠ');
    expect(day.lessons[1].testLabel, 'LEAP単語テスト 1201〜1300');
    // ほかの授業には付かない
    expect(day.lessons[0].testLabel, isNull);
  });

  test('9/29 には印が付かない（同じ週の2回目以降の ECⅠ）', () {
    final day = _annotated().resolve(DateTime(2026, 9, 29));
    expect(day.hasTests, isFalse);
  });

  test('印を付けても、時間割そのものは変わらない', () {
    final plain = _base().resolve(DateTime(2026, 9, 28));
    final withTest = _annotated().resolve(DateTime(2026, 9, 28));
    expect(
      withTest.lessons.map((l) => l.subject).toList(),
      plain.lessons.map((l) => l.subject).toList(),
    );
  });
}
