/// 成績
library;

enum ExamKind {
  regular('定期テスト'),
  quiz('小テスト');

  const ExamKind(this.label);
  final String label;
}

/// グラフで見るもの
enum GradeMetric {
  score('点数'),
  deviation('偏差値'),
  rank('順位');

  const GradeMetric(this.label);
  final String label;
}

/// 推移で「テスト全体」を選ぶときの名前
const totalSubject = '総合';

class GradeEntry {
  const GradeEntry({
    required this.subject,
    required this.score,
    this.max = 100,
    this.average,
    this.rank,
    this.deviation,
  });

  final String subject;
  final num score;
  final num max;
  final num? average;
  final int? rank;

  /// 偏差値（手入力）
  final num? deviation;

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
    this.totalDeviation,
    this.participants,
  });

  final String? id;
  final String title;
  final ExamKind kind;
  final DateTime date;
  final List<GradeEntry> entries;

  /// 総合順位
  final int? totalRank;

  /// 総合偏差値
  final num? totalDeviation;

  /// 受験者数
  final int? participants;

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

/// グラフの1点
class ChartPoint {
  const ChartPoint({
    required this.date,
    required this.label,
    required this.value,
    this.average,
  });

  final DateTime date;
  final String label;
  final double value;

  /// 平均（点数のときだけ）
  final double? average;
}

double? _per100(num? v, num max) =>
    v == null || max <= 0 ? null : v * 100 / max;

/// 科目（または「総合」）の推移をグラフ用の点にする（古い順）
///
/// 点数は満点がテストごとに違っても比べられるよう「100点満点に換算」する。
/// その値がないテストは飛ばす。
List<ChartPoint> chartSeries(
  List<Exam> exams,
  String subject,
  GradeMetric metric,
) {
  final points = <ChartPoint>[];
  for (final ex in exams) {
    double? value;
    double? average;
    if (subject == totalSubject) {
      switch (metric) {
        case GradeMetric.score:
          value = _per100(ex.total, ex.maxTotal);
          average = _per100(ex.averageTotal, ex.maxTotal);
        case GradeMetric.deviation:
          value = ex.totalDeviation?.toDouble();
        case GradeMetric.rank:
          value = ex.totalRank?.toDouble();
      }
    } else {
      final e = ex.entries.where((x) => x.subject == subject).firstOrNull;
      if (e == null) continue;
      switch (metric) {
        case GradeMetric.score:
          value = _per100(e.score, e.max);
          average = _per100(e.average, e.max);
        case GradeMetric.deviation:
          value = e.deviation?.toDouble();
        case GradeMetric.rank:
          value = e.rank?.toDouble();
      }
    }
    if (value == null) continue;
    points.add(
      ChartPoint(
        date: ex.date,
        label: ex.title,
        value: value,
        average: average,
      ),
    );
  }
  points.sort((a, b) => a.date.compareTo(b.date));
  return points;
}

/// グラフに引く目標ライン（科目ごと）
class GradeTarget {
  const GradeTarget({this.score, this.deviation, this.rank});

  final num? score;
  final num? deviation;
  final int? rank;

  num? valueFor(GradeMetric m) => switch (m) {
    GradeMetric.score => score,
    GradeMetric.deviation => deviation,
    GradeMetric.rank => rank,
  };

  GradeTarget withValue(GradeMetric m, num? v) => GradeTarget(
    score: m == GradeMetric.score ? v : score,
    deviation: m == GradeMetric.deviation ? v : deviation,
    rank: m == GradeMetric.rank ? v?.toInt() : rank,
  );

  bool get isEmpty => score == null && deviation == null && rank == null;
}

/// 目標ラインの保存キー（定期テストと小テストで分ける）
String targetKey(ExamKind kind, String subject) => '${kind.name}|$subject';

/// 数字の表示（85.0 → 85、58.25 → 58.3）
String numText(num v) {
  if (v == v.roundToDouble()) return '${v.toInt()}';
  final s = v.toStringAsFixed(1);
  return s.endsWith('.0') ? s.substring(0, s.length - 2) : s;
}
