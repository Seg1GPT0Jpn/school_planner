/// 車移動の「実際の道なり」の時間を、無料・キー不要の OSRM から取ってくる
///
/// OSRM（project-osrm.org のデモサーバー）は、渋滞は考慮しないが、
/// 実際の道路網にそって時間を計算してくれる（直線距離×係数より正確）。
/// 取れないときは null を返すだけで、呼び出し側は今まで通りの目安を使う。
library;

import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import 'travel.dart';

class OsrmService {
  OsrmService._();
  static final instance = OsrmService._();

  static const _keep = Duration(minutes: 30);
  static const _timeout = Duration(seconds: 8);

  final _cache = <String, (int minutes, DateTime at)>{};

  String _key(LatLng from, LatLng to) => '${from.text}>${to.text}';

  /// 実際の道なりでかかる時間（分）。取れないときは null
  Future<int?> fetchCarMinutes({required LatLng from, required LatLng to}) async {
    final key = _key(from, to);
    final cached = _cache[key];
    if (cached != null && DateTime.now().difference(cached.$2) < _keep) {
      return cached.$1;
    }
    final uri = Uri.https(
      'router.project-osrm.org',
      '/route/v1/driving/${from.lng},${from.lat};${to.lng},${to.lat}',
      {'overview': 'false'},
    );
    try {
      final res = await http.get(uri).timeout(_timeout);
      if (res.statusCode != 200) return null;
      final json = jsonDecode(res.body);
      if (json is! Map || json['code'] != 'Ok') return null;
      final routes = json['routes'];
      if (routes is! List || routes.isEmpty) return null;
      final seconds = (routes.first['duration'] as num?)?.toDouble();
      if (seconds == null) return null;
      final minutes = (seconds / 60).ceil().clamp(1, 24 * 60);
      _cache[key] = (minutes, DateTime.now());
      return minutes;
    } catch (_) {
      return null;
    }
  }
}
