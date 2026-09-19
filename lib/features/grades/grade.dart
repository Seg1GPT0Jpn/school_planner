/// 成績
library;

enum ExamKind {
  regular('定期テスト'),
  quiz('小テスト');

  const ExamKind(this.label);
  final String label;
}

class GradeEntry {
  const GradeEntry({
    required this.subject,
    required this.score,
    this.max = 100,
    this.average,
    this.rank,
  });

  final String subject;
  final num score;
  final num max;
  final num? average;
  final int? rank;

  double get percent => max <= 0 ? 0 : (score / max).clamp(0, 1).toDouble();
}

class Exam {
  const Exam({
    this.id,
    required this.title,
    this.kind = ExamKind.regular,
    required this.date,
    this.entries = const [],
    this.totalRank,
  });

  final String? id;
  final String title;
  final ExamKind kind;
  final DateTime date;
  final List<GradeEntry> entries;

  /// 総合順位
  final int? totalRank;

  num get total => entries.fold<num>(0, (s, e) => s + e.score);
  num get maxTotal => entries.fold<num>(0, (s, e) => s + e.max);

  /// すべての科目に平均点があるときだけ、平均点の合計
  num? get averageTotal =>
      entries.isNotEmpty && entries.every((e) => e.average != null)
      ? entries.fold<num>(0, (s, e) => s + e.average!)
      : null;
}

/// その科目の点数の推移（古い順）
List<(Exam, GradeEntry)> subjectHistory(List<Exam> exams, String subject) {
  final list = [
    for (final ex in exams)
      for (final e in ex.entries)
        if (e.subject == subject) (ex, e),
  ]..sort((a, b) => a.$1.date.compareTo(b.$1.date));
  return list;
}

/// 数字の表示（85.0 → 85）
String numText(num v) => v == v.roundToDouble() ? '${v.toInt()}' : '$v';
