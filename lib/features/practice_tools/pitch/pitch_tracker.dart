/// ピッチトラッカー（検出結果を安定させる／Auto Modeの「不確実」判定）
///
/// 1回1回の検出はどうしてもブレる（特にビブラートや倍音のせいで揺れる）ので、
/// ・直近数回のメディアン（中央値）でスパイクを弾く
/// ・そのうえで指数平滑化して、表示のガタつきを抑える
/// という2段階でならす。
///
/// また、confidence（周期性の強さ）が低いときは「certain: false」を返し、
/// 呼び出し側はそれを見て「検出不確実」と表示する（無理に音名を出さない）。
library;

import 'dart:collection';

import 'pitch_algorithms.dart';

class TrackedPitch {
  const TrackedPitch({
    required this.frequency,
    required this.confidence,
    required this.certain,
  });

  /// ならした後の周波数
  final double frequency;

  /// 直近の検出の信頼度（0〜1）
  final double confidence;

  /// これ以上信頼できる、とみなせるか（false なら「検出不確実」表示にする）
  final bool certain;
}

class PitchTracker {
  PitchTracker({
    this.historySize = 5,
    this.smoothingAlpha = 0.35,
    this.certaintyThreshold = 0.5,
  });

  /// メディアンを取る、直近何回ぶんか
  final int historySize;

  /// 指数平滑化の強さ（0〜1。大きいほど追従が速く、ガタつきやすい）
  final double smoothingAlpha;

  /// これ未満の confidence は「不確実」とみなす
  final double certaintyThreshold;

  final Queue<double> _recentFreqs = Queue();
  double? _smoothed;

  /// 新しい検出結果を1つ渡す。無音・雑音（null）なら履歴をリセットする。
  TrackedPitch? push(PitchCandidate? candidate) {
    if (candidate == null) {
      reset();
      return null;
    }
    _recentFreqs.add(candidate.frequency);
    while (_recentFreqs.length > historySize) {
      _recentFreqs.removeFirst();
    }
    final median = _median(_recentFreqs.toList()..sort());
    _smoothed = _smoothed == null
        ? median
        : _smoothed! + smoothingAlpha * (median - _smoothed!);

    return TrackedPitch(
      frequency: _smoothed!,
      confidence: candidate.confidence,
      certain: candidate.confidence >= certaintyThreshold,
    );
  }

  double _median(List<double> sorted) {
    final n = sorted.length;
    if (n == 0) return 0;
    if (n.isOdd) return sorted[n ~/ 2];
    return (sorted[n ~/ 2 - 1] + sorted[n ~/ 2]) / 2;
  }

  void reset() {
    _recentFreqs.clear();
    _smoothed = null;
  }
}
