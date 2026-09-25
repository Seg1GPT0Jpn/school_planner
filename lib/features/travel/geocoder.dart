/// 住所・施設名から緯度経度を調べる（APIキーのいらない無料のサービスだけを使う）
///
/// 1. 国土地理院の「地名検索」（住所に強い）
///    https://msearch.gsi.go.jp/address-search/AddressSearch?q=…
/// 2. 見つからなければ OpenStreetMap の Nominatim（駅や施設の名前に強い）
///    © OpenStreetMap contributors（ODbL）
///
/// 一度調べた場所は users/{uid}/places に覚えておき、同じ場所は二度と調べない
/// （Nominatim の利用ルール「結果はキャッシュする・連続で呼ばない」を守るため）。
library;

import 'dart:async';
import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import 'travel.dart';

/// 調べた結果
class GeoResult {
  const GeoResult(this.point, this.label);

  final LatLng point;

  /// 見つかった場所の名前（確認用）
  final String label;
}

class Geocoder {
  Geocoder._();

  static const _timeout = Duration(seconds: 10);

  /// アプリを開いている間だけの覚え（見つからなかったものも覚える）
  static final Map<String, GeoResult?> _memory = {};

  /// 同じ場所を同時に何回も調べないように
  static final Map<String, Future<GeoResult?>> _running = {};

  /// Nominatim は1秒に1回まで
  static DateTime _lastNominatim = DateTime(2000);

  /// 住所・施設名・「35.33,139.49」・マップの URL から、場所を調べる
  static Future<GeoResult?> lookup(String text) {
    final t = text.trim().replaceAll(RegExp(r'\s+'), ' ');
    if (t.isEmpty) return Future.value(null);

    final ll = parseLatLng(t);
    if (ll != null) return Future.value(GeoResult(ll, ll.text));
    // 短縮 URL などは中身がわからないので調べない
    if (isUrl(t)) return Future.value(null);

    if (_memory.containsKey(t)) return Future.value(_memory[t]);
    return _running[t] ??= _lookup(t).whenComplete(() {
      _running.remove(t);
    });
  }

  static Future<GeoResult?> _lookup(String t) async {
    final cache = _cacheDoc(t);
    // ① 覚えている場所
    if (cache != null) {
      try {
        final d = (await cache.get()).data();
        if (d != null && d['query'] == t) {
          final lat = d['lat'], lng = d['lng'];
          if (lat is num && lng is num) {
            final r = GeoResult(
              LatLng(lat.toDouble(), lng.toDouble()),
              d['label'] is String ? d['label'] as String : t,
            );
            return _memory[t] = r;
          }
        }
      } catch (_) {
        // 読めなくても、調べ直せばよい
      }
    }

    // ② 国土地理院 → ③ Nominatim
    final r = await _gsi(t) ?? await _nominatim(t);
    _memory[t] = r;
    if (r != null && cache != null) {
      unawaited(
        cache
            .set({
              'query': t,
              'lat': r.point.lat,
              'lng': r.point.lng,
              'label': r.label,
              'updatedAt': FieldValue.serverTimestamp(),
            })
            .catchError((Object _) {}),
      );
    }
    return r;
  }

  /// 覚えておく場所（ログインしていない・長すぎる文字は覚えない）
  static DocumentReference<Map<String, dynamic>>? _cacheDoc(String t) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return null;
    final id = base64Url.encode(utf8.encode(t)).replaceAll('=', '');
    if (id.length > 700) return null;
    return FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('places')
        .doc(id);
  }

  static Future<GeoResult?> _gsi(String t) async {
    try {
      final uri = Uri.https(
        'msearch.gsi.go.jp',
        '/address-search/AddressSearch',
        {'q': t},
      );
      final res = await http.get(uri).timeout(_timeout);
      if (res.statusCode != 200) return null;
      return parseGsi(utf8.decode(res.bodyBytes));
    } catch (_) {
      return null;
    }
  }

  /// 緯度経度から、大まかな地名を調べる（現在地の天気の表示名などに使う）
  ///
  /// Nominatim の reverse ジオコーディングだけを使う（現在地はキャッシュしない）。
  static Future<String?> reverse(double lat, double lng) async {
    try {
      final wait =
          const Duration(milliseconds: 1100) -
          DateTime.now().difference(_lastNominatim);
      if (wait > Duration.zero) await Future<void>.delayed(wait);
      _lastNominatim = DateTime.now();

      final uri = Uri.https('nominatim.openstreetmap.org', '/reverse', {
        'lat': '$lat',
        'lon': '$lng',
        'format': 'jsonv2',
        'accept-language': 'ja',
        'zoom': '12',
      });
      final res = await http
          .get(
            uri,
            headers: kIsWeb
                ? null
                : {'User-Agent': 'Tsuzuri-school-planner/1.0'},
          )
          .timeout(_timeout);
      if (res.statusCode != 200) return null;
      final j = jsonDecode(utf8.decode(res.bodyBytes));
      if (j is! Map) return null;
      final addr = j['address'];
      if (addr is Map) {
        final name =
            addr['city'] ??
            addr['town'] ??
            addr['village'] ??
            addr['suburb'] ??
            addr['county'];
        if (name is String && name.isNotEmpty) return name;
      }
      final display = j['display_name'];
      return display is String ? display : null;
    } catch (_) {
      return null;
    }
  }

  static Future<GeoResult?> _nominatim(String t) async {
    try {
      final wait =
          const Duration(milliseconds: 1100) -
          DateTime.now().difference(_lastNominatim);
      if (wait > Duration.zero) await Future<void>.delayed(wait);
      _lastNominatim = DateTime.now();

      final uri = Uri.https('nominatim.openstreetmap.org', '/search', {
        'q': t,
        'format': 'jsonv2',
        'limit': '1',
        'countrycodes': 'jp',
        'accept-language': 'ja',
      });
      // ブラウザでは User-Agent を変えられないので、アプリのときだけ名乗る
      final res = await http
          .get(
            uri,
            headers: kIsWeb
                ? null
                : {'User-Agent': 'Tsuzuri-school-planner/1.0'},
          )
          .timeout(_timeout);
      if (res.statusCode != 200) return null;
      return parseNominatim(utf8.decode(res.bodyBytes));
    } catch (_) {
      return null;
    }
  }
}

/// 国土地理院の結果を読む（[{geometry:{coordinates:[経度,緯度]}, properties:{title}}]）
@visibleForTesting
GeoResult? parseGsi(String body) {
  final list = jsonDecode(body);
  if (list is! List || list.isEmpty) return null;
  final f = list.first;
  if (f is! Map) return null;
  final c = (f['geometry'] as Map?)?['coordinates'];
  if (c is! List || c.length < 2 || c[0] is! num || c[1] is! num) return null;
  final title = (f['properties'] as Map?)?['title'];
  return GeoResult(
    LatLng((c[1] as num).toDouble(), (c[0] as num).toDouble()),
    title is String ? title : '',
  );
}

/// Nominatim の結果を読む（[{lat:"35.3", lon:"139.4", display_name}]）
@visibleForTesting
GeoResult? parseNominatim(String body) {
  final list = jsonDecode(body);
  if (list is! List || list.isEmpty) return null;
  final f = list.first;
  if (f is! Map) return null;
  final lat = double.tryParse('${f['lat']}');
  final lng = double.tryParse('${f['lon']}');
  if (lat == null || lng == null) return null;
  final name = f['display_name'];
  return GeoResult(LatLng(lat, lng), name is String ? name : '');
}
