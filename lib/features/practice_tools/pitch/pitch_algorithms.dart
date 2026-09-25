/// ピッチ検出アルゴリズム（複数方式を切り替えられるようにする）
///
/// ・自己相関法（autocorrelation）：軽い・素直。倍音の影響をやや受けやすい
/// ・YIN法：自己相関の派生。しきい値を使って「基音らしい周期」を選ぶため、
///   倍音が強い音（金管楽器など）でも基音を見失いにくい
///
/// どちらも「時間領域」でみているので、そもそも単純なFFTピーク検出より
/// 倍音に惑わされにくい。そのうえで、楽器のクセ（[HarmonicQuirk]）に応じて
/// 「1オクターブ上に誤検出していないか」を追加でチェックする。
library;

import 'dart:math' as math;
import 'dart:typed_data';

import '../instruments/instrument_profile.dart';

enum PitchAlgorithm { autocorrelation, yin }

/// 検出された1候補（音量・周期性の強さを含む）
class PitchCandidate {
  const PitchCandidate({
    required this.frequency,
    required this.confidence,
    required this.rms,
  });

  final double frequency;

  /// 0〜1。1に近いほど「はっきりした音程」
  final double confidence;

  /// 音量の目安（0〜1くらい）
  final double rms;
}

double _rmsOf(Float64List buf) {
  var sum = 0.0;
  for (final v in buf) {
    sum += v * v;
  }
  return math.sqrt(sum / buf.length);
}

Float64List _toFloat(Uint8List pcm16LEBytes) {
  final n = pcm16LEBytes.length ~/ 2;
  final buf = Float64List(n);
  final bd = ByteData.sublistView(pcm16LEBytes);
  for (var i = 0; i < n; i++) {
    buf[i] = bd.getInt16(i * 2, Endian.little) / 32768.0;
  }
  return buf;
}

/// 自己相関法。ラグごとの相関を総当たりで求め、一番強い周期を選ぶ。
PitchCandidate? _autocorrelate(
  Float64List buf, {
  required int sampleRate,
  required int minLag,
  required int maxLag,
}) {
  final n = buf.length;
  var sumSq = 0.0;
  for (final v in buf) {
    sumSq += v * v;
  }
  var bestCorr = 0.0;
  var bestLag = -1;
  for (var lag = minLag; lag <= maxLag; lag++) {
    var corr = 0.0;
    final count = n - lag;
    for (var i = 0; i < count; i++) {
      corr += buf[i] * buf[i + lag];
    }
    corr /= count;
    if (corr > bestCorr) {
      bestCorr = corr;
      bestLag = lag;
    }
  }
  if (bestLag <= 0) return null;
  final energy = sumSq / n;
  final clarity = energy > 0 ? (bestCorr / energy).clamp(0.0, 1.0).toDouble() : 0.0;
  return PitchCandidate(
    frequency: sampleRate / bestLag,
    confidence: clarity,
    rms: _rmsOf(buf),
  );
}

/// YIN法（de Cheveigné & Kawahara, 2002 の簡易実装）
///
/// 「差分関数を累積平均で正規化し、しきい値を初めて下回ったところ」を
/// 基音の周期とみなす。倍音のピークに引っ張られにくいのが特徴。
PitchCandidate? _yin(
  Float64List buf, {
  required int sampleRate,
  required int minLag,
  required int maxLag,
  double threshold = 0.15,
}) {
  final n = buf.length;
  if (maxLag >= n) return null;

  final diff = Float64List(maxLag + 1);
  for (var lag = 1; lag <= maxLag; lag++) {
    var sum = 0.0;
    final count = n - lag;
    for (var i = 0; i < count; i++) {
      final d = buf[i] - buf[i + lag];
      sum += d * d;
    }
    diff[lag] = sum;
  }

  final cmnd = Float64List(maxLag + 1);
  cmnd[0] = 1;
  var running = 0.0;
  for (var lag = 1; lag <= maxLag; lag++) {
    running += diff[lag];
    cmnd[lag] = running == 0 ? 1 : diff[lag] * lag / running;
  }

  var tau = -1;
  for (var lag = minLag; lag <= maxLag; lag++) {
    if (cmnd[lag] < threshold) {
      while (lag + 1 <= maxLag && cmnd[lag + 1] < cmnd[lag]) {
        lag++;
      }
      tau = lag;
      break;
    }
  }
  if (tau == -1) {
    // しきい値を下回る場所がなければ、範囲内で一番低いところを採用する
    // （＝一番「それっぽい」が、自信度は低くなる）
    var bestLag = minLag;
    var bestVal = cmnd[minLag];
    for (var lag = minLag; lag <= maxLag; lag++) {
      if (cmnd[lag] < bestVal) {
        bestVal = cmnd[lag];
        bestLag = lag;
      }
    }
    tau = bestLag;
  }

  // 放物線補間で、サンプル単位の粗さを補正する
  var betterTau = tau.toDouble();
  if (tau > minLag && tau < maxLag) {
    final s0 = cmnd[tau - 1], s1 = cmnd[tau], s2 = cmnd[tau + 1];
    final denom = 2 * (2 * s1 - s2 - s0);
    if (denom != 0) {
      final delta = (s2 - s0) / denom;
      if (delta.abs() < 1) betterTau = tau + delta;
    }
  }
  if (betterTau <= 0) return null;

  return PitchCandidate(
    frequency: sampleRate / betterTau,
    confidence: (1 - cmnd[tau]).clamp(0.0, 1.0).toDouble(),
    rms: _rmsOf(buf),
  );
}

/// 音量が小さすぎる・周期性が弱いときに使う、共通のしきい値
const double minRmsForDetection = 0.02;
const double minConfidenceForDetection = 0.35;

/// [algorithm] で検出する。[instrument] を渡すと、その楽器の音域に絞って探し、
/// 倍音が強く出やすい楽器（[HarmonicQuirk.strongOctave] など）では
/// 「1オクターブ上に誤検出していないか」も追加でチェックする。
PitchCandidate? detectPitchCandidate(
  Uint8List pcm16LEBytes, {
  required int sampleRate,
  required PitchAlgorithm algorithm,
  InstrumentProfile? instrument,
  double? minFreqOverride,
  double? maxFreqOverride,
}) {
  final buf = _toFloat(pcm16LEBytes);
  if (buf.length < 256) return null;
  final rms = _rmsOf(buf);
  if (rms < minRmsForDetection) return null;

  final minFreq = minFreqOverride ?? instrument?.minFreq ?? 60.0;
  final maxFreq = maxFreqOverride ?? instrument?.maxFreq ?? 2200.0;
  final n = buf.length;
  final minLag = (sampleRate / maxFreq).floor().clamp(1, n - 1).toInt();
  final maxLag = (sampleRate / minFreq).ceil().clamp(minLag + 1, n - 1).toInt();

  final raw = switch (algorithm) {
    PitchAlgorithm.autocorrelation => _autocorrelate(
      buf,
      sampleRate: sampleRate,
      minLag: minLag,
      maxLag: maxLag,
    ),
    PitchAlgorithm.yin => _yin(
      buf,
      sampleRate: sampleRate,
      minLag: minLag,
      maxLag: maxLag,
    ),
  };
  if (raw == null || raw.confidence < minConfidenceForDetection) return null;

  return _guardOctave(raw, buf, sampleRate, minFreq, instrument);
}

/// 「基音より2倍音（1オクターブ上）が強く出やすい」楽器では、検出結果を
/// 半分の周波数（1オクターブ下）でも確認し、そちらが楽器の実用音域に入って
/// いて、かつ周期性がそう変わらないなら、低いほうを採用する。
///
/// ※ これは「絶対に正しい」補正ではなく、あくまで誤検出を減らすための
/// 目安（ヒューリスティック）であることに注意。
PitchCandidate _guardOctave(
  PitchCandidate raw,
  Float64List buf,
  int sampleRate,
  double minFreq,
  InstrumentProfile? instrument,
) {
  if (instrument == null || instrument.quirk != HarmonicQuirk.strongOctave) {
    return raw;
  }
  final halfFreq = raw.frequency / 2;
  if (halfFreq < minFreq) return raw; // 半分にすると音域を外れるので、そのまま

  final lagAtHalf = (sampleRate / halfFreq).round();
  if (lagAtHalf <= 0 || lagAtHalf >= buf.length) return raw;

  var corr = 0.0;
  var energy = 0.0;
  final count = buf.length - lagAtHalf;
  for (var i = 0; i < count; i++) {
    corr += buf[i] * buf[i + lagAtHalf];
    energy += buf[i] * buf[i];
  }
  corr /= count;
  energy /= count;
  final halfClarity = energy > 0 ? (corr / energy).clamp(0.0, 1.0).toDouble() : 0.0;

  // 半分の周波数でも、元の検出と同じくらいはっきりした周期性があれば、
  // （金管の2倍音誤検出の典型パターンなので）低いほうを信じる
  if (halfClarity >= raw.confidence * 0.85) {
    return PitchCandidate(
      frequency: halfFreq,
      confidence: halfClarity,
      rms: raw.rms,
    );
  }
  return raw;
}
