import 'package:flutter_test/flutter_test.dart';
import 'package:school_planner/core/japanese_holidays.dart';
import 'package:school_planner/features/school_tests/initial_rules.dart';
import 'package:school_planner/features/school_tests/school_test.dart';
import 'package:school_planner/features/school_tests/upcoming_tests.dart';
import 'package:school_planner/features/timetable/day_timetable_resolver.dart';
import 'package:school_planner/features/timetable/initial_data.dart';
import 'package:school_planner/features/timetable/school_periods.dart';
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

void main() {
  test('9/19 から2週間：9/28 の LEAP と、手で登録した小テストが日付順に並ぶ', () {
    final items = collectUpcoming(
      from: DateTime(2026, 9, 19),
      days: 14,
      resolver: _resolver(),
      rules: [leapRule],
      schoolTests: [
        SchoolTest(
          kind: SchoolTestKind.quiz,
          title: '漢字テスト',
          subject: '現代の国語',
          date: DateTime(2026, 9, 30),
          period: 2,
          scope: 'p.20〜35',
        ),
        // 2週間より先のものは入らない
        SchoolTest(
          kind: SchoolTestKind.quiz,
          title: '単語テスト',
          subject: '言語文化',
          date: DateTime(2026, 10, 10),
        ),
      ],
    );

    expect(items.length, 2);
    expect(items[0].title, 'ECⅠ LEAP単語テスト');
    expect(items[0].detail, '1201〜1300');
    expect(items[0].date, DateTime(2026, 9, 28));
    expect(items[1].title, '現代の国語 漢字テスト');
    expect(items[1].daysFrom(DateTime(2026, 9, 19)), 11);
  });

  test('試験日課の日に試験科目が入っていれば、定期テストとして並ぶ', () {
    final items = collectUpcoming(
      from: DateTime(2026, 11, 20),
      days: 14,
      resolver: _resolver(
        extra: [
          DayOverride(
            date: DateTime(2026, 11, 25),
            schedule: DaySchedule.exam,
            note: '後期中間試験',
            changes: const [PeriodChange.replace(period: 1, subject: '数学Ⅰ')],
          ),
        ],
      ),
      rules: [leapRule],
      schoolTests: const [],
    );

    final titles = items.map((i) => i.title).toList();
    // 11/24（短縮日課）の LEAP → 11/25 の試験 → 12/1 の LEAP の順
    expect(titles.first, 'ECⅠ LEAP単語テスト');
    expect(items.first.date, DateTime(2026, 11, 24));
    expect(titles, contains('後期中間試験 数学Ⅰ'));
    final exam = items.firstWhere((i) => i.title == '後期中間試験 数学Ⅰ');
    expect(exam.kindLabel, '定期テスト');
    expect(exam.period, 1);
  });

  test('提出物は「テストの仲間」ではない', () {
    final items = collectUpcoming(
      from: DateTime(2026, 9, 19),
      days: 14,
      resolver: _resolver(),
      rules: const [],
      schoolTests: [
        SchoolTest(
          kind: SchoolTestKind.assignment,
          title: 'レポート提出',
          date: DateTime(2026, 9, 25),
        ),
      ],
    );
    expect(items.single.isTest, isFalse);
    expect(items.single.kindLabel, '提出物');
  });
}
