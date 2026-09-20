import 'package:flutter_test/flutter_test.dart';
import 'package:school_planner/core/japanese_holidays.dart';
import 'package:school_planner/features/school_tests/school_test_repository.dart';
import 'package:school_planner/features/school_tests/weekly_lesson_test.dart';
import 'package:school_planner/features/timetable/day_timetable_resolver.dart';
import 'package:school_planner/features/timetable/initial_data.dart';
import 'package:school_planner/features/timetable/week_cycle.dart';

WeeklyLessonTestRule _rule({DateTime? startDate}) => WeeklyLessonTestRule(
  id: 'teppeki',
  subject: 'ECⅠ',
  title: '鉄壁単語テスト',
  baseWeekDate: DateTime(2026, 10, 5),
  baseRangeStart: 1,
  rangeStep: 100,
  startDate: startDate,
);

WeeklyLessonTestCalculator _calc(WeeklyLessonTestRule rule) =>
    WeeklyLessonTestCalculator(
      rule: rule,
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

void main() {
  test('始まる週より前はテストなし、その週から 1〜100', () {
    final c = _calc(_rule(startDate: DateTime(2026, 10, 5)));
    expect(c.occurrenceInWeek(DateTime(2026, 9, 28)), isNull);
    expect(c.occurrenceInWeek(DateTime(2026, 10, 5))!.rangeLabel, '1〜100');
  });

  test('始まりの指定がなければ前の週も逆算する（LEAP と同じ動き）', () {
    final c = _calc(_rule());
    expect(c.occurrenceInWeek(DateTime(2026, 9, 28)), isNotNull);
  });

  test('保存形式に始まりの日が入る', () {
    final r = _rule(startDate: DateTime(2027, 4, 12));
    final back = SchoolTestRepository.ruleFromMap(
      'x',
      SchoolTestRepository.ruleToMap(r),
    );
    expect(back.startDate, DateTime(2027, 4, 12));
    expect(back.title, '鉄壁単語テスト');
    expect(
      SchoolTestRepository.ruleFromMap(
        'y',
        SchoolTestRepository.ruleToMap(_rule()),
      ).startDate,
      isNull,
    );
  });
}
