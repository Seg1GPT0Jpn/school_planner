import 'package:flutter_test/flutter_test.dart';
import 'package:school_planner/features/grades/grade.dart';
import 'package:school_planner/features/grades/grade_chart.dart';
import 'package:school_planner/features/grades/grade_repository.dart';

void main() {
  final exams = [
    Exam(
      title: '後期中間試験',
      date: DateTime(2026, 11, 25),
      totalRank: 20,
      totalDeviation: 58.5,
      participants: 240,
      entries: const [
        GradeEntry(
          subject: '数学Ⅰ',
          score: 82,
          average: 65,
          rank: 12,
          deviation: 61,
        ),
        GradeEntry(subject: 'ECⅠ', score: 90, average: 70),
      ],
    ),
    Exam(
      title: '前期期末試験',
      date: DateTime(2026, 7, 10),
      entries: const [GradeEntry(subject: '数学Ⅰ', score: 35, max: 50)],
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
    expect(h.map((x) => x.$2.score).toList(), [35, 82]);
  });

  test('割合', () {
    expect(const GradeEntry(subject: 'x', score: 45, max: 50).percent, 0.9);
  });

  test('点数のグラフは100点満点に換算・古い順', () {
    final s = chartSeries(exams, '数学Ⅰ', GradeMetric.score);
    expect(s.map((p) => p.value).toList(), [70, 82]);
    expect(s.map((p) => p.average).toList(), [null, 65]);
  });

  test('偏差値・順位は記録があるテストだけ', () {
    expect(
      chartSeries(exams, '数学Ⅰ', GradeMetric.deviation).map((p) => p.value),
      [61],
    );
    expect(chartSeries(exams, '数学Ⅰ', GradeMetric.rank).map((p) => p.value), [
      12,
    ]);
    expect(chartSeries(exams, 'ECⅠ', GradeMetric.deviation), isEmpty);
  });

  test('総合', () {
    final s = chartSeries(exams, totalSubject, GradeMetric.score);
    expect(s.map((p) => p.value).toList(), [70, 86]);
    expect(
      chartSeries(exams, totalSubject, GradeMetric.deviation).single.value,
      58.5,
    );
    expect(chartSeries(exams, totalSubject, GradeMetric.rank).single.value, 20);
  });

  test('グラフの縦の範囲', () {
    final pts = chartSeries(exams, '数学Ⅰ', GradeMetric.deviation);
    expect(chartRange(pts, GradeMetric.deviation, 65), (lo: 55.0, hi: 70.0));
    expect(chartRange(pts, GradeMetric.score, null), (lo: 0.0, hi: 100.0));
    expect(chartRange(const [], GradeMetric.rank, null).lo, 1);
  });

  test('目標ラインの変更と保存形式', () {
    const t = GradeTarget(deviation: 65);
    final t2 = t.withValue(GradeMetric.rank, 10);
    expect(t2.deviation, 65);
    expect(t2.rank, 10);
    expect(
      t2
          .withValue(GradeMetric.deviation, null)
          .withValue(GradeMetric.rank, null)
          .isEmpty,
      isTrue,
    );

    final key = targetKey(ExamKind.regular, '数学Ⅰ');
    final back = GradeRepository.targetsFromMap(
      GradeRepository.targetsToMap({key: t2}),
    );
    expect(back[key]!.deviation, 65);
    expect(back[key]!.rank, 10);
    expect(back[key]!.score, isNull);
  });

  test('成績の保存形式（偏差値・受験者数）', () {
    final m = GradeRepository.toMap(exams[0]);
    final back = GradeRepository.fromMap('x', m);
    expect(back.totalDeviation, 58.5);
    expect(back.participants, 240);
    expect(back.entries.first.deviation, 61);
  });

  test('数字の表示', () {
    expect(numText(85.0), '85');
    expect(numText(58.5), '58.5');
    expect(numText(61.26), '61.3');
  });
}
