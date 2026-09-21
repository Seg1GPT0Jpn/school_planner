/// 地震情報のデータ（P2P地震情報 API から取得したものを使う）
///
/// データの元：気象庁の発表を P2P地震情報（https://www.p2pquake.net/）が
/// JSON で配信しているもの。無料・登録不要で使える。
library;

/// 観測点1つぶんの震度
class EarthquakePoint {
  const EarthquakePoint({
    required this.pref,
    required this.addr,
    required this.scale,
    required this.isArea,
  });

  /// 都道府県名（例：神奈川県）
  final String pref;

  /// 市区町村名など
  final String addr;

  /// 震度（気象庁の10倍表記。45=5弱, 50=5強, 55=6弱, 60=6強 など）
  final int scale;

  /// 地域単位の情報か（市区町村単位でないとき true）
  final bool isArea;

  factory EarthquakePoint.fromJson(Map<String, dynamic> j) => EarthquakePoint(
    pref: j['pref'] as String? ?? '',
    addr: j['addr'] as String? ?? '',
    scale: (j['scale'] as num?)?.toInt() ?? -1,
    isArea: j['isArea'] as bool? ?? false,
  );
}

/// 地震情報1件
class EarthquakeInfo {
  const EarthquakeInfo({
    required this.id,
    required this.time,
    required this.hypocenterName,
    required this.latitude,
    required this.longitude,
    required this.depth,
    required this.magnitude,
    required this.maxScale,
    required this.points,
    required this.domesticTsunami,
  });

  final String id;

  /// 発生時刻
  final DateTime time;

  /// 震源地（例：千葉県東方沖）
  final String hypocenterName;

  /// 緯度（不明なとき null）
  final double? latitude;

  /// 経度（不明なとき null）
  final double? longitude;

  /// 深さ（km。不明なとき null）
  final double? depth;

  /// マグニチュード（不明なとき null）
  final double? magnitude;

  /// 最大震度（気象庁の10倍表記。不明なとき null）
  final int? maxScale;

  /// 各地の震度
  final List<EarthquakePoint> points;

  /// 国内の津波の有無（例：Warning／Checking／NonEffective／Unknown）
  final String domesticTsunami;

  /// 都道府県ごとの最大震度（震度分布図に使う）
  Map<String, int> get maxScaleByPref {
    final m = <String, int>{};
    for (final p in points) {
      if (p.scale < 0) continue;
      final cur = m[p.pref];
      if (cur == null || p.scale > cur) m[p.pref] = p.scale;
    }
    return m;
  }

  factory EarthquakeInfo.fromJson(Map<String, dynamic> j) {
    final eq = j['earthquake'] as Map<String, dynamic>? ?? const {};
    final hypo = eq['hypocenter'] as Map<String, dynamic>? ?? const {};
    final lat = (hypo['latitude'] as num?)?.toDouble();
    final lng = (hypo['longitude'] as num?)?.toDouble();
    final depth = (hypo['depth'] as num?)?.toDouble();
    final mag = (hypo['magnitude'] as num?)?.toDouble();
    final maxScale = (eq['maxScale'] as num?)?.toInt();
    final timeStr = (eq['time'] as String?) ?? (j['time'] as String?);

    return EarthquakeInfo(
      id: (j['id'] ?? j['_id'] ?? '').toString(),
      time: _parseJmaTime(timeStr) ?? DateTime.now(),
      hypocenterName: hypo['name'] as String? ?? '不明',
      latitude: (lat != null && lat > -200) ? lat : null,
      longitude: (lng != null && lng > -200) ? lng : null,
      depth: (depth != null && depth >= 0) ? depth : null,
      magnitude: (mag != null && mag > 0) ? mag : null,
      maxScale: (maxScale != null && maxScale >= 0) ? maxScale : null,
      points: [
        for (final p in (j['points'] as List<dynamic>? ?? const []))
          EarthquakePoint.fromJson(p as Map<String, dynamic>),
      ],
      domesticTsunami: eq['domesticTsunami'] as String? ?? 'Unknown',
    );
  }
}

/// 「2024/01/01 01:23:45.678」のような、P2P地震情報の時刻表記を読む
DateTime? _parseJmaTime(String? s) {
  if (s == null || s.isEmpty) return null;
  try {
    final norm = s.replaceFirst('/', '-').replaceFirst('/', '-');
    return DateTime.parse(norm);
  } catch (_) {
    return null;
  }
}

List<EarthquakeInfo> parseEarthquakeHistory(Object? json) {
  if (json is! List) return const [];
  final list = [
    for (final e in json)
      if (e is Map<String, dynamic>) EarthquakeInfo.fromJson(e),
  ];
  list.sort((a, b) => b.time.compareTo(a.time));
  return list;
}

/// 震度（10倍表記）を「5弱」のような表示用文字列にする
String scaleLabel(int? scale) => switch (scale) {
  null => '不明',
  10 => '1',
  20 => '2',
  30 => '3',
  40 => '4',
  45 => '5弱',
  50 => '5強',
  55 => '6弱',
  60 => '6強',
  70 => '7',
  _ => '不明',
};

/// 国内の津波の有無を日本語にする
String tsunamiLabel(String v) => switch (v) {
  'Warning' => '津波の心配があります',
  'Checking' => '津波の有無を調査中',
  'NonEffectiveNearby' => '若干の海面変動があるかもしれません（被害の心配なし）',
  'NonEffective' => '被害を伴う津波の心配はありません',
  _ => '',
};
