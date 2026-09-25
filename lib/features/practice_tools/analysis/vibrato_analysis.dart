/// ビブラート分析：ピッチ履歴から、揺れの速さ・幅・規則性を推定する
///
/// 判定できるだけのデータがない、またはビブラートらしい規則性がないときは
/// 無理に判定せず null を返す（不確かな結果を「正しい分析」として出さない）。
library;

import 'dart:math' as math;

import 'long_tone_analysis.dart' show TimedCents;

class VibratoStats {
  const VibratoStats({
    required this.rateHz,
    required this.extentCents,
    required this.regularity,
  });

  /// 揺れの速さ（1秒あたりの往復回数の目安）
  final double rateHz;

  /// 揺れの幅（セント。中心からの最大のずれ）
  final double extentCents;

  /// 規則性（0〜1。1に近いほど周期が揃っている）
  final double regularity;

  String get description =>
      '${rateHz.toStringAsFixed(1)}Hz・幅±${extentCents.toStringAsFixed(1)}¢・'
      '規則性${(regularity * 100).round()}%';
}

/// 一般的なビブラートは、だいたい 3〜8Hz くらいとされる。それより極端に
/// 速い／遅い揺れは、ビブラートというより雑音や音程の揺らぎとみなす。
const double _minPlausibleRate = 2.0;
const double _maxPlausibleRate = 10.0;

VibratoStats? analyzeVibrato(List<TimedCents> samples) {
  if (samples.length < 10) return null;
  final duration = samples.last.t - samples.first.t;
  if (duration < 1.0) return null; // 判定するには短すぎる

  final values = [for (final s in samples) s.cents];
  final mean = values.reduce((a, b) => a + b) / values.length;
  final detrended = [for (final v in values) v - mean];

  // ゼロ交差（上向き）の時刻を集めて、周期を推定する
  final crossTimes = <double>[];
  for (var i = 1; i < detrended.length; i++) {
    if (detrended[i - 1] < 0 && detrended[i] >= 0) {
      final t0 = samples[i - 1].t;
      final t1 = samples[i].t;
      final v0 = detrended[i - 1];
      final v1 = detrended[i];
      final frac = v1 == v0 ? 0.0 : (-v0) / (v1 - v0);
      crossTimes.add(t0 + frac * (t1 - t0));
    }
  }
  if (crossTimes.length < 3) return null; // 往復が少なすぎて判定できない

  final periods = [
    for (var i = 1; i < crossTimes.length; i++) crossTimes[i] - crossTimes[i - 1],
  ];
  final meanPeriod = periods.reduce((a, b) => a + b) / periods.length;
  if (meanPeriod <= 0) return null;
  final rateHz = 1 / meanPeriod;
  if (rateHz < _minPlausibleRate || rateHz > _maxPlausibleRate) return null;

  var periodVarSum = 0.0;
  for (final p in periods) {
    periodVarSum += (p - meanPeriod) * (p - meanPeriod);
  }
  final periodStd = math.sqrt(periodVarSum / periods.length);
  final regularity = (1 - (periodStd / meanPeriod)).clamp(0.0, 1.0);

  final extent = detrended.map((v) => v.abs()).reduce(math.max);

  return VibratoStats(rateHz: rateHz, extentCents: extent, regularity: regularity);
}
