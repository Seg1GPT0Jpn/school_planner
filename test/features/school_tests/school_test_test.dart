import 'package:flutter_test/flutter_test.dart';
import 'package:school_planner/features/school_tests/school_test.dart';

void main() {
  test('画面に出す名前は「科目 名前」', () {
    final t = SchoolTest(
      kind: SchoolTestKind.quiz,
      title: '漢字テスト',
      subject: '現代の国語',
      date: DateTime(2026, 10, 1),
    );
    expect(t.displayTitle, '現代の国語 漢字テスト');
  });

  test('科目がない行事は、名前だけ', () {
    final t = SchoolTest(
      kind: SchoolTestKind.schoolEvent,
      title: '文化祭',
      date: DateTime(2026, 10, 1),
    );
    expect(t.displayTitle, '文化祭');
  });

  test('名前が空ならエラー、時限は1〜5', () {
    expect(
      SchoolTest(
        kind: SchoolTestKind.quiz,
        title: ' ',
        date: DateTime(2026, 10, 1),
      ).validate(),
      isNotNull,
    );
    expect(
      SchoolTest(
        kind: SchoolTestKind.quiz,
        title: '単語テスト',
        date: DateTime(2026, 10, 1),
        period: 6,
      ).validate(),
      isNotNull,
    );
  });

  test('国語の小テストの候補', () {
    expect(quizPresets['現代の国語'], ['漢字テスト', '単語テスト']);
    expect(quizPresets['言語文化'], ['単語テスト', '文法テスト']);
  });

  test('テストの仲間かどうか', () {
    expect(SchoolTestKind.quiz.isTest, isTrue);
    expect(SchoolTestKind.regularExam.isTest, isTrue);
    expect(SchoolTestKind.assignment.isTest, isFalse);
  });
}
