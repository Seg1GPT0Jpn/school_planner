import 'package:flutter_test/flutter_test.dart';
import 'package:school_planner/features/grades/grade.dart';

void main() {
  final exams = [
    Exam(
      title: '後期中間試験',
      date: DateTime(2026, 11, 25),
      entries: const [
        GradeEntry(subject: '数学Ⅰ', score: 82, average: 65, rank: 12),
        GradeEntry(subject: 'ECⅠ', score: 90, average: 70),
      ],
    ),
    Exam(
      title: '前期期末試験',
      date: DateTime(2026, 7, 10),
      entries: const [GradeEntry(subject: '数学Ⅰ', score: 70)],
    ),
  ];

  test('合計・満点の合計・平均点の合計', () {
    expect(exams[0].total, 172);
    expect(exams[0].maxTotal, 200);
    expect(exams[0].averageTotal, 135);
    expect(exams[1].averageTotal, isNull);
  });

  test('科目の推移は古い順', () {
    final h = subjectHistory(exams, '数学Ⅰ');
    expect(h.map((x) => x.$2.score).toList(), [70, 82]);
  });

  test('割合', () {
    expect(const GradeEntry(subject: 'x', score: 45, max: 50).percent, 0.9);
  });
}
