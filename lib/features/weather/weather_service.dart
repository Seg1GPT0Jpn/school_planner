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

  // 現在地の天気（学校の天気とは別に覚えておく）
  WeatherBundle? _lastAt;
  Future<WeatherBundle>? _loadingAt;
  double? _lastAtLat, _lastAtLng;

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

  /// 指定した場所の天気を取ってくる（現在地など、学校以外の場所用）
  Future<WeatherBundle> loadAt({
    required double latitude,
    required double longitude,
    bool force = false,
  }) {
    final last = _lastAt;
    final samePlace = _lastAtLat == latitude && _lastAtLng == longitude;
    if (!force &&
        samePlace &&
        last != null &&
        DateTime.now().difference(last.fetchedAt) < _keep) {
      return Future.value(last);
    }
    if (!samePlace) {
      _lastAt = null;
      _lastAtLat = latitude;
      _lastAtLng = longitude;
    }
    return _loadingAt ??= _fetch(latitude: latitude, longitude: longitude)
        .then((b) => _lastAt = b)
        .whenComplete(() => _loadingAt = null);
  }

  /// いま持っているもの（まだ一度も取っていなければ null）
  WeatherBundle? get cached => _last;

  /// 現在地で最後に取ったもの
  WeatherBundle? get cachedAt => _lastAt;

  Future<Object?> _getJson(Uri uri) async {
    final res = await http.get(uri).timeout(_timeout);
    if (res.statusCode != 200) {
      throw Exception('HTTP ${res.statusCode}');
    }
    return jsonDecode(utf8.decode(res.bodyBytes));
  }

  /// latitude/longitude を指定したときは、その場所の天気予報だけを取る
  /// （警報・注意報は市区町村単位の気象庁の区域コードに対応づけできないため、
  /// 学校の場所（藤沢市）のものを参考として引き続き表示する）
  Future<WeatherBundle> _fetch({double? latitude, double? longitude}) async {
    final errors = <String>[];
    final now = DateTime.now();
    final atOtherPlace = latitude != null && longitude != null;

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
        final j = await _getJson(
          atOtherPlace
              ? openMeteoUri(latitude: latitude, longitude: longitude)
              : openMeteoUri(),
        );
        return parseOpenMeteo(j! as Map<String, dynamic>, fetchedAt: now);
      }),
      attempt('気象庁の警報', () async {
        return parseAreaWarnings(await _getJson(jmaWarningUri()));
      }),
      attempt('気象庁の台風情報', () async {
        return parseTyphoons(await _getJson(jmaTyphoonUri()));
      }),
      attempt('大気質', () async {
        final j = await _getJson(
          atOtherPlace
              ? openMeteoAirQualityUri(latitude: latitude, longitude: longitude)
              : openMeteoAirQualityUri(),
        );
        return parseOpenMeteoAirQuality(j! as Map<String, dynamic>);
      }),
    ]);

    final rawForecast = results[0] as WeatherForecast?;
    final airQuality = results[3] as AirQuality?;

    final bundle = WeatherBundle(
      fetchedAt: now,
      forecast: rawForecast == null || airQuality == null
          ? rawForecast
          : rawForecast.mergeAirQuality(airQuality),
      warnings: results[1] as AreaWarnings?,
      typhoons: (results[2] as List<String>?) ?? const [],
      errors: errors,
    );
    if (atOtherPlace) return bundle;
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
