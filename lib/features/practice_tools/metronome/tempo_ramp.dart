/// テンポの自動変化（だんだん速く／遅く／往復／ランダム）
///
/// トランペットのタンギングや指回しの練習で「限界テンポまで少しずつ上げる」
/// ような使い方を想定している。
library;

import 'dart:math';

enum TempoRampMode { off, up, down, bounce, random }

extension TempoRampModeX on TempoRampMode {
  String get label => switch (this) {
    TempoRampMode.off => 'なし',
    TempoRampMode.up => 'だんだん速く',
    TempoRampMode.down => 'だんだん遅く',
    TempoRampMode.bounce => '往復（行ったり来たり）',
    TempoRampMode.random => 'ランダム',
  };
}

/// テンポ自動変化の設定
class TempoRamp {
  const TempoRamp({
    this.mode = TempoRampMode.off,
    this.stepBpm = 4,
    this.everyBars = 4,
    this.minBpm = 60,
    this.maxBpm = 160,
  });

  final TempoRampMode mode;

  /// 1回に変化させるBPM
  final int stepBpm;

  /// 何小節ごとに変化させるか
  final int everyBars;

  final int minBpm;
  final int maxBpm;

  TempoRamp copyWith({
    TempoRampMode? mode,
    int? stepBpm,
    int? everyBars,
    int? minBpm,
    int? maxBpm,
  }) => TempoRamp(
    mode: mode ?? this.mode,
    stepBpm: stepBpm ?? this.stepBpm,
    everyBars: everyBars ?? this.everyBars,
    minBpm: minBpm ?? this.minBpm,
    maxBpm: maxBpm ?? this.maxBpm,
  );

  /// [barsElapsed] 小節ぶん経過した時点でのBPMを、開始BPM [startBpm] から計算する。
  /// [bounceDirectionUp] は往復モードの、現在向かっている方向（true＝上昇中）を
  /// 呼び出し側が保持し、折り返しの判定に使う（呼び出し側で更新すること）。
  int bpmAfter(int startBpm, int barsElapsed, {required bool bounceDirectionUp}) {
    if (mode == TempoRampMode.off || everyBars <= 0) return startBpm;
    final steps = barsElapsed ~/ everyBars;
    switch (mode) {
      case TempoRampMode.up:
        return (startBpm + steps * stepBpm).clamp(minBpm, maxBpm).toInt();
      case TempoRampMode.down:
        return (startBpm - steps * stepBpm).clamp(minBpm, maxBpm).toInt();
      case TempoRampMode.bounce:
        final range = max(1, maxBpm - minBpm);
        final span = range * 2;
        final pos = (steps * stepBpm) % span;
        final bpm = pos <= range ? minBpm + pos : minBpm + (span - pos);
        return bpm.clamp(minBpm, maxBpm).toInt();
      case TempoRampMode.random:
        // 小節ごとに疑似ランダム（同じ小節番号なら同じ値になるよう、簡易ハッシュを種にする）
        final seed = steps * 2654435761 % 1000000007;
        final rand = Random(seed);
        return minBpm + rand.nextInt(max(1, maxBpm - minBpm + 1));
      case TempoRampMode.off:
        return startBpm;
    }
  }
}
