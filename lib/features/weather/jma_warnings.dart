/// 気象庁の警報・注意報（令和8年からの新しい形・r8）を読む
///
/// データ：https://www.jma.go.jp/bosai/warning/data/r8/{府県のコード}.json
/// （古い /bosai/warning/data/warning/ は 2026年5月28日で止まっているので使わない）
library;

/// 神奈川県
const String kanagawaOfficeCode = '140000';

/// 藤沢市
const String fujisawaAreaCode = '1420500';

/// 何の危険か
enum Hazard {
  heavyRain('大雨'),
  landslide('土砂災害'),
  flood('河川氾濫'),
  stormSurge('高潮'),
  snow('大雪'),
  wind('暴風'),
  blizzard('暴風雪'),
  wave('波浪'),
  other('その他');

  const Hazard(this.label);
  final String label;
}

/// 警報のコード → 何の危険の、どのレベルか
///
/// レベル5 特別警報 / レベル4 危険警報 / レベル3 警報 / レベル2 注意報。
/// 大雪・暴風・暴風雪・波浪にはレベルがないので、特別警報を5、警報を3、注意報を2として扱う。
const Map<String, ({Hazard hazard, int level})> warningCodes = {
  // 特別警報
  '33': (hazard: Hazard.heavyRain, level: 5),
  '39': (hazard: Hazard.landslide, level: 5),
  '34': (hazard: Hazard.flood, level: 5),
  '38': (hazard: Hazard.stormSurge, level: 5),
  '36': (hazard: Hazard.snow, level: 5),
  '35': (hazard: Hazard.wind, level: 5),
  '32': (hazard: Hazard.blizzard, level: 5),
  '37': (hazard: Hazard.wave, level: 5),
  // 危険警報
  '43': (hazard: Hazard.heavyRain, level: 4),
  '49': (hazard: Hazard.landslide, level: 4),
  '44': (hazard: Hazard.flood, level: 4),
  '48': (hazard: Hazard.stormSurge, level: 4),
  // 警報
  '03': (hazard: Hazard.heavyRain, level: 3),
  '09': (hazard: Hazard.landslide, level: 3),
  '04': (hazard: Hazard.flood, level: 3),
  '08': (hazard: Hazard.stormSurge, level: 3),
  '06': (hazard: Hazard.snow, level: 3),
  '05': (hazard: Hazard.wind, level: 3),
  '02': (hazard: Hazard.blizzard, level: 3),
  '07': (hazard: Hazard.wave, level: 3),
  // 注意報
  '10': (hazard: Hazard.heavyRain, level: 2),
  '29': (hazard: Hazard.landslide, level: 2),
  '18': (hazard: Hazard.flood, level: 2),
  '19': (hazard: Hazard.stormSurge, level: 2),
  '12': (hazard: Hazard.snow, level: 2),
  '15': (hazard: Hazard.wind, level: 2),
  '13': (hazard: Hazard.blizzard, level: 2),
  '16': (hazard: Hazard.wave, level: 2),
};

/// そのほかの注意報の名前
const Map<String, String> otherAdvisoryNames = {
  '14': '雷注意報',
  '17': '融雪注意報',
  '20': '濃霧注意報',
  '21': '乾燥注意報',
  '22': 'なだれ注意報',
  '23': '低温注意報',
  '24': '霜注意報',
  '25': '着氷注意報',
  '26': '着雪注意報',
};

/// 画面に出す名前（例：レベル4大雨危険警報・暴風警報）
String warningName(Hazard hazard, int level) {
  final leveled =
      hazard == Hazard.heavyRain ||
      hazard == Hazard.landslide ||
      hazard == Hazard.flood ||
      hazard == Hazard.stormSurge;
  final name = switch (hazard) {
    Hazard.flood => '氾濫',
    _ => hazard.label,
  };
  final kind = switch (level) {
    >= 5 => '特別警報',
    4 => '危険警報',
    3 => '警報',
    _ => '注意報',
  };
  return leveled ? 'レベル$level$name$kind' : '$name$kind';
}

/// これから危なくなる時間帯（「21日14時から22日0時まで、警戒レベル４相当」など）
class WarningPeriod {
  const WarningPeriod({
    required this.start,
    required this.end,
    required this.sentence,
    this.level,
  });

  final DateTime start;
  final DateTime end;
  final String sentence;

  /// 文から読み取った警戒レベル（読めなければ null）
  final int? level;

  bool covers(DateTime t) => !t.isBefore(start) && t.isBefore(end);
}

/// いま出ている警報・注意報1つ
class ActiveWarning {
  const ActiveWarning({
    required this.code,
    required this.name,
    required this.level,
    required this.status,
    this.hazard,
    this.periods = const [],
    this.additions = const [],
  });

  final String code;
  final String name;
  final Hazard? hazard;

  /// 2〜5（そのほかの注意報は 2）
  final int level;

  /// 発表・継続 など
  final String status;

  final List<WarningPeriod> periods;

  /// 「竜巻」「うねり」など
  final List<String> additions;
}

/// 藤沢市の警報のまとめ
class AreaWarnings {
  const AreaWarnings({
    required this.reportTime,
    required this.warnings,
    this.headline = '',
  });

  /// いちばん新しい発表時刻
  final DateTime? reportTime;
  final List<ActiveWarning> warnings;
  final String headline;

  /// 高いレベルから
  List<ActiveWarning> get sorted =>
      [...warnings]..sort((a, b) => b.level.compareTo(a.level));

  int get maxLevel => warnings.fold(0, (m, w) => w.level > m ? w.level : m);
}

/// 全角の数字を半角にする
String _hankaku(String s) => s.replaceAllMapped(
  RegExp('[０-９]'),
  (m) => String.fromCharCode(m[0]!.codeUnitAt(0) - 0xFEE0),
);

int? _levelIn(String sentence) {
  final m = RegExp(r'レベル\s*([1-5])').firstMatch(_hankaku(sentence));
  return m == null ? null : int.parse(m.group(1)!);
}

/// ISO 8601 の「PT10H」「PT30M」「P1DT3H」を読む
Duration _duration(String? s) {
  if (s == null) return Duration.zero;
  final m = RegExp(r'^P(?:(\d+)D)?(?:T(?:(\d+)H)?(?:(\d+)M)?)?$').firstMatch(s);
  if (m == null) return Duration.zero;
  int n(int i) => int.tryParse(m.group(i) ?? '') ?? 0;
  return Duration(days: n(1), hours: n(2), minutes: n(3));
}

bool _isActive(String status) =>
    status != '解除' && !status.contains('なし') && status.isNotEmpty;

/// その市町村の項目をさがす（形が少し変わっても読めるよう、全体をたどる）
List<Map<String, dynamic>> _itemsFor(Object? node, String areaCode) {
  final out = <Map<String, dynamic>>[];
  void walk(Object? n) {
    if (n is Map<String, dynamic>) {
      if (n['areaCode'] == areaCode && n['kinds'] is List) {
        out.add(n);
        return;
      }
      n.values.forEach(walk);
    } else if (n is List) {
      n.forEach(walk);
    }
  }

  walk(node);
  return out;
}

/// r8 の JSON から、その市町村でいま出ている警報・注意報を読む
AreaWarnings parseAreaWarnings(
  Object? json, {
  String areaCode = fujisawaAreaCode,
}) {
  final reports = json is List ? json : [json];
  final byCode = <String, ActiveWarning>{};
  DateTime? latest;
  final headlines = <String>[];

  for (final r in reports) {
    if (r is! Map<String, dynamic>) continue;
    final t = DateTime.tryParse('${r['reportDatetime']}');
    if (t != null && (latest == null || t.isAfter(latest))) latest = t;
    final h = r['headlineText'];
    if (h is String && h.trim().isNotEmpty && !headlines.contains(h.trim())) {
      headlines.add(h.trim());
    }

    for (final item in _itemsFor(r['warning'] ?? r, areaCode)) {
      for (final k in item['kinds'] as List) {
        if (k is! Map<String, dynamic>) continue;
        final code = '${k['code'] ?? ''}'.padLeft(2, '0');
        final status = '${k['status'] ?? ''}';
        if (!_isActive(status)) continue;

        final known = warningCodes[code];
        final name = known != null
            ? warningName(known.hazard, known.level)
            : (otherAdvisoryNames[code] ?? 'コード$code');

        final periods = <WarningPeriod>[];
        for (final p in (k['properties'] as List? ?? const [])) {
          final cp = p is Map ? p['criteriaPeriod'] : null;
          final locals = cp is Map && cp['locals'] is List
              ? cp['locals'] as List
              : const [];
          for (final l in locals) {
            if (l is! Map) continue;
            final start = DateTime.tryParse('${l['time']}');
            if (start == null) continue;
            final sentence = '${l['sentence'] ?? ''}';
            periods.add(
              WarningPeriod(
                start: start,
                end: start.add(_duration(l['duration'] as String?)),
                sentence: sentence,
                level: _levelIn(sentence),
              ),
            );
          }
        }

        final w = ActiveWarning(
          code: code,
          name: name,
          hazard: known?.hazard,
          level: known?.level ?? 2,
          status: status,
          periods: periods,
          additions: [
            for (final a in (k['additions'] as List? ?? const [])) '$a',
          ],
        );
        // 同じコードが何度も出てきたら、情報が多いほうを残す
        final old = byCode[code];
        if (old == null || w.periods.length > old.periods.length) {
          byCode[code] = w;
        }
      }
    }
  }

  return AreaWarnings(
    reportTime: latest,
    warnings: byCode.values.toList(),
    headline: headlines.join('\n'),
  );
}

Uri jmaWarningUri([String officeCode = kanagawaOfficeCode]) =>
    Uri.https('www.jma.go.jp', '/bosai/warning/data/r8/$officeCode.json');

Uri jmaTyphoonUri() =>
    Uri.https('www.jma.go.jp', '/bosai/typhoon/data/targetTc.json');

/// いま発生している台風（台風番号のリスト。例：2625 → 台風25号）
List<String> parseTyphoons(Object? json) => [
  if (json is List)
    for (final t in json)
      if (t is Map && t['typhoonNumber'] != null) '${t['typhoonNumber']}',
];

/// 「2625」→「台風25号」
String typhoonLabel(String number) {
  final n = int.tryParse(number.length > 2 ? number.substring(2) : number);
  return n == null ? '台風' : '台風$n号';
}
