/// チューナー・メトロノーム・ドローンで共通して使う、音楽まわりの定義と計算
///
/// ・平均律／純正律の周波数計算
/// ・音名の表記（英語式・ドイツ式・日本式・イタリア式）
/// ・チューナーの感度（許容セント数）・楽器モード（検出する周波数帯）
library;

import 'dart:math' as math;

/// 音律
enum Temperament { equal, just, pythagorean, custom }

extension TemperamentX on Temperament {
  String get label => switch (this) {
    Temperament.equal => '平均律',
    Temperament.just => '純正律',
    Temperament.pythagorean => 'ピタゴラス音律',
    Temperament.custom => 'カスタム音律',
  };

  String get description => switch (this) {
    Temperament.equal => '12音を均等に分けた、今のピアノなどの調律',
    Temperament.just => '主音（ド）からの整数比でとる、和音がよく響く調律',
    Temperament.pythagorean => '完全5度の積み重ねで作る、中世〜古典の調律',
    Temperament.custom => '自分で半音ごとのズレ（セント）を決められる調律',
  };
}

/// 音名の表記方法
enum NotationSystem { english, german, japanese, solfege }

extension NotationSystemX on NotationSystem {
  String get label => switch (this) {
    NotationSystem.english => '英語式（C, D, E…）',
    NotationSystem.german => 'ドイツ式（C, D, E, H…）',
    NotationSystem.japanese => '日本式（ハ, ニ, ホ…）',
    NotationSystem.solfege => 'イタリア式（ド, レ, ミ…）',
  };

  String get shortLabel => switch (this) {
    NotationSystem.english => '英語式',
    NotationSystem.german => 'ドイツ式',
    NotationSystem.japanese => '日本式',
    NotationSystem.solfege => 'イタリア式',
  };
}

const List<String> _englishNames = [
  'C', 'C#', 'D', 'D#', 'E', 'F', 'F#', 'G', 'G#', 'A', 'A#', 'B',
];
// ドイツ式：H = ロ（英語のB）、B = 変ロ（英語のB♭）
const List<String> _germanNames = [
  'C', 'Cis', 'D', 'Dis', 'E', 'F', 'Fis', 'G', 'Gis', 'A', 'B', 'H',
];
const List<String> _japaneseNames = [
  'ハ', '嬰ハ', 'ニ', '嬰ニ', 'ホ', 'ヘ', '嬰ヘ', 'ト', '嬰ト', 'イ', '嬰イ', 'ロ',
];
const List<String> _solfegeNames = [
  'ド', 'ド#', 'レ', 'レ#', 'ミ', 'ファ', 'ファ#', 'ソ', 'ソ#', 'ラ', 'ラ#', 'シ',
];

/// 0〜11（C=0）の音名を、指定した表記方法の文字列にする
String noteNameFor(int pitchClass, NotationSystem system) {
  final i = ((pitchClass % 12) + 12) % 12;
  return switch (system) {
    NotationSystem.english => _englishNames[i],
    NotationSystem.german => _germanNames[i],
    NotationSystem.japanese => _japaneseNames[i],
    NotationSystem.solfege => _solfegeNames[i],
  };
}

/// 「英語式の音名（C, C#…）」→ 0〜11 の番号
int pitchClassOfEnglish(String name) => _englishNames.indexOf(name);

/// 実音の pitch class を、楽器の移調（半音数）ぶんずらして「記譜音」にする
///
/// 例：B♭管（+2）の実音Cは、記譜だとD（実音より長2度高く書く）
int transposedPitchClass(int concertPitchClass, int transpositionSemitones) =>
    ((concertPitchClass + transpositionSemitones) % 12 + 12) % 12;

/// チューナーの感度（「合っている」とみなす、ずれの範囲）
enum TunerPrecision {
  large(5, '大きめ'),
  medium(3, 'ふつう'),
  small(2, 'せまい'),
  fine(1, '微細');

  const TunerPrecision(this.cents, this.label);

  /// この範囲内（±cents）なら「合っている」とする
  final int cents;
  final String label;
}

// 楽器の種類（管楽器の個別プロファイル）は instruments/instrument_profile.dart に
// 統合した（Trumpet・Trombone・Horn…と、それぞれの音域・移調・倍音のクセを持つ）。

/// 5-limit 純正律：主音（ratio 1/1）からの整数比（0〜11 は半音インデックス）
const List<double> justIntonationRatios = [
  1 / 1, // 完全1度
  16 / 15, // 短2度
  9 / 8, // 長2度
  6 / 5, // 短3度
  5 / 4, // 長3度
  4 / 3, // 完全4度
  45 / 32, // 増4度
  3 / 2, // 完全5度
  8 / 5, // 短6度
  5 / 3, // 長6度
  9 / 5, // 短7度
  15 / 8, // 長7度
];

/// ピタゴラス音律（3-limit）：主音からの整数比。完全5度(3/2)の積み重ねで作る
const List<double> pythagoreanRatios = [
  1 / 1, // 完全1度
  256 / 243, // 短2度（リンマ）
  9 / 8, // 長2度
  32 / 27, // 短3度
  81 / 64, // 長3度
  4 / 3, // 完全4度
  729 / 512, // 増4度
  3 / 2, // 完全5度
  128 / 81, // 短6度
  27 / 16, // 長6度
  16 / 9, // 短7度
  243 / 128, // 長7度
];

/// ユーザーが自由に決められる音律。12半音それぞれの「平均律からのズレ」を
/// セントで持つ（すべて0なら平均律と同じ）。
class CustomTemperament {
  const CustomTemperament({
    required this.name,
    required this.centsOffsetByPitchClass,
  });

  final String name;

  /// 0〜11（C=0）の、平均律からのズレ（セント）。12要素。
  final List<double> centsOffsetByPitchClass;

  factory CustomTemperament.equalBased({String name = 'マイ音律'}) =>
      CustomTemperament(name: name, centsOffsetByPitchClass: List.filled(12, 0));

  double offsetFor(int pitchClass) =>
      centsOffsetByPitchClass[((pitchClass % 12) + 12) % 12];

  CustomTemperament withOffset(int pitchClass, double cents) {
    final list = List<double>.from(centsOffsetByPitchClass);
    list[((pitchClass % 12) + 12) % 12] = cents;
    return CustomTemperament(name: name, centsOffsetByPitchClass: list);
  }
}

/// 楽器の個体差・奏者のクセを補正するための、個人プロファイル
///
/// 基準音（Concert Pitch）・楽器プロファイルとは別に持つ。「この音は自分の場合
/// 標準よりこれくらい高く/低く出やすい」という半音ごとの補正値（セント）。
/// 自動でチューナーの基準をズラすのではなく、あくまで「補正後の目安」を
/// 別枠で見せるために使う。
class PersonalCalibration {
  const PersonalCalibration({
    this.name = '個人プロファイル',
    this.centsOffsetByPitchClass = const [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0],
  });

  final String name;
  final List<double> centsOffsetByPitchClass;

  double offsetFor(int pitchClass) =>
      centsOffsetByPitchClass[((pitchClass % 12) + 12) % 12];

  PersonalCalibration withOffset(int pitchClass, double cents) {
    final list = List<double>.from(centsOffsetByPitchClass);
    list[((pitchClass % 12) + 12) % 12] = cents;
    return PersonalCalibration(name: name, centsOffsetByPitchClass: list);
  }
}

/// midi ノート番号（A4=69）を、指定した基準音・音律で周波数にする
///
/// 純正律・ピタゴラス音律のときは [tonicPitchClass]（0=C, 9=A など）を主音として、
/// そのオクターブ内の主音を平均律で置いた上で、そこからの整数比で音を作る。
/// カスタム音律のときは [custom] のセントのズレを平均律に足す。
double frequencyForMidi(
  double midi, {
  required double referenceHz,
  required Temperament temperament,
  int tonicPitchClass = 0,
  CustomTemperament? custom,
}) {
  if (temperament == Temperament.equal) {
    return referenceHz * math.pow(2, (midi - 69) / 12);
  }
  if (temperament == Temperament.custom) {
    final rounded = midi.round();
    final pc = ((rounded % 12) + 12) % 12;
    final offsetCents = (custom ?? CustomTemperament.equalBased()).offsetFor(pc);
    final base = referenceHz * math.pow(2, (midi - 69) / 12);
    return base * math.pow(2, offsetCents / 1200);
  }
  final ratios = temperament == Temperament.just
      ? justIntonationRatios
      : pythagoreanRatios;
  final rounded = midi.round();
  final pc = ((rounded % 12) + 12) % 12;
  final ratioIdx = ((pc - tonicPitchClass) + 12) % 12;
  final ratio = ratios[ratioIdx];
  // このオクターブ内の「主音」の midi 番号（平均律で求めた基準点）
  final tonicMidi = rounded - ratioIdx;
  final tonicFreq = referenceHz * math.pow(2, (tonicMidi - 69) / 12);
  // 端数（rounded と実際の midi のずれ）ぶんも、比率の対数スケールで反映する
  final frac = midi - rounded;
  return tonicFreq * ratio * math.pow(2, frac / 12);
}

/// チューナー表示用の「検出された音」の情報
class TunedNote {
  const TunedNote({
    required this.pitchClass,
    required this.octave,
    required this.targetFrequency,
    required this.cents,
    this.personalAdjustedCents,
  });

  /// 0〜11（C=0）
  final int pitchClass;
  final int octave;

  /// この音律・基準音での「正しい」周波数
  final double targetFrequency;

  /// 検出した周波数の、targetFrequency からのずれ（セント。+が高い、-が低い）
  final double cents;

  /// 個人プロファイルで補正した後のずれ（セント）。渡さなければ null。
  final double? personalAdjustedCents;

  String label(NotationSystem system) =>
      '${noteNameFor(pitchClass, system)}$octave';
}

/// 検出した周波数 [freq] に一番近い音を、指定の音律・基準音で探す
///
/// [custom] はカスタム音律のときに使う。[personal] を渡すと、個人（楽器個体）
/// の補正を反映した [TunedNote.personalAdjustedCents] も計算する。
TunedNote nearestTunedNote(
  double freq, {
  required double referenceHz,
  required Temperament temperament,
  int tonicPitchClass = 0,
  CustomTemperament? custom,
  PersonalCalibration? personal,
}) {
  final approxMidi = 69 + 12 * (math.log(freq / referenceHz) / math.ln2);
  final base = approxMidi.round();

  TunedNote? best;
  var bestAbsCents = double.infinity;
  for (var m = base - 1; m <= base + 1; m++) {
    final target = frequencyForMidi(
      m.toDouble(),
      referenceHz: referenceHz,
      temperament: temperament,
      tonicPitchClass: tonicPitchClass,
      custom: custom,
    );
    if (target <= 0) continue;
    final cents = 1200 * (math.log(freq / target) / math.ln2);
    if (cents.abs() < bestAbsCents) {
      bestAbsCents = cents.abs();
      final pc = ((m % 12) + 12) % 12;
      final octave = (m ~/ 12) - 1;
      best = TunedNote(
        pitchClass: pc,
        octave: octave,
        targetFrequency: target,
        cents: cents,
        personalAdjustedCents: personal == null
            ? null
            : cents - personal.offsetFor(pc),
      );
    }
  }
  return best!;
}
