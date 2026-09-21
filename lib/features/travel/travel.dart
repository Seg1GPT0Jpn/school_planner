/// 移動時間の目安（距離から計算する。APIキーはいらない）
///
/// 自宅・学校（職場）から予定の場所までの「まっすぐの距離」に、
/// 道のりの曲がり具合（×1.3）と、乗り物ごとの速さ・待ち時間を足して目安を出す。
/// 正確な時間は Google マップの経路で確かめる。
library;

import 'dart:math' as math;

/// 移動のしかた
enum TravelMode {
  transit('電車・バス', 'transit'),
  car('車（送迎）', 'driving');

  const TravelMode(this.label, this.googleMode);

  final String label;

  /// Google マップの travelmode
  final String googleMode;
}

/// どこから出発するか
enum TravelOrigin {
  home('自宅'),
  school('学校');

  const TravelOrigin(this.label);

  final String label;
}

/// 緯度・経度
class LatLng {
  const LatLng(this.lat, this.lng);

  final double lat;
  final double lng;

  /// 「35.33890,139.49000」（Google マップに渡す形）
  String get text => '${lat.toStringAsFixed(5)},${lng.toStringAsFixed(5)}';

  @override
  bool operator ==(Object other) =>
      other is LatLng && other.lat == lat && other.lng == lng;

  @override
  int get hashCode => Object.hash(lat, lng);

  @override
  String toString() => text;
}

/// 2点間のまっすぐの距離（km）
double distanceKm(LatLng a, LatLng b) {
  const r = 6371.0;
  double rad(double d) => d * math.pi / 180;
  final dLat = rad(b.lat - a.lat);
  final dLng = rad(b.lng - a.lng);
  final h =
      math.pow(math.sin(dLat / 2), 2) +
      math.cos(rad(a.lat)) *
          math.cos(rad(b.lat)) *
          math.pow(math.sin(dLng / 2), 2);
  return 2 * r * math.asin(math.min(1, math.sqrt(h)));
}

/// 近すぎて移動の目安を出さない距離（km）
const nearKm = 0.3;

/// 文字の中の「35.3389,139.49」や、マップの URL の @35.33,139.49 / q=35.33,139.49 を読む
LatLng? parseLatLng(String text) {
  var t = text.trim();
  try {
    t = Uri.decodeFull(t);
  } catch (_) {
    // 「%」だけの文字などは、そのまま読む
  }
  final patterns = [
    RegExp(r'^\s*(-?\d{1,2}\.\d+)\s*[,，、 ]\s*(-?\d{1,3}\.\d+)\s*$'),
    RegExp(r'@(-?\d{1,2}\.\d+),(-?\d{1,3}\.\d+)'),
    RegExp(r'[?&](?:q|query|ll|destination)=(-?\d{1,2}\.\d+),(-?\d{1,3}\.\d+)'),
  ];
  for (final p in patterns) {
    final m = p.firstMatch(t);
    if (m == null) continue;
    final lat = double.parse(m.group(1)!), lng = double.parse(m.group(2)!);
    if (lat.abs() <= 90 && lng.abs() <= 180) return LatLng(lat, lng);
  }
  return null;
}

/// http(s) の URL か
bool isUrl(String text) {
  final u = Uri.tryParse(text.trim());
  return u != null && (u.scheme == 'http' || u.scheme == 'https');
}

/// 5分単位に切り上げ
int _ceil5(double minutes) => math.max(5, (minutes / 5).ceil() * 5);

/// まっすぐの距離（km）から、かかる時間の目安（分）
///
/// - 道のり ＝ まっすぐの距離 × 1.3
/// - 歩き：時速4.5km
/// - 電車・バス：駅やバス停までの歩き＋待ち（合わせて18分）＋時速28km
/// - 車：乗り降り・駐車（5分）＋時速25km
/// 近いときは歩いたほうが早ければ歩きの時間にする。
int estimateTravelMinutes(double straightKm, TravelMode mode) {
  final road = straightKm * 1.3;
  final walk = road / 4.5 * 60;
  final ride = switch (mode) {
    TravelMode.transit => 18 + road / 28 * 60,
    TravelMode.car => 5 + road / 25 * 60,
  };
  return _ceil5(math.min(walk, ride));
}

/// 歩いたほうが早い距離か（表示を「徒歩」にするため）
bool walkingIsFaster(double straightKm, TravelMode mode) {
  final road = straightKm * 1.3;
  final walk = road / 4.5 * 60;
  final ride = switch (mode) {
    TravelMode.transit => 18 + road / 28 * 60,
    TravelMode.car => 5 + road / 25 * 60,
  };
  return walk <= ride;
}

/// 移動の計画（いつ出ればよいか）
class TravelPlan {
  const TravelPlan({
    required this.origin,
    required this.mode,
    required this.distanceKm,
    required this.minutes,
    required this.bufferMinutes,
    required this.arriveBy,
    required this.walking,
  });

  final TravelOrigin origin;
  final TravelMode mode;

  /// まっすぐの距離（km）
  final double distanceKm;

  /// 移動にかかる時間の目安（分）
  final int minutes;

  /// 余裕（分）
  final int bufferMinutes;

  /// この時刻までに着きたい（予定の開始）
  final DateTime arriveBy;

  /// 歩きのほうが早い
  final bool walking;

  /// この時刻ごろに出発する
  DateTime get departAt =>
      arriveBy.subtract(Duration(minutes: minutes + bufferMinutes));

  /// 「電車・バス」「徒歩」など
  String get modeLabel => walking ? '徒歩' : mode.label;

  /// 「約8.2km」
  String get distanceLabel => distanceKm < 1
      ? '約${(distanceKm * 1000 / 100).round() * 100}m'
      : '約${distanceKm.toStringAsFixed(1)}km';
}

/// 出発地から予定の場所までの計画を立てる（近すぎるときは null）
TravelPlan? planTravel({
  required LatLng from,
  required LatLng to,
  required DateTime arriveBy,
  required TravelOrigin origin,
  required TravelMode mode,
  int bufferMinutes = 10,
}) {
  final km = distanceKm(from, to);
  if (km < nearKm) return null;
  return TravelPlan(
    origin: origin,
    mode: mode,
    distanceKm: km,
    minutes: estimateTravelMinutes(km, mode),
    bufferMinutes: bufferMinutes,
    arriveBy: arriveBy,
    walking: walkingIsFaster(km, mode),
  );
}

/// どこから出発しそうか
///
/// 学校のある日で、授業が終わったあと（夜8時まで）に始まる予定は「学校から」。
/// それ以外は「自宅から」。
TravelOrigin suggestOrigin({
  required DateTime start,
  required bool hasHome,
  required bool hasSchool,
  required bool departFromSchool,
  int? schoolEndMinutes,
}) {
  if (!hasSchool) return TravelOrigin.home;
  if (!hasHome) return TravelOrigin.school;
  if (!departFromSchool || schoolEndMinutes == null) return TravelOrigin.home;
  final m = start.hour * 60 + start.minute;
  if (m >= schoolEndMinutes && m < 20 * 60) return TravelOrigin.school;
  return TravelOrigin.home;
}

/// Google マップの経路の URL
///
/// 行き先は、住所・施設名ならその文字で（マップが施設を見つけやすい）、
/// URL しかないときは緯度・経度で渡す。
Uri directionsUri({
  required LatLng from,
  required String destinationText,
  LatLng? destination,
  required TravelMode mode,
}) {
  final t = destinationText.trim();
  final dest = (t.isEmpty || isUrl(t)) ? (destination?.text ?? t) : t;
  return Uri.https('www.google.com', '/maps/dir/', {
    'api': '1',
    'origin': from.text,
    'destination': dest,
    'travelmode': mode.googleMode,
  });
}
