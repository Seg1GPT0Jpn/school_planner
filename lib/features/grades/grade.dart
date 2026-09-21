/// 成績
library;

import 'dart:math' as math;

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

/// 偏差値をどうやって出したか
enum DeviationSource {
  /// 自分で入れた
  entered,

  /// 平均点と標準偏差から計算した（正確）
  stats,

  /// 順位と受験者数から推定した（めやす）
  rank,
}

/// 平均点と標準偏差から偏差値を計算する（標準偏差がないと計算できない）
double? deviationFromStats({required num score, num? average, num? stdDev}) {
  if (average == null || stdDev == null || stdDev <= 0) return null;
  return _round1(50 + 10 * (score - average) / stdDev);
}

/// 順位と受験者数から偏差値を推定する（点数が正規分布だとみなす）
double? deviationFromRank({int? rank, int? participants}) {
  if (rank == null || participants == null) return null;
  if (participants < 2 || rank < 1 || rank > participants) return null;
  // 自分より上の人の割合（真ん中をとる）
  final above = (rank - 0.5) / participants;
  return _round1(50 + 10 * _inverseNormal(1 - above));
}

double _round1(double v) => (v * 10).roundToDouble() / 10;

/// 標準正規分布の逆関数（Acklam の近似。誤差は 1e-9 ほど）
double _inverseNormal(double p) {
  const a = [
    -3.969683028665376e+01,
    2.209460984245205e+02,
    -2.759285104469687e+02,
    1.383577518672690e+02,
    -3.066479806614716e+01,
    2.506628277459239e+00,
  ];
  const b = [
    -5.447609879822406e+01,
    1.615858368580409e+02,
    -1.556989798598866e+02,
    6.680131188771972e+01,
    -1.328068155288572e+01,
  ];
  const c = [
    -7.784894002430293e-03,
    -3.223964580411365e-01,
    -2.400758277161838e+00,
    -2.549732539343734e+00,
    4.374664141464968e+00,
    2.938163982698783e+00,
  ];
  const d = [
    7.784695709041462e-03,
    3.224671290700398e-01,
    2.445134137142996e+00,
    3.754408661907416e+00,
  ];
  const low = 0.02425, high = 1 - low;
  if (p <= 0) return -8;
  if (p >= 1) return 8;
  if (p < low) {
    final q = _sqrt(-2 * _ln(p));
    return (((((c[0] * q + c[1]) * q + c[2]) * q + c[3]) * q + c[4]) * q +
            c[5]) /
        ((((d[0] * q + d[1]) * q + d[2]) * q + d[3]) * q + 1);
  }
  if (p > high) {
    final q = _sqrt(-2 * _ln(1 - p));
    return -(((((c[0] * q + c[1]) * q + c[2]) * q + c[3]) * q + c[4]) * q +
            c[5]) /
        ((((d[0] * q + d[1]) * q + d[2]) * q + d[3]) * q + 1);
  }
  final q = p - 0.5, r = q * q;
  return (((((a[0] * r + a[1]) * r + a[2]) * r + a[3]) * r + a[4]) * r + a[5]) *
      q /
      (((((b[0] * r + b[1]) * r + b[2]) * r + b[3]) * r + b[4]) * r + 1);
}

double _sqrt(double x) => math.sqrt(x);
double _ln(double x) => math.log(x);

class GradeEntry {
  const GradeEntry({
    required this.subject,
    required this.score,
    this.max = 100,
    this.average,
    this.rank,
    this.deviation,
    this.stdDev,
    this.deviationSource = DeviationSource.entered,
  });

  final String subject;
  final num score;
  final num max;
  final num? average;
  final int? rank;

  /// 偏差値（自分で入れたもの。空なら自動で計算したもの）
  final num? deviation;

  /// 標準偏差（成績表に書いてあれば）
  final num? stdDev;

  /// 偏差値をどうやって出したか
  final DeviationSource deviationSource;

  /// 偏差値が推定か（順位から出したもの）
  bool get isDeviationEstimated => deviationSource == DeviationSource.rank;

  /// 偏差値が空なら、平均点と標準偏差 → 順位と受験者数 の順に計算して入れる
  GradeEntry withAutoDeviation({int? participants}) {
    if (deviation != null && deviationSource == DeviationSource.entered) {
      return this;
    }
    final byStats = deviationFromStats(
      score: score,
      average: average,
      stdDev: stdDev,
    );
    final byRank = byStats == null
        ? deviationFromRank(rank: rank, participants: participants)
        : null;
    return GradeEntry(
      subject: subject,
      score: score,
      max: max,
      average: average,
      rank: rank,
      stdDev: stdDev,
      deviation: byStats ?? byRank,
      deviationSource: byStats != null
          ? DeviationSource.stats
          : (byRank != null ? DeviationSource.rank : DeviationSource.entered),
    );
  }

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
    this.totalDeviationSource = DeviationSource.entered,
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

  /// 総合偏差値をどうやって出したか
  final DeviationSource totalDeviationSource;

  bool get isTotalDeviationEstimated =>
      totalDeviationSource == DeviationSource.rank;

  /// 空の偏差値を自動で入れたもの（科目ごとと総合）
  Exam withAutoDeviations() {
    final total =
        totalDeviation != null &&
            totalDeviationSource == DeviationSource.entered
        ? null
        : deviationFromRank(rank: totalRank, participants: participants);
    return Exam(
      id: id,
      title: title,
      kind: kind,
      date: date,
      entries: [
        for (final e in entries)
          e.withAutoDeviation(participants: participants),
      ],
      totalRank: totalRank,
      participants: participants,
      totalDeviation: total ?? totalDeviation,
      totalDeviationSource: total != null
          ? DeviationSource.rank
          : totalDeviationSource,
    );
  }

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
