/// 楽器プロファイル
///
/// 楽器ごとに「実用音域」「移調」「ピッチ検出のクセ（倍音が基音より強く出やすい
/// など）」をまとめて持つ。チューナー・解析・ロングトーン分析すべてがこれを参照する。
library;

/// この楽器で誤検出しやすい倍音のクセ（ピッチ検出側のヒントに使う）
enum HarmonicQuirk {
  /// 特徴なし
  none,

  /// 基音より第2倍音（1オクターブ上）が強く出やすい（トランペット等の金管に多い）
  strongOctave,

  /// 基音より第3倍音（1オクターブ+5度上）が強く出やすい（クラリネットの低音域）
  strongTwelfth,
}

class InstrumentProfile {
  const InstrumentProfile({
    required this.id,
    required this.name,
    required this.family,
    required this.transpositionSemitones,
    required this.transpositionLabel,
    required this.minFreq,
    required this.maxFreq,
    this.quirk = HarmonicQuirk.none,
    this.breathNoiseProne = false,
  });

  /// 内部識別子
  final String id;

  /// 表示名
  final String name;

  /// 管楽器／弦楽器／ボイスなどの大分類
  final String family;

  /// 実音 → 記譜音の移調幅（半音）。C管は0。
  /// 例：B♭管トランペットは +2（記譜Cを吹くと実音B♭になるので、
  /// 「実音から記譜音にする」には +2 する）
  final int transpositionSemitones;

  /// 「B♭管」のような表示用ラベル
  final String transpositionLabel;

  /// ピッチ検出で探す周波数帯（実音、Hz）
  final double minFreq;
  final double maxFreq;

  /// 誤検出しやすい倍音のクセ
  final HarmonicQuirk quirk;

  /// アタック直後にブレスノイズが乗りやすいか（立ち上がりの検出を慎重にする）
  final bool breathNoiseProne;
}

const List<InstrumentProfile> instrumentProfiles = [
  InstrumentProfile(
    id: 'trumpet',
    name: 'トランペット／コルネット',
    family: '金管',
    transpositionSemitones: 2,
    transpositionLabel: 'B♭管',
    minFreq: 155.0, // F#3くらい（ペダルトーンは除く実用域）
    maxFreq: 1050.0,
    quirk: HarmonicQuirk.strongOctave,
    breathNoiseProne: true,
  ),
  InstrumentProfile(
    id: 'trombone',
    name: 'トロンボーン',
    family: '金管',
    transpositionSemitones: 0,
    transpositionLabel: 'C管（実音表記）',
    minFreq: 58.0,
    maxFreq: 700.0,
    quirk: HarmonicQuirk.strongOctave,
    breathNoiseProne: true,
  ),
  InstrumentProfile(
    id: 'horn',
    name: 'ホルン',
    family: '金管',
    transpositionSemitones: 7,
    transpositionLabel: 'F管',
    minFreq: 62.0,
    maxFreq: 900.0,
    quirk: HarmonicQuirk.strongOctave,
    breathNoiseProne: true,
  ),
  InstrumentProfile(
    id: 'euphonium',
    name: 'ユーフォニアム',
    family: '金管',
    transpositionSemitones: 0,
    transpositionLabel: 'C管（実音表記）',
    minFreq: 58.0,
    maxFreq: 620.0,
    quirk: HarmonicQuirk.strongOctave,
    breathNoiseProne: true,
  ),
  InstrumentProfile(
    id: 'tuba',
    name: 'チューバ',
    family: '金管',
    transpositionSemitones: 0,
    transpositionLabel: 'C管（実音表記）',
    minFreq: 33.0,
    maxFreq: 400.0,
    quirk: HarmonicQuirk.strongOctave,
    breathNoiseProne: true,
  ),
  InstrumentProfile(
    id: 'flute',
    name: 'フルート',
    family: '木管',
    transpositionSemitones: 0,
    transpositionLabel: 'C管',
    minFreq: 247.0,
    maxFreq: 2100.0,
    breathNoiseProne: true,
  ),
  InstrumentProfile(
    id: 'clarinet',
    name: 'クラリネット',
    family: '木管',
    transpositionSemitones: 2,
    transpositionLabel: 'B♭管',
    minFreq: 145.0,
    maxFreq: 1600.0,
    quirk: HarmonicQuirk.strongTwelfth,
  ),
  InstrumentProfile(
    id: 'oboe',
    name: 'オーボエ',
    family: '木管',
    transpositionSemitones: 0,
    transpositionLabel: 'C管',
    minFreq: 230.0,
    maxFreq: 1550.0,
  ),
  InstrumentProfile(
    id: 'bassoon',
    name: 'ファゴット',
    family: '木管',
    transpositionSemitones: 0,
    transpositionLabel: 'C管',
    minFreq: 58.0,
    maxFreq: 700.0,
    quirk: HarmonicQuirk.strongOctave,
  ),
  InstrumentProfile(
    id: 'saxophone',
    name: 'サクソフォーン（アルト基準）',
    family: '木管',
    transpositionSemitones: 9,
    transpositionLabel: 'E♭管（アルト・バリトン）／B♭管（ソプラノ・テナー）',
    minFreq: 130.0,
    maxFreq: 1200.0,
    quirk: HarmonicQuirk.strongOctave,
  ),
  InstrumentProfile(
    id: 'strings',
    name: '弦楽器',
    family: '弦',
    transpositionSemitones: 0,
    transpositionLabel: 'C管',
    minFreq: 40.0,
    maxFreq: 2500.0,
  ),
  InstrumentProfile(
    id: 'voice',
    name: 'ボイス',
    family: '声',
    transpositionSemitones: 0,
    transpositionLabel: 'C管',
    minFreq: 70.0,
    maxFreq: 1100.0,
  ),
];

InstrumentProfile instrumentById(String id) =>
    instrumentProfiles.firstWhere((p) => p.id == id, orElse: () => instrumentProfiles.first);
