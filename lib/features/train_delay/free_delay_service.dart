/// キー不要で使える、もう一つの遅延情報源（てつどう遅延情報 / rti-giken）
///
/// Cloud Functions（ODPT）が使えないとき（Blazeプラン未設定など）に、
/// アプリから直接・無料で読みにいく代わりの情報源。APIキーは不要。
/// このAPIは「いま遅延している路線だけ」を返すので、載っていない路線は
/// 平常運転とみなす。
library;

import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

class FreeDelayInfo {
  const FreeDelayInfo({
    required this.company,
    required this.name,
    required this.text,
  });

  final String company;
  final String name;
  final String text;
}

class FreeDelayService {
  FreeDelayService._();
  static final instance = FreeDelayService._();

  static final _uri = Uri.parse(
    'https://api.tetsudou.rti-giken.jp/free/delay.json',
  );
  static const _keep = Duration(minutes: 5);
  static const _timeout = Duration(seconds: 8);

  List<FreeDelayInfo>? _last;
  DateTime? _fetchedAt;
  Future<List<FreeDelayInfo>>? _loading;

  /// いま遅延している路線の一覧（取れないときは前回の結果、それも無ければ空）
  Future<List<FreeDelayInfo>> load({bool force = false}) {
    final last = _last, at = _fetchedAt;
    if (!force &&
        last != null &&
        at != null &&
        DateTime.now().difference(at) < _keep) {
      return Future.value(last);
    }
    return _loading ??= _fetch().whenComplete(() => _loading = null);
  }

  Future<List<FreeDelayInfo>> _fetch() async {
    try {
      final res = await http.get(_uri).timeout(_timeout);
      if (res.statusCode != 200) throw Exception('HTTP ${res.statusCode}');
      final decoded = jsonDecode(utf8.decode(res.bodyBytes));
      if (decoded is! List) throw const FormatException('想定外の形式でした');

      final list = <FreeDelayInfo>[
        for (final item in decoded)
          if (item is Map)
            FreeDelayInfo(
              company: '${item['company'] ?? item['operator'] ?? ''}',
              name: '${item['name'] ?? item['line'] ?? ''}',
              text: '${item['text'] ?? item['status'] ?? item['cause'] ?? ''}',
            ),
      ];
      _last = list;
      _fetchedAt = DateTime.now();
      return list;
    } catch (_) {
      // 取れないときは、前回の結果（無ければ空）をそのまま使う
      return _last ?? const [];
    }
  }

  /// 「線」「ライン」を取って、ゆるく比べるための正規化
  static String _norm(String s) =>
      s.trim().replaceAll(RegExp(r'(線|ライン)$'), '');

  /// 路線名に一致する遅延情報を探す（表記ゆれをゆるく吸収する）
  static FreeDelayInfo? findFor(List<FreeDelayInfo> list, String lineName) {
    final target = _norm(lineName);
    if (target.isEmpty) return null;
    for (final d in list) {
      final n = _norm(d.name);
      if (n.isEmpty) continue;
      if (n == target || n.contains(target) || target.contains(n)) return d;
    }
    return null;
  }
}
