/// テストカルテの集計（画面に依存しない計算だけ）
library;

import '../grades/grade.dart';
import '../study/study.dart';
import 'review_models.dart';

/// 試験前として数える日数（試験の日もふくむ）
const int karteStudyDays = 14;

class KarteData {
  const KarteData({
    required this.windowStart,
    required this.subjectMinutes,
    required this.allMinutes,
    required this.daily,
    this.grade,
    this.previous,
    this.score,
    this.max,
  });

  /// 勉強時間を数え始めた日
  final DateTime windowStart;

  /// その科目の勉強時間（試験前の期間）
  final int subjectMinutes;

  /// すべての科目の勉強時間（同じ期間）
  final int allMinutes;

  /// その科目の毎日の勉強時間（古い順）
  final List<int> daily;

  /// 「成績」に記録した、このテストの結果
  final (Exam, GradeEntry)? grade;

  /// その前の、同じ科目の成績
  final (Exam, GradeEntry)? previous;

  /// このテストの点数（カルテで入れたもの → なければ成績）
  final num? score;
  final num? max;

  double? get percent =>
      score == null || max == null || max! <= 0 ? null : score! / max! * 100;

  double? get previousPercent => previous == null
      ? null
      : previous!.$2.max <= 0
      ? null
      : previous!.$2.score / previous!.$2.max * 100;

  /// 前回との差（100点満点に直したとき）
  double? get diff => percent == null || previousPercent == null
      ? null
      : percent! - previousPercent!;
}

/// テストカルテを作る
KarteData buildKarte({
  required DateTime date,
  String? subject,
  List<StudySession> sessions = const [],
  List<Exam> exams = const [],
  TestReview? review,
  int days = karteStudyDays,
}) {
  final day = DateTime(date.year, date.month, date.day);
  final from = DateTime(day.year, day.month, day.day - days + 1);
  final to = DateTime(day.year, day.month, day.day + 1);

  final mine = subject == null
      ? const <StudySession>[]
      : [
          for (final s in sessions)
            if (s.subject == subject) s,
        ];

  // 「成績」の中から、このテストの結果を探す（同じ科目で、日付がいちばん近いもの。10日以内）
  (Exam, GradeEntry)? grade;
  (Exam, GradeEntry)? previous;
  if (subject != null) {
    final history = subjectHistory(exams, subject); // 古い順
    var best = 11;
    for (final h in history) {
      final gap = h.$1.date.difference(day).inDays.abs();
      if (gap <= 10 && gap < best) {
        best = gap;
        grade = h;
      }
    }
    // その前の成績
    final before =
        grade?.$1.date ?? DateTime(day.year, day.month, day.day - 10);
    for (final h in history) {
      if (h.$1.date.isBefore(before)) previous = h;
    }
  }

  final score = review?.score ?? grade?.$2.score;
  final max = review?.score != null ? review!.maxScore : grade?.$2.max;

  return KarteData(
    windowStart: from,
    subjectMinutes: totalMinutes(mine, from, to),
    allMinutes: totalMinutes(sessions, from, to),
    daily: dailyMinutes(mine, day, days),
    grade: grade,
    previous: previous,
    score: score,
    max: max,
  );
}
