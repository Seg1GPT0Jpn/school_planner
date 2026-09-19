import 'package:flutter_test/flutter_test.dart';
import 'package:school_planner/features/school_tests/school_test.dart';
import 'package:school_planner/features/school_tests/school_test_repository.dart';
import 'package:school_planner/features/school_tests/weekly_lesson_test.dart';

void main() {
  test('小テストの保存形式を行き来できる', () {
    final original = SchoolTest(
      id: 'x',
      kind: SchoolTestKind.quiz,
      title: '漢字テスト',
      date: DateTime(2026, 10, 6),
      subject: '現代の国語',
      period: 1,
      scope: 'p.20〜35',
    );
    final back = SchoolTestRepository.testFromMap(
      'x',
      SchoolTestRepository.testToMap(original),
    );
    expect(back.kind, SchoolTestKind.quiz);
    expect(back.title, '漢字テスト');
    expect(back.date, DateTime(2026, 10, 6));
    expect(back.subject, '現代の国語');
    expect(back.period, 1);
    expect(back.scope, 'p.20〜35');
  });

  test('ルールの保存形式を行き来できる（なしにした週も）', () {
    final original = WeeklyLessonTestRule(
      id: 'leap',
      subject: 'ECⅠ',
      title: 'LEAP単語テスト',
      baseWeekDate: DateTime(2026, 9, 28),
      baseRangeStart: 1201,
      skippedWeeks: const {'2026-10-05'},
    );
    final back = SchoolTestRepository.ruleFromMap(
      'leap',
      SchoolTestRepository.ruleToMap(original),
    );
    expect(back.subject, 'ECⅠ');
    expect(back.baseWeekDate, DateTime(2026, 9, 28));
    expect(back.baseRangeStart, 1201);
    expect(back.rangeStep, 100);
    expect(back.skippedWeeks, {'2026-10-05'});
  });
}
