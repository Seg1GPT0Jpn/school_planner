/// 音の高さ（幹音・変化記号・オクターブ）
library;

import 'dart:math' as math;

/// 音の高さ（例：C4＝真ん中のド、F#5 など）
class Pitch {
  const Pitch({required this.step, this.alter = 0, required this.octave});

  /// 幹音（0=ド(C) 1=レ(D) 2=ミ(E) 3=ファ(F) 4=ソ(G) 5=ラ(A) 6=シ(B)）
  final int step;

  /// 変化記号（-2=ダブルフラット -1=フラット 0=なし 1=シャープ 2=ダブルシャープ）
  final int alter;

  /// オクターブ（真ん中のドが C4）
  final int octave;

  static const List<String> stepNames = ['C', 'D', 'E', 'F', 'G', 'A', 'B'];

  /// 幹音から半音数への変換（C=0 基準）
  static const List<int> _semitoneFromC = [0, 2, 4, 5, 7, 9, 11];

  String get stepName => stepNames[step];

  /// 変化記号の記号（♭♯など）
  String get alterSymbol => switch (alter) {
    -2 => '𝄫',
    -1 => '♭',
    1 => '♯',
    2 => '𝄪',
    _ => '',
  };

  /// 「C#4」のような表示用ラベル
  String get label => '$stepName$alterSymbol$octave';

  /// MIDIノート番号（C4=60、A4=69）
  int get midi => (octave + 1) * 12 + _semitoneFromC[step] + alter;

  /// 周波数（Hz）。tone_synth.dart の frequencyOf と同じ考え方（A4=referenceHz）
  double frequencyHz({double referenceHz = 440}) {
    return referenceHz * math.pow(2, (midi - 69) / 12);
  }

  /// 五線譜上の縦位置を表す整数（1増えるごとに1つ上の幹音に上がる）。
  /// 真ん中のド（C4）を 0 とする。加線の計算・描画に使う。
  int get staffStep => (octave - 4) * 7 + step;

  /// MIDIノート番号から音高を作る（異名同音は、シャープ系／フラット系のうち
  /// [preferFlat] で指定した方を使う。移調・自動生成のときに使う）
  factory Pitch.fromMidi(int midi, {bool preferFlat = false}) {
    final octave = (midi ~/ 12) - 1;
    final pitchClass = midi - (octave + 1) * 12;
    // 半音（0〜11）ごとの (幹音, 変化記号)
    const sharpMap = [
      (0, 0), (0, 1), (1, 0), (1, 1), (2, 0), (3, 0),
      (3, 1), (4, 0), (4, 1), (5, 0), (5, 1), (6, 0),
    ];
    const flatMap = [
      (0, 0), (1, -1), (1, 0), (2, -1), (2, 0), (3, 0),
      (4, -1), (4, 0), (5, -1), (5, 0), (6, -1), (6, 0),
    ];
    final (s, a) = (preferFlat ? flatMap : sharpMap)[pitchClass];
    return Pitch(step: s, alter: a, octave: octave);
  }

  /// 半音移動した新しい音高を作る（異名同音は [preferFlat] のとおりに選ぶ）
  Pitch withMidiShift(int semitones, {bool? preferFlat}) =>
      Pitch.fromMidi(midi + semitones, preferFlat: preferFlat ?? alter < 0);

  Map<String, dynamic> toMap() => {
    'step': step,
    'alter': alter,
    'octave': octave,
  };

  static Pitch fromMap(Map<String, dynamic> m) => Pitch(
    step: (m['step'] as num).toInt(),
    alter: (m['alter'] as num?)?.toInt() ?? 0,
    octave: (m['octave'] as num).toInt(),
  );

  Pitch copyWith({int? step, int? alter, int? octave}) => Pitch(
    step: step ?? this.step,
    alter: alter ?? this.alter,
    octave: octave ?? this.octave,
  );

  @override
  bool operator ==(Object other) =>
      other is Pitch &&
      other.step == step &&
      other.alter == alter &&
      other.octave == octave;

  @override
  int get hashCode => Object.hash(step, alter, octave);

  @override
  String toString() => label;
}
