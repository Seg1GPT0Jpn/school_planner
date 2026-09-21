import 'package:flutter_test/flutter_test.dart';
import 'package:school_planner/features/grades/grade.dart';
import 'package:school_planner/features/grades/grade_repository.dart';

void main() {
  test('平均点と標準偏差から偏差値を計算', () {
    expect(deviationFromStats(score: 70, average: 60, stdDev: 10), 60);
    expect(deviationFromStats(score: 45, average: 60, stdDev: 12), 37.5);
    // 標準偏差がないと計算できない
    expect(deviationFromStats(score: 70, average: 60), isNull);
    expect(deviationFromStats(score: 70, average: 60, stdDev: 0), isNull);
  });

  test('順位と受験者数から偏差値を推定', () {
    expect(deviationFromRank(rank: 20, participants: 240), 64.0);
    expect(deviationFromRank(rank: 12, participants: 240), 66.7);
    expect(deviationFromRank(rank: 120, participants: 240), 50.1);
    expect(deviationFromRank(rank: 1, participants: 40), 72.4);
    expect(deviationFromRank(rank: 40, participants: 40), 27.6);
    expect(deviationFromRank(rank: 50, participants: 40), isNull);
    expect(deviationFromRank(rank: 3), isNull);
  });

  test('空の偏差値だけを自動で入れる（標準偏差 → 順位 の順）', () {
    const typed = GradeEntry(
      subject: '数学',
      score: 70,
      average: 60,
      stdDev: 10,
      deviation: 55,
    );
    expect(typed.withAutoDeviation(participants: 240).deviation, 55);

    final byStats = const GradeEntry(
      subject: '数学',
      score: 70,
      average: 60,
      stdDev: 10,
      rank: 20,
    ).withAutoDeviation(participants: 240);
    expect(byStats.deviation, 60);
    expect(byStats.deviationSource, DeviationSource.stats);
    expect(byStats.isDeviationEstimated, isFalse);

    final byRank = const GradeEntry(
      subject: '数学',
      score: 70,
      average: 60,
      rank: 20,
    ).withAutoDeviation(participants: 240);
    expect(byRank.deviation, 64.0);
    expect(byRank.isDeviationEstimated, isTrue);

    final none = const GradeEntry(
      subject: '数学',
      score: 70,
      average: 60,
    ).withAutoDeviation();
    expect(none.deviation, isNull);
  });

  test('自動の偏差値は保存せず、読むたびに計算し直す', () {
    final exam = Exam(
      title: '前期期末',
      date: DateTime(2026, 9, 25),
      totalRank: 20,
      participants: 240,
      entries: const [
        GradeEntry(subject: '数学', score: 70, average: 60, stdDev: 10),
        GradeEntry(subject: '英語', score: 80, deviation: 62),
      ],
    ).withAutoDeviations();

    expect(exam.totalDeviation, 64.0);
    expect(exam.isTotalDeviationEstimated, isTrue);
    expect(exam.entries.first.deviation, 60);

    final map = GradeRepository.toMap(exam);
    expect(map['totalDeviation'], isNull);
    final entries = map['entries'] as List;
    expect((entries.first as Map)['deviation'], isNull);
    expect((entries.first as Map)['stdDev'], 10);
    expect((entries.last as Map)['deviation'], 62);

    final back = GradeRepository.fromMap('x', map);
    expect(back.totalDeviation, 64.0);
    expect(back.entries.first.deviation, 60);
    expect(back.entries.last.deviation, 62);
    expect(back.entries.last.deviationSource, DeviationSource.entered);
  });
}
