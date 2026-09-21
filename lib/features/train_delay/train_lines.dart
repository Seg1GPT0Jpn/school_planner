/// 「よく使う路線」に登録できる路線の一覧
///
/// ID は ODPT（公共交通オープンデータセンター）の路線ID。
/// 藤沢市とその周辺でよく使いそうな路線を中心にしています。
/// ここに無い路線が必要になったら、ODPT の路線一覧
/// （https://developer.odpt.org/ のチャレンジデータ）を見て追加してください。
library;

class TrainLine {
  const TrainLine({
    required this.id,
    required this.name,
    required this.operatorName,
  });

  /// ODPT の路線ID（例：odpt.Railway:JR-East.Tokaido）
  final String id;

  /// 表示名
  final String name;

  final String operatorName;
}

const trainLines = <TrainLine>[
  TrainLine(
    id: 'odpt.Railway:JR-East.Tokaido',
    name: '東海道線',
    operatorName: 'JR東日本',
  ),
  TrainLine(
    id: 'odpt.Railway:JR-East.Yokosuka',
    name: '横須賀線',
    operatorName: 'JR東日本',
  ),
  TrainLine(
    id: 'odpt.Railway:JR-East.ShonanShinjuku',
    name: '湘南新宿ライン',
    operatorName: 'JR東日本',
  ),
  TrainLine(
    id: 'odpt.Railway:JR-East.Yokohama',
    name: '横浜線',
    operatorName: 'JR東日本',
  ),
  TrainLine(
    id: 'odpt.Railway:Odakyu.Odawara',
    name: '小田急小田原線',
    operatorName: '小田急電鉄',
  ),
  TrainLine(
    id: 'odpt.Railway:Odakyu.Enoshima',
    name: '小田急江ノ島線',
    operatorName: '小田急電鉄',
  ),
  TrainLine(
    id: 'odpt.Railway:Enoden.Enoshima',
    name: '江ノ島電鉄線',
    operatorName: '江ノ島電鉄',
  ),
  TrainLine(
    id: 'odpt.Railway:Sotetsu.Main',
    name: '相鉄本線',
    operatorName: '相模鉄道',
  ),
  TrainLine(
    id: 'odpt.Railway:Keikyu.Main',
    name: '京急本線',
    operatorName: '京浜急行電鉄',
  ),
  TrainLine(
    id: 'odpt.Railway:TokyoMetro.Marunouchi',
    name: '丸ノ内線',
    operatorName: '東京メトロ',
  ),
  TrainLine(
    id: 'odpt.Railway:Toei.Asakusa',
    name: '都営浅草線',
    operatorName: '都営地下鉄',
  ),
];

TrainLine? findTrainLine(String id) {
  for (final l in trainLines) {
    if (l.id == id) return l;
  }
  return null;
}
