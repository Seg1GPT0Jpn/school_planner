/// 天気予報・警報・台風を取ってくる係（10分間は同じものを使い回す）
library;

import 'dart:convert';

import 'package:http/http.dart' as http;

import 'jma_warnings.dart';
import 'weather_models.dart';

/// まとめて取ってきたもの（取れなかったものは null と、その理由）
class WeatherBundle {
  const WeatherBundle({
    required this.fetchedAt,
    this.forecast,
    this.warnings,
    this.typhoons = const [],
    this.errors = const [],
  });

  final DateTime fetchedAt;
  final WeatherForecast? forecast;
  final AreaWarnings? warnings;
  final List<String> typhoons;

  /// 取れなかったものの説明
  final List<String> errors;
}

class WeatherService {
  WeatherService._();
  static final instance = WeatherService._();

  static const _keep = Duration(minutes: 10);
  static const _timeout = Duration(seconds: 15);

  WeatherBundle? _last;
  Future<WeatherBundle>? _loading;

  /// 取ってくる（10分以内なら前のものを返す。force なら取り直す）
  Future<WeatherBundle> load({bool force = false}) {
    final last = _last;
    if (!force &&
        last != null &&
        DateTime.now().difference(last.fetchedAt) < _keep) {
      return Future.value(last);
    }
    return _loading ??= _fetch().whenComplete(() => _loading = null);
  }

  /// いま持っているもの（まだ一度も取っていなければ null）
  WeatherBundle? get cached => _last;

  Future<Object?> _getJson(Uri uri) async {
    final res = await http.get(uri).timeout(_timeout);
    if (res.statusCode != 200) {
      throw Exception('HTTP ${res.statusCode}');
    }
    return jsonDecode(utf8.decode(res.bodyBytes));
  }

  Future<WeatherBundle> _fetch() async {
    final errors = <String>[];
    final now = DateTime.now();

    Future<T?> attempt<T>(String what, Future<T> Function() f) async {
      try {
        return await f();
      } catch (e) {
        errors.add('$what を取れませんでした（$e）');
        return null;
      }
    }

    final results = await Future.wait([
      attempt('天気予報', () async {
        final j = await _getJson(openMeteoUri());
        return parseOpenMeteo(j! as Map<String, dynamic>, fetchedAt: now);
      }),
      attempt('気象庁の警報', () async {
        return parseAreaWarnings(await _getJson(jmaWarningUri()));
      }),
      attempt('気象庁の台風情報', () async {
        return parseTyphoons(await _getJson(jmaTyphoonUri()));
      }),
    ]);

    final bundle = WeatherBundle(
      fetchedAt: now,
      forecast: results[0] as WeatherForecast?,
      warnings: results[1] as AreaWarnings?,
      typhoons: (results[2] as List<String>?) ?? const [],
      errors: errors,
    );
    // 何も取れなかったときは、前のものを残す
    if (bundle.forecast != null || bundle.warnings != null || _last == null) {
      _last = bundle;
    }
    return bundle;
  }
}

/// 気象庁のページ（地図など）
final jmaPages = <({String label, String description, Uri uri})>[
  (
    label: '雨雲の動き',
    description: 'いまと1時間先までの雨雲（レーダー）',
    uri: Uri.parse('https://www.jma.go.jp/bosai/nowc/'),
  ),
  (
    label: '今後の雨',
    description: '15時間先までの雨の予想',
    uri: Uri.parse('https://www.jma.go.jp/bosai/kaikotan/'),
  ),
  (
    label: '天気図',
    description: '実況と予想の天気図',
    uri: Uri.parse('https://www.jma.go.jp/bosai/weather_map/'),
  ),
  (
    label: '台風情報',
    description: '台風の位置と進路の予報',
    uri: Uri.parse('https://www.jma.go.jp/bosai/map.html#contents=typhoon'),
  ),
  (
    label: '藤沢市の警報・注意報',
    description: '気象庁の警報のページ',
    uri: Uri.parse(
      'https://www.jma.go.jp/bosai/warning/#area_type=class20s&area_code=1420500&lang=ja',
    ),
  ),
  (
    label: 'キキクル（危険度分布）',
    description: '土砂災害・浸水・洪水の危険度',
    uri: Uri.parse('https://www.jma.go.jp/bosai/risk/'),
  ),
];
