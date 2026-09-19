import 'package:flutter_test/flutter_test.dart';
import 'package:school_planner/core/japanese_holidays.dart';
import 'package:school_planner/features/school_tests/initial_rules.dart';
import 'package:school_planner/features/school_tests/lesson_test_annotation.dart';
import 'package:school_planner/features/school_tests/school_test.dart';
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

DayTimetable _annotate(DateTime date, {List<SchoolTest> manual = const []}) {
  final base = _base();
  final calculators = [
    WeeklyLessonTestCalculator(rule: leapRule, resolver: base),
  ];
  return annotateLessonTests(
    base.resolve(date),
    calculators,
    manualTests: manual,
  );
}

void main() {
  test('9/28 の2限（ECⅠ）に LEAP の印が付く', () {
    final day = _annotate(DateTime(2026, 9, 28));
    expect(day.hasTests, isTrue);
    expect(day.lessons[1].subject, 'ECⅠ');
    expect(day.lessons[1].testLabel, 'LEAP単語テスト 1201〜1300');
    // ほかの授業には付かない
    expect(day.lessons[0].testLabel, isNull);
  });

  test('9/29 には印が付かない（同じ週の2回目以降の ECⅠ）', () {
    final day = _annotate(DateTime(2026, 9, 29));
    expect(day.hasTests, isFalse);
  });

  test('印を付けても、時間割そのものは変わらない', () {
    final plain = _base().resolve(DateTime(2026, 9, 28));
    final withTest = _annotate(DateTime(2026, 9, 28));
    expect(
      withTest.lessons.map((l) => l.subject).toList(),
      plain.lessons.map((l) => l.subject).toList(),
    );
  });

  test('手で登録した小テストも、その時限の授業に印が付く', () {
    // 10/6（火・Ⅰ週）1限は現代の国語
    final day = _annotate(
      DateTime(2026, 10, 6),
      manual: [
        SchoolTest(
          kind: SchoolTestKind.quiz,
          title: '漢字テスト',
          subject: '現代の国語',
          date: DateTime(2026, 10, 6),
          period: 1,
          scope: 'p.20〜35',
        ),
      ],
    );
    expect(day.lessons[0].subject, '現代の国語');
    expect(day.lessons[0].testLabel, '漢字テスト p.20〜35');
  });

  test('同じ授業に LEAP と手で登録した小テストがあれば、両方をつなぐ', () {
    final day = _annotate(
      DateTime(2026, 9, 28),
      manual: [
        SchoolTest(
          kind: SchoolTestKind.quiz,
          title: '音読テスト',
          subject: 'ECⅠ',
          date: DateTime(2026, 9, 28),
          period: 2,
        ),
      ],
    );
    expect(day.lessons[1].testLabel, 'LEAP単語テスト 1201〜1300 / 音読テスト');
  });

  test('時限を指定していない小テストは、授業には印を付けない', () {
    final day = _annotate(
      DateTime(2026, 10, 6),
      manual: [
        SchoolTest(
          kind: SchoolTestKind.assignment,
          title: 'レポート提出',
          date: DateTime(2026, 10, 6),
        ),
      ],
    );
    expect(day.hasTests, isFalse);
  });
}
