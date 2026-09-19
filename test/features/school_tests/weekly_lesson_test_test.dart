import 'package:flutter_test/flutter_test.dart';
import 'package:school_planner/core/japanese_holidays.dart';
import 'package:school_planner/features/school_tests/initial_rules.dart';
import 'package:school_planner/features/school_tests/weekly_lesson_test.dart';
import 'package:school_planner/features/timetable/day_timetable_resolver.dart';
import 'package:school_planner/features/timetable/initial_data.dart';
import 'package:school_planner/features/timetable/timetable_models.dart';
import 'package:school_planner/features/timetable/week_cycle.dart';

DayTimetableResolver _resolver({List<DayOverride> extra = const []}) {
  return DayTimetableResolver(
    weekCalculator: WeekCycleCalculator(
      anchors: initialAnchors,
      weekOverrides: initialWeekOverrides,
    ),
    slots: initialSlots,
    dayOverrides: [...initialDayOverrides, ...extra],
    closures: initialClosures.values.toList(),
    holidays: japaneseHolidays,
  );
}

WeeklyLessonTestCalculator _calc({
  WeeklyLessonTestRule? rule,
  List<DayOverride> extra = const [],
}) {
  return WeeklyLessonTestCalculator(
    rule: rule ?? leapRule,
    resolver: _resolver(extra: extra),
  );
}

String _describe(LessonTestOccurrence? o) {
  if (o == null) return 'なし';
  return '${o.date.month}/${o.date.day} ${o.lesson.period}限 ${o.rangeLabel}';
}

void main() {
  group('LEAP テストの日と範囲', () {
    test('9/28 の週（基準）：9/28（月）2限、1201〜1300', () {
      expect(
        _describe(_calc().occurrenceInWeek(DateTime(2026, 9, 28))),
        '9/28 2限 1201〜1300',
      );
    });

    test('10/5 の週（Ⅰ週）：10/5（月）4限、1301〜1400', () {
      expect(
        _describe(_calc().occurrenceInWeek(DateTime(2026, 10, 5))),
        '10/5 4限 1301〜1400',
      );
    });

    test('10/12 の週：月曜は祝日、Ⅰ週扱いの 10/13（火）3限、1401〜1500', () {
      expect(
        _describe(_calc().occurrenceInWeek(DateTime(2026, 10, 14))),
        '10/13 3限 1401〜1500',
      );
    });

    test('10/19 の週：その日だけⅡ週の 10/19（月）2限、1501〜1600', () {
      expect(
        _describe(_calc().occurrenceInWeek(DateTime(2026, 10, 19))),
        '10/19 2限 1501〜1600',
      );
    });

    test('9/21 の週：月〜水は祝日、木・金に ECⅠ がないので「なし」', () {
      expect(_calc().occurrenceInWeek(DateTime(2026, 9, 24)), isNull);
    });

    test('9/14 の週：テストがなかった 9/21 の週は数えず、1101〜1200', () {
      expect(
        _describe(_calc().occurrenceInWeek(DateTime(2026, 9, 14))),
        '9/14 2限 1101〜1200',
      );
    });

    test('11/30 の週：試験日課の 11/30 を飛ばし、12/1（火）3限', () {
      final o = _calc().occurrenceInWeek(DateTime(2026, 11, 30));
      expect(o?.date.day, 1);
      expect(o?.date.month, 12);
      expect(o?.lesson.period, 3);
    });

    test('冬休みの週（12/28〜）は「なし」', () {
      expect(_calc().occurrenceInWeek(DateTime(2026, 12, 28)), isNull);
    });
  });

  group('休講・「この週はなし」', () {
    test('9/28 の ECⅠ が休講なら、その週の次の ECⅠ（9/29 火 1限）に移る', () {
      final o = _calc(
        extra: [
          DayOverride(
            date: DateTime(2026, 9, 28),
            changes: const [PeriodChange.cancel(period: 2)],
          ),
        ],
      ).occurrenceInWeek(DateTime(2026, 9, 28));
      expect(_describe(o), '9/29 1限 1201〜1300');
    });

    test('10/5 の週を「なし」にすると、その週はなく、次の週の範囲も進まない', () {
      final rule = WeeklyLessonTestRule(
        id: 'leap',
        subject: 'ECⅠ',
        title: 'LEAP単語テスト',
        baseWeekDate: DateTime(2026, 9, 28),
        baseRangeStart: 1201,
        skippedWeeks: const {'2026-10-05'},
      );
      final calc = _calc(rule: rule);
      expect(calc.occurrenceInWeek(DateTime(2026, 10, 5)), isNull);
      expect(
        _describe(calc.occurrenceInWeek(DateTime(2026, 10, 13))),
        '10/13 3限 1301〜1400',
      );
    });
  });

  group('その日にテストがあるか（occurrenceOn）', () {
    test('9/28 はあり、9/29 はなし', () {
      final calc = _calc();
      expect(calc.occurrenceOn(DateTime(2026, 9, 28)), isNotNull);
      expect(calc.occurrenceOn(DateTime(2026, 9, 29)), isNull);
    });
  });
}
