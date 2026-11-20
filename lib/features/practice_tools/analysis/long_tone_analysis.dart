/// ロングトーン分析：伸ばした音の「時間ごとのセントのずれ」から統計を出す
library;

import 'dart:math' as math;

/// 時刻つきの、セントのずれ1点
class TimedCents {
  const TimedCents(this.t, this.cents);

  /// 秒（計測開始からの経過時間）
  final double t;
  final double cents;
}

class LongToneStats {
  const LongToneStats({
    required this.mean,
    required this.min,
    required this.max,
    required this.stdDev,
    required this.stabilityPercent,
    required this.holdSeconds,
    required this.startCents,
    required this.midCents,
    required this.endCents,
  });

  final double mean;
  final double min;
  final double max;

  /// 標準偏差（小さいほど安定）
  final double stdDev;

  /// 平均から±5セント以内に収まっていた割合（0〜100）
  final double stabilityPercent;

  /// 音を保持していた長さ（秒）
  final double holdSeconds;

  /// 立ち上がり直後・中間・終わりぎわ、それぞれの平均セント
  final double startCents;
  final double midCents;
  final double endCents;

  /// 「立ち上がり時だけ低い」「伸びるにつれて高くなる」などの、ひとこと所見
  String get trend {
    final startVsMid = midCents - startCents;
    final midVsEnd = endCents - midCents;
    if (startVsMid.abs() >= 4 && startVsMid.abs() > midVsEnd.abs()) {
      return startVsMid > 0 ? '立ち上がり時だけ低いようです' : '立ち上がり時だけ高いようです';
    }
    final overall = endCents - startCents;
    if (overall.abs() < 3) return '音の高さは安定して伸ばせています';
    return overall > 0 ? '音が伸びるにつれて高くなる傾向があります' : '音が伸びるにつれて低くなる傾向があります';
  }

  String get levelComment {
    if (mean.abs() <= 2) return 'この音は平均的にほぼ正確です';
    return mean > 0 ? 'この音は平均的に高めです（+${mean.toStringAsFixed(1)}¢）' : 'この音は平均的に低めです（${mean.toStringAsFixed(1)}¢）';
  }

  String get stabilityComment {
    if (stabilityPercent >= 85) return '安定しています';
    if (stabilityPercent >= 60) return 'やや揺れています';
    return '不安定です';
  }
}

/// [samples] は時系列順であること。3点未満なら判定できないので null。
LongToneStats? analyzeLongTone(List<TimedCents> samples) {
  if (samples.length < 3) return null;

  final values = [for (final s in samples) s.cents];
  final mean = values.reduce((a, b) => a + b) / values.length;
  final minV = values.reduce(math.min);
  final maxV = values.reduce(math.max);

  var sqSum = 0.0;
  for (final v in values) {
    sqSum += (v - mean) * (v - mean);
  }
  final stdDev = math.sqrt(sqSum / values.length);

  final within = values.where((v) => (v - mean).abs() <= 5).length;
  final stability = 100 * within / values.length;

  final holdSeconds = samples.last.t - samples.first.t;

  final n = samples.length;
  final seg = math.max(1, (n * 0.15).round());

  double avgOf(Iterable<TimedCents> it) {
    final l = it.toList();
    if (l.isEmpty) return 0;
    return l.map((s) => s.cents).reduce((a, b) => a + b) / l.length;
  }

  final start = avgOf(samples.take(seg));
  final end = avgOf(samples.skip(math.max(0, n - seg)));
  final midStart = ((n ~/ 2) - (seg ~/ 2)).clamp(0, math.max(0, n - 1)).toInt();
  final mid = avgOf(samples.skip(midStart).take(seg));

  return LongToneStats(
    mean: mean,
    min: minV,
    max: maxV,
    stdDev: stdDev,
    stabilityPercent: stability,
    holdSeconds: holdSeconds,
    startCents: start,
    midCents: mid,
    endCents: end,
  );
}
