/// タイムゾーン（世界時計）のための小さな道具
library;

import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

bool _ready = false;

/// タイムゾーンの表を1回だけ読み込む
void ensureTimeZones() {
  if (_ready) return;
  tzdata.initializeTimeZones();
  _ready = true;
}

/// 使えるタイムゾーンの名前（Asia/Tokyo など）をあいうえお順で
List<String> allTimeZoneNames() {
  ensureTimeZones();
  return tz.timeZoneDatabase.locations.keys.toList()..sort();
}

/// よく使いそうなものを先に出す
const commonTimeZoneNames = [
  'Asia/Tokyo',
  'Asia/Seoul',
  'Asia/Shanghai',
  'Asia/Singapore',
  'Asia/Kolkata',
  'Europe/London',
  'Europe/Paris',
  'Europe/Vienna',
  'America/New_York',
  'America/Los_Angeles',
  'Australia/Sydney',
  'UTC',
];

/// そのタイムゾーンの、その時点の時差（分）
int zoneOffsetMinutes(String name, DateTime at) {
  ensureTimeZones();
  try {
    return tz.TZDateTime.from(
      at,
      tz.getLocation(name),
    ).timeZoneOffset.inMinutes;
  } catch (e) {
    return 0;
  }
}

/// [from] から見た [to] の時差（分）。東京 → ウィーンなら -480 など
int zoneDifferenceMinutes(String from, String to, DateTime at) =>
    zoneOffsetMinutes(to, at) - zoneOffsetMinutes(from, at);

/// 「+09:00」の形
String offsetText(int minutes) {
  final sign = minutes < 0 ? '-' : '+';
  final m = minutes.abs();
  return '$sign${(m ~/ 60).toString().padLeft(2, '0')}:'
      '${(m % 60).toString().padLeft(2, '0')}';
}

/// 一覧に出す名前（例：Europe/Vienna（+02:00））
String timeZoneLabel(String name, DateTime at) =>
    '$name（${offsetText(zoneOffsetMinutes(name, at))}）';

/// そのタイムゾーンの、いまの時刻の分（0〜1439）
int nowMinutesIn(String name) {
  ensureTimeZones();
  try {
    final t = tz.TZDateTime.now(tz.getLocation(name));
    return t.hour * 60 + t.minute;
  } catch (e) {
    final t = DateTime.now();
    return t.hour * 60 + t.minute;
  }
}
