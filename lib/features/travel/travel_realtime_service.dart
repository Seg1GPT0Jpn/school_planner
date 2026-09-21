/// 渋滞・電車の遅れを考慮した「本当の」移動時間を取ってくる係
///
/// 実際の取得は Cloud Functions（getTravelEstimate）が行う（Google Maps
/// Directions API）。この関数がまだデプロイされていない・失敗したときは、
/// null を返すだけで、呼び出し側は距離から出した目安（travel.dart）を
/// そのまま使い続ける。つまり「読み取れないときは、今まで通りの代替手段」に
/// 自動で切りかわる。
library;

import 'package:cloud_functions/cloud_functions.dart';

import 'travel.dart';

class TravelEstimate {
  const TravelEstimate({required this.minutes, required this.fetchedAt});
  final int minutes;
  final DateTime fetchedAt;
}

class TravelRealtimeService {
  TravelRealtimeService._();
  static final instance = TravelRealtimeService._();

  static const _keep = Duration(minutes: 5);

  final _cache = <String, TravelEstimate>{};

  String _key(LatLng from, LatLng to, TravelMode mode, DateTime? arriveBy) =>
      '${from.text}>${to.text}|${mode.name}|'
      '${arriveBy == null ? '' : arriveBy.millisecondsSinceEpoch ~/ 60000}';

  /// 実際の移動時間（分）。取得できないときは null（呼び出し側は目安を使う）
  Future<int?> fetchMinutes({
    required LatLng from,
    required LatLng to,
    required TravelMode mode,
    DateTime? arriveBy,
  }) async {
    final key = _key(from, to, mode, arriveBy);
    final cached = _cache[key];
    if (cached != null &&
        DateTime.now().difference(cached.fetchedAt) < _keep) {
      return cached.minutes;
    }
    try {
      final callable = FirebaseFunctions.instanceFor(
        region: 'asia-northeast1',
      ).httpsCallable('getTravelEstimate');
      final res = await callable.call<Map<String, dynamic>>({
        'originLat': from.lat,
        'originLng': from.lng,
        'destLat': to.lat,
        'destLng': to.lng,
        'mode': mode.googleMode == 'driving' ? 'driving' : 'transit',
        if (arriveBy != null) 'arriveByMs': arriveBy.millisecondsSinceEpoch,
      });
      final minutes = (res.data['minutes'] as num?)?.toInt();
      if (minutes == null) return null;
      _cache[key] = TravelEstimate(minutes: minutes, fetchedAt: DateTime.now());
      return minutes;
    } catch (_) {
      // 未デプロイ・エラーのときは、静かに諦める（呼び出し側が目安にフォールバック）
      return null;
    }
  }
}
