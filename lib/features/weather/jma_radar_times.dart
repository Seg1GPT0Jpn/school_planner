/// 気象庁「高解像度降水ナウキャスト」の時刻リストを取ってくる
///
/// 気象庁が自分のサイト（https://www.jma.go.jp/bosai/nowc/）で使っている
/// タイル配信の仕組みをそのまま利用する。公式に「外部アプリ向け」として
/// 公開されているAPIではない（ドキュメントが無い）ため、気象庁側の都合で
/// 予告なく形式が変わったり、使えなくなったりする可能性がある。
library;

import 'dart:convert';

import 'package:http/http.dart' as http;

/// 1コマぶんの時刻（実況＝過去〜今、または予報＝これから1時間）
class RadarFrame {
  const RadarFrame({
    required this.basetime,
    required this.validtime,
    required this.time,
    required this.isForecast,
  });

  /// 気象庁のデータ生成時刻（YYYYMMDDHHmmss）
  final String basetime;

  /// このコマが表す時刻（YYYYMMDDHHmmss）
  final String validtime;

  final DateTime time;

  /// これからの予報（true）か、実況＝観測ずみ（false）か
  final bool isForecast;

  String get tileUrlTemplate =>
      'https://www.jma.go.jp/bosai/jmatile/data/nowc/$basetime/none/$validtime/surf/hrpns';
}

DateTime? _parseJmaTime(String s) {
  if (s.length < 14) return null;
  try {
    return DateTime.utc(
      int.parse(s.substring(0, 4)),
      int.parse(s.substring(4, 6)),
      int.parse(s.substring(6, 8)),
      int.parse(s.substring(8, 10)),
      int.parse(s.substring(10, 12)),
      int.parse(s.substring(12, 14)),
    ).toLocal();
  } catch (_) {
    return null;
  }
}

List<RadarFrame> _parse(Object? json, {required bool isForecast}) {
  if (json is! List) return const [];
  final out = <RadarFrame>[];
  for (final e in json) {
    if (e is! Map) continue;
    final elements = e['elements'];
    if (elements is List && !elements.contains('hrpns')) continue;
    final basetime = e['basetime'];
    final validtime = e['validtime'];
    if (basetime is! String || validtime is! String) continue;
    final t = _parseJmaTime(validtime);
    if (t == null) continue;
    out.add(
      RadarFrame(
        basetime: basetime,
        validtime: validtime,
        time: t,
        isForecast: isForecast,
      ),
    );
  }
  return out;
}

/// 実況（直近ぶん）＋予報（1時間先まで）をあわせた時刻リストを取ってくる
/// （実況が新しい順、予報が古い順に並んでいることがあるので、時刻順にそろえる）
Future<List<RadarFrame>> fetchRadarFrames() async {
  const timeout = Duration(seconds: 10);
  final results = await Future.wait([
    http
        .get(
          Uri.parse(
            'https://www.jma.go.jp/bosai/jmatile/data/nowc/targetTimes_N1.json',
          ),
        )
        .timeout(timeout),
    http
        .get(
          Uri.parse(
            'https://www.jma.go.jp/bosai/jmatile/data/nowc/targetTimes_N2.json',
          ),
        )
        .timeout(timeout),
  ]);

  final past = _parse(
    results[0].statusCode == 200
        ? jsonDecode(utf8.decode(results[0].bodyBytes))
        : null,
    isForecast: false,
  );
  final forecast = _parse(
    results[1].statusCode == 200
        ? jsonDecode(utf8.decode(results[1].bodyBytes))
        : null,
    isForecast: true,
  );

  final byTime = <String, RadarFrame>{};
  for (final f in [...past, ...forecast]) {
    byTime[f.validtime] = f;
  }
  final list = byTime.values.toList()..sort((a, b) => a.time.compareTo(b.time));
  return list;
}
