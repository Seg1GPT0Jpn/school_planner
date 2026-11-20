/// 速度記号の目安（Grave〜Prestissimo）
///
/// チューナー・メトロノームの裏面などによくある「速度記号とBPMの対応表」を
/// アプリの中でも見られるようにしたもの。範囲は代表的な教本・市販チューナーの
/// 表記を参考にした目安であり、厳密な決まりがあるわけではない。
library;

class TempoMarking {
  const TempoMarking({
    required this.name,
    required this.reading,
    required this.description,
    required this.minBpm,
    required this.maxBpm,
  });

  /// イタリア語の速度記号
  final String name;

  /// カタカナ読み
  final String reading;

  /// 日本語での意味
  final String description;

  final int minBpm;
  final int maxBpm;

  bool contains(int bpm) => bpm >= minBpm && bpm <= maxBpm;
}

/// 30〜300（アプリのBPM範囲）を隙間なくカバーする目安表
const List<TempoMarking> tempoMarkings = [
  TempoMarking(
    name: 'Grave',
    reading: 'グラーヴェ',
    description: 'きわめて遅く、重々しく',
    minBpm: 30,
    maxBpm: 39,
  ),
  TempoMarking(
    name: 'Largo',
    reading: 'ラルゴ',
    description: '幅広く、ゆるやかに',
    minBpm: 40,
    maxBpm: 59,
  ),
  TempoMarking(
    name: 'Larghetto',
    reading: 'ラルゲット',
    description: 'ラルゴよりやや速く',
    minBpm: 60,
    maxBpm: 65,
  ),
  TempoMarking(
    name: 'Adagio',
    reading: 'アダージョ',
    description: 'ゆっくりと',
    minBpm: 66,
    maxBpm: 75,
  ),
  TempoMarking(
    name: 'Andante',
    reading: 'アンダンテ',
    description: '歩くような速さで',
    minBpm: 76,
    maxBpm: 107,
  ),
  TempoMarking(
    name: 'Moderato',
    reading: 'モデラート',
    description: '中くらいの速さで',
    minBpm: 108,
    maxBpm: 119,
  ),
  TempoMarking(
    name: 'Allegro',
    reading: 'アレグロ',
    description: '速く、快活に',
    minBpm: 120,
    maxBpm: 167,
  ),
  TempoMarking(
    name: 'Vivace',
    reading: 'ヴィヴァーチェ',
    description: '活発に、生き生きと',
    minBpm: 168,
    maxBpm: 175,
  ),
  TempoMarking(
    name: 'Presto',
    reading: 'プレスト',
    description: '急速に',
    minBpm: 176,
    maxBpm: 207,
  ),
  TempoMarking(
    name: 'Prestissimo',
    reading: 'プレスティッシモ',
    description: 'きわめて急速に',
    minBpm: 208,
    maxBpm: 300,
  ),
];

/// 指定したBPMに対応する速度記号を返す（表の範囲外なら一番近い端のものを返す）
TempoMarking tempoMarkingFor(int bpm) {
  for (final m in tempoMarkings) {
    if (m.contains(bpm)) return m;
  }
  return bpm < tempoMarkings.first.minBpm ? tempoMarkings.first : tempoMarkings.last;
}
