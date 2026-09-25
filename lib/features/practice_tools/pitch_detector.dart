/// マイクの音から音の高さを推定する（簡易版：自己相関法）
///
/// 「正式なチューナーアプリ」ほどの精度は狙わず、「だいたい合っているか」が
/// わかる程度の実装。100Hz〜1000Hz くらいの範囲（管楽器の基準音あたり）を想定。
library;

import 'dart:math' as math;
import 'dart:typed_data';

const _noteNames = [
  'C',
  'C#',
  'D',
  'D#',
  'E',
  'F',
  'F#',
  'G',
  'G#',
  'A',
  'A#',
  'B',
];

class PitchResult {
  const PitchResult({
    required this.frequency,
    required this.noteName,
    required this.octave,
    required this.cents,
  });

  final double frequency;

  /// 「C」「C#」など
  final String noteName;
  final int octave;

  /// 一番近い音からのズレ（セント。-50〜+50。0がぴったり）
  final double cents;

  String get label => '$noteName$octave';
}

/// 録音した PCM16（リトルエンディアン）のバイト列から、音の高さを推定する
///
/// 静かすぎる・周期性が弱い（雑音）ときは null を返す
PitchResult? detectPitch(Uint8List pcm16LEBytes, {int sampleRate = 44100}) {
  final n = pcm16LEBytes.length ~/ 2;
  if (n < 256) return null;

  final buf = Float64List(n);
  final bd = ByteData.sublistView(pcm16LEBytes);
  var sumSq = 0.0;
  for (var i = 0; i < n; i++) {
    final v = bd.getInt16(i * 2, Endian.little) / 32768.0;
    buf[i] = v;
    sumSq += v * v;
  }
  final rms = math.sqrt(sumSq / n);
  if (rms < 0.02) return null; // 音が小さすぎる（無音・雑音レベル）

  // 探す周波数の範囲（管楽器の基準音あたり：だいたい 100Hz〜1000Hz）
  const minFreq = 100.0;
  const maxFreq = 1000.0;
  final minLag = (sampleRate / maxFreq).floor().clamp(1, n - 1);
  final maxLag = (sampleRate / minFreq).ceil().clamp(minLag + 1, n - 1);

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
  if (energy <= 0 || bestCorr / energy < 0.35) {
    return null; // 周期性が弱い＝雑音っぽいので採用しない
  }

  final freq = sampleRate / bestLag;
  return _toNote(freq);
}

PitchResult _toNote(double freq) {
  final midi = 69 + 12 * (math.log(freq / 440) / math.ln2);
  final rounded = midi.round();
  final cents = (midi - rounded) * 100;
  final noteIdx = rounded % 12;
  final octave = (rounded ~/ 12) - 1;
  return PitchResult(
    frequency: freq,
    noteName: _noteNames[noteIdx < 0 ? noteIdx + 12 : noteIdx],
    octave: octave,
    cents: cents,
  );
}
