/// 地震情報を取ってくる係（5分間は同じものを使い回す）
///
/// P2P地震情報 API（https://api.p2pquake.net/）を使用。
/// 気象庁の地震情報をもとにした、無料・登録不要の JSON 配信。
library;

import 'dart:convert';

import 'package:http/http.dart' as http;

import 'earthquake_models.dart';

class EarthquakeService {
  EarthquakeService._();
  static final instance = EarthquakeService._();

  static const _keep = Duration(minutes: 5);
  static const _timeout = Duration(seconds: 15);
  static final _historyUri = Uri.parse(
    'https://api.p2pquake.net/v2/history?codes=551&limit=100',
  );

  List<EarthquakeInfo>? _last;
  DateTime? _fetchedAt;
  Future<List<EarthquakeInfo>>? _loading;
  String? lastError;

  /// 過去100件ほどの地震履歴（震度1以上のものが中心。新しい順）
  Future<List<EarthquakeInfo>> load({bool force = false}) {
    final last = _last;
    final at = _fetchedAt;
    if (!force &&
        last != null &&
        at != null &&
        DateTime.now().difference(at) < _keep) {
      return Future.value(last);
    }
    return _loading ??= _fetch().whenComplete(() => _loading = null);
  }

  List<EarthquakeInfo>? get cached => _last;

  Future<List<EarthquakeInfo>> _fetch() async {
    try {
      final res = await http.get(_historyUri).timeout(_timeout);
      if (res.statusCode != 200) {
        throw Exception('HTTP ${res.statusCode}');
      }
      final json = jsonDecode(utf8.decode(res.bodyBytes));
      final list = parseEarthquakeHistory(json);
      _last = list;
      _fetchedAt = DateTime.now();
      lastError = null;
      return list;
    } catch (e) {
      lastError = '$e';
      if (_last != null) return _last!;
      rethrow;
    }
  }
}

/// 防災科学技術研究所（NIED）強震モニタ（本物のリアルタイム震度）
final kmoniUri = Uri.parse('https://www.kmoni.bosai.go.jp/');
