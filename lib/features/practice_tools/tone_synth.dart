/// メトロノームのクリック音・ドローン（基準音）の波形を、その場で作る
///
/// 音のファイルを用意しなくてよいように、サイン波から自前で PCM16 の WAV を作る。
library;

import 'dart:math' as math;
import 'dart:typed_data';

const int _sampleRate = 44100;

Uint8List _wavBytes(List<int> samples16, {int sampleRate = _sampleRate}) {
  const bitsPerSample = 16;
  const numChannels = 1;
  final byteRate = sampleRate * numChannels * bitsPerSample ~/ 8;
  final blockAlign = numChannels * bitsPerSample ~/ 8;
  final dataSize = samples16.length * 2;
  final buffer = ByteData(44 + dataSize);

  void s(int offset, String v) {
    for (var i = 0; i < v.length; i++) {
      buffer.setUint8(offset + i, v.codeUnitAt(i));
    }
  }

  s(0, 'RIFF');
  buffer.setUint32(4, 36 + dataSize, Endian.little);
  s(8, 'WAVE');
  s(12, 'fmt ');
  buffer.setUint32(16, 16, Endian.little);
  buffer.setUint16(20, 1, Endian.little); // PCM
  buffer.setUint16(22, numChannels, Endian.little);
  buffer.setUint32(24, sampleRate, Endian.little);
  buffer.setUint32(28, byteRate, Endian.little);
  buffer.setUint16(32, blockAlign, Endian.little);
  buffer.setUint16(34, bitsPerSample, Endian.little);
  s(36, 'data');
  buffer.setUint32(40, dataSize, Endian.little);

  for (var i = 0; i < samples16.length; i++) {
    buffer.setInt16(44 + i * 2, samples16[i], Endian.little);
  }
  return buffer.buffer.asUint8List();
}

/// メトロノームの「カチッ」という短いクリック音
///
/// [accent] は小節の頭、[secondaryAccent] は複合拍子でグループの頭（例：5拍子の
/// 2+3の「3」が始まるところ）、どちらも false で [subdivision] が true なら
/// 3連符・4連符などの「裏」のクリック（弱く、少し低い音）になる。
Uint8List generateClickWav({
  bool accent = false,
  bool secondaryAccent = false,
  bool subdivision = false,
}) {
  const durationMs = 35;
  final freq = accent
      ? 1760.0 // A6：小節の頭（一番強い）
      : secondaryAccent
      ? 1400.0 // 複合拍子のグループの頭
      : subdivision
      ? 750.0 // 3連符・4連符などの裏
      : 1100.0; // ふつうの拍（C#6くらい）
  final amp = subdivision ? 15000.0 : 28000.0;
  final n = (_sampleRate * durationMs / 1000).round();
  final samples = List<int>.generate(n, (i) {
    final t = i / _sampleRate;
    // 立ち上がりは速く、減衰はなめらかに（ポップ音を防ぐ）
    final envelope = math.exp(-t * 60);
    final v = math.sin(2 * math.pi * freq * t) * envelope;
    return (v * amp).round().clamp(-32768, 32767);
  });
  return _wavBytes(samples);
}

/// 波形の種類（クリック音メーカー用）
enum ClickWaveform { sine, triangle, noise }

/// メトロノームのクリック音の音色プリセット
enum ClickTimbre {
  classic('クラシック', 1100, 35, 1, 15, ClickWaveform.sine),
  wood('木製（ウッドブロック風）', 700, 45, 2, 25, ClickWaveform.triangle),
  soft('やわらかい', 900, 40, 3, 30, ClickWaveform.sine),
  rim('リムショット風', 1800, 25, 1, 10, ClickWaveform.noise),
  electronic('電子音', 2200, 30, 1, 12, ClickWaveform.sine),
  low('低いクリック', 400, 50, 2, 30, ClickWaveform.triangle);

  const ClickTimbre(
    this.label,
    this.baseFreq,
    this.durationMs,
    this.attackMs,
    this.decayMs,
    this.waveform,
  );

  final String label;
  final double baseFreq;
  final int durationMs;
  final int attackMs;
  final int decayMs;
  final ClickWaveform waveform;
}

double _waveSample(ClickWaveform w, double phase, math.Random rand) {
  final p = phase % 1.0;
  switch (w) {
    case ClickWaveform.sine:
      return math.sin(2 * math.pi * p);
    case ClickWaveform.triangle:
      return 4 * (p - (p + 0.75).floor() + 0.25).abs() - 1;
    case ClickWaveform.noise:
      return rand.nextDouble() * 2 - 1;
  }
}

/// 音色プリセット・強さ（0〜1）・ピッチ倍率から、クリック音のWAVを作る
///
/// [gain] はダイナミクス（DynamicLevel.gain など）で 0（無音に近い）〜1（最大）。
/// [pitchMultiplier] は、拍の種類（主拍／グループ先頭／裏拍）で音の高さを
/// 変えたいときに使う（1.0で基準どおり）。
Uint8List generateTimbredClick(
  ClickTimbre timbre, {
  double gain = 1.0,
  double pitchMultiplier = 1.0,
}) {
  if (gain <= 0.01) {
    // ほぼ無音：ごく短い無音データを返す（再生自体はしても聞こえない）
    return _wavBytes(List<int>.filled(200, 0));
  }
  final freq = timbre.baseFreq * pitchMultiplier;
  final n = (_sampleRate * timbre.durationMs / 1000).round();
  final attackN = math.max(1, (_sampleRate * timbre.attackMs / 1000).round());
  final decayStartN = math.max(
    attackN,
    n - (_sampleRate * timbre.decayMs / 1000).round(),
  );
  final rand = math.Random(freq.round());
  final amp = 30000.0 * gain.clamp(0.0, 1.0).toDouble();
  final samples = List<int>.generate(n, (i) {
    final envelope = i < attackN
        ? i / attackN
        : (i > decayStartN
              ? math.max(0.0, 1 - (i - decayStartN) / math.max(1, n - decayStartN))
              : 1.0);
    final phase = freq * i / _sampleRate;
    final v = _waveSample(timbre.waveform, phase, rand) * envelope;
    return (v * amp).round().clamp(-32768, 32767).toInt();
  });
  return _wavBytes(samples);
}

/// 指定した周波数の、なめらかにループできるサイン波（ドローン用）
Uint8List generateToneWav(double freq, {double seconds = 2}) {
  final cycles = math.max(1, (freq * seconds).round());
  final n = (cycles / freq * _sampleRate).round();
  const fadeSamples = 400; // 端でのプチ音を防ぐ、ごく短いフェード
  final samples = List<int>.generate(n, (i) {
    final t = i / _sampleRate;
    var amp = 1.0;
    if (i < fadeSamples) amp = i / fadeSamples;
    if (i > n - fadeSamples) amp = (n - i) / fadeSamples;
    final v = math.sin(2 * math.pi * freq * t) * amp * 0.5;
    return (v * 32000).round().clamp(-32768, 32767);
  });
  return _wavBytes(samples);
}

/// ピアノ機能の音色（倍音の混ぜ方と減衰の速さで、楽器らしさを作る）
enum PianoTone {
  piano('ピアノ', [1.0, 0.55, 0.3, 0.15, 0.08, 0.04], 1.8),
  electric('エレピ', [1.0, 0.15, 0.35, 0.05, 0.1], 1.1),
  organ('オルガン', [1.0, 0.6, 0.8, 0.3, 0.5, 0.2], 0.25),
  harpsichord('ハープシコード', [1.0, 0.8, 0.6, 0.5, 0.4, 0.3, 0.2], 3.2),
  synth('シンセ', [1.0, 0.5, 0.33, 0.25, 0.2, 0.17], 1.2);

  const PianoTone(this.label, this.harmonics, this.decayRate);

  final String label;

  /// 倍音（基音・2倍音・3倍音…）の相対的な強さ
  final List<double> harmonics;

  /// 減衰の速さ（大きいほど早く減衰する。オルガンは小さくして伸ばす）
  final double decayRate;
}

/// ピアノ機能の1音ぶんのWAV（指で弾いた感じの速い立ち上がり＋音色ごとの減衰）
Uint8List generatePianoNoteWav(double freq, PianoTone tone, {double seconds = 2.5}) {
  final n = (_sampleRate * seconds).round();
  const attackN = 200; // 立ち上がり（約4.5ms）
  final norm = tone.harmonics.fold<double>(0, (a, b) => a + b);
  final samples = List<int>.generate(n, (i) {
    final t = i / _sampleRate;
    final attack = i < attackN ? i / attackN : 1.0;
    final decay = math.exp(-tone.decayRate * t);
    var v = 0.0;
    for (var h = 0; h < tone.harmonics.length; h++) {
      final harmonicFreq = freq * (h + 1);
      if (harmonicFreq > _sampleRate / 2) break; // ナイキスト周波数を超えたら無視
      v += math.sin(2 * math.pi * harmonicFreq * t) * tone.harmonics[h];
    }
    v = v / norm * attack * decay * 0.6;
    return (v * 32000).round().clamp(-32768, 32767);
  });
  return _wavBytes(samples);
}

/// 音名（C4=ド、A4=ラ=440Hz が基準）から周波数を求める
/// [octave] は「ド」から始まる音楽的なオクターブ表記（A4=440Hz、[referenceHz] で変更可）
double frequencyOf(String noteName, int octave, {double referenceHz = 440}) {
  const order = [
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
  final idx = order.indexOf(noteName);
  final midi = (octave + 1) * 12 + idx;
  return referenceHz * math.pow(2, (midi - 69) / 12);
}
