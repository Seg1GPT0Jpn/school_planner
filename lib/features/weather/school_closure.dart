/// 荒天のときの「自宅待機（休校）」の判定と予測
///
/// 学校のきまり（午前6時の時点で藤沢市に…）
/// ① レベル4以上の警報が出ている
/// ② 「大雨」「河川氾濫」「土砂災害」のレベル3警報が3つ同時に出ている
/// ③ 「大雪警報」または「暴風雪警報」が出ている
/// → 生徒は自宅で待機（休校・日程変更は「すぐーる」「クラスルーム」で連絡）
///
/// これはあくまで目安で、最後は学校からの連絡で決まる。
library;

import 'jma_warnings.dart';
import 'weather_models.dart';

/// 判定のために使う、1つの危険とそのレベル
typedef HazardLevel = ({Hazard? hazard, int level, String name});

/// きまりに当てはまるか
class RuleCheck {
  const RuleCheck(this.reasons);

  /// 当てはまったきまり（空なら当てはまらない）
  final List<String> reasons;

  bool get stayHome => reasons.isNotEmpty;
}

bool _leveled(Hazard? h) =>
    h == Hazard.heavyRain ||
    h == Hazard.landslide ||
    h == Hazard.flood ||
    h == Hazard.stormSurge;

/// 学校のきまり①②③に当てはめる
RuleCheck checkSchoolRules(List<HazardLevel> items) {
  final reasons = <String>[];

  // ① レベル4以上（特別警報もふくむ）
  final l4 = [
    for (final x in items)
      if (x.level >= 5 || (x.level >= 4 && _leveled(x.hazard))) x.name,
  ];
  if (l4.isNotEmpty) {
    reasons.add('① レベル4以上の警報（${l4.join('・')}）');
  }

  // ② 大雨・河川氾濫・土砂災害のレベル3以上が3つそろう
  int levelOf(Hazard h) => items
      .where((x) => x.hazard == h)
      .fold(0, (m, x) => x.level > m ? x.level : m);
  if (levelOf(Hazard.heavyRain) >= 3 &&
      levelOf(Hazard.flood) >= 3 &&
      levelOf(Hazard.landslide) >= 3) {
    reasons.add('② 大雨・河川氾濫・土砂災害のレベル3警報が3つ同時');
  }

  // ③ 大雪警報・暴風雪警報
  final snow = [
    for (final x in items)
      if ((x.hazard == Hazard.snow || x.hazard == Hazard.blizzard) &&
          x.level >= 3)
        x.name,
  ];
  if (snow.isNotEmpty) reasons.add('③ ${snow.join('・')}');

  return RuleCheck(reasons);
}

List<HazardLevel> levelsOf(List<ActiveWarning> ws) => [
  for (final w in ws) (hazard: w.hazard, level: w.level, name: w.name),
];

/// 自宅待機の見込み
enum ClosureRisk {
  none('心配なし'),
  low('低い'),
  medium('ありうる'),
  high('高い'),
  now('いま条件にあてはまっています');

  const ClosureRisk(this.label);
  final String label;
}

class ClosurePrediction {
  const ClosurePrediction({
    required this.target,
    required this.risk,
    required this.reasons,
    required this.notes,
    required this.isToday,
  });

  /// 判定の時刻（その登校日の午前6時）
  final DateTime target;
  final ClosureRisk risk;

  /// きまりに当てはまる理由
  final List<String> reasons;

  /// 参考になること（予報・台風など）
  final List<String> notes;

  /// 今日の朝の判定か
  final bool isToday;
}

/// 次に判定される朝6時（今日が登校日で、まだ8時前なら今日）
DateTime nextJudgeTime(DateTime now, bool Function(DateTime day) isSchoolDay) {
  final today = DateTime(now.year, now.month, now.day);
  if (isSchoolDay(today) && now.hour < 8) {
    return DateTime(today.year, today.month, today.day, 6);
  }
  for (var i = 1; i <= 14; i++) {
    final d = DateTime(today.year, today.month, today.day + i);
    if (isSchoolDay(d)) return DateTime(d.year, d.month, d.day, 6);
  }
  return DateTime(today.year, today.month, today.day + 1, 6);
}

/// 自宅待機になりそうかを予測する
///
/// - いま出ている警報の「これからの見通し（〇時から〇時まで、警戒レベル4相当）」が朝6時にかかるか
/// - 朝6時まで6時間以内なら、いまの警報がそのまま続くとみなす
/// - 天気予報（1時間の雨量・風速・雪）と台風は参考にする
ClosurePrediction predictClosure({
  required DateTime now,
  required DateTime target,
  required AreaWarnings warnings,
  WeatherForecast? forecast,
  List<String> typhoons = const [],
}) {
  final hoursLeft = target.difference(now).inMinutes / 60;
  final t = target.toLocal(), n = now.toLocal();
  final isToday = t.year == n.year && t.month == n.month && t.day == n.day;

  // いまの警報で判定
  final nowCheck = checkSchoolRules(levelsOf(warnings.warnings));

  // 朝6時に見込まれるレベル
  final expected = <HazardLevel>[];
  for (final w in warnings.warnings) {
    if (hoursLeft <= 6) {
      expected.add((hazard: w.hazard, level: w.level, name: w.name));
    }
    for (final p in w.periods) {
      if (p.covers(target) && p.level != null) {
        expected.add((
          hazard: w.hazard,
          level: p.level!,
          name: '${w.hazard?.label ?? w.name} 警戒レベル${p.level}相当',
        ));
      }
    }
  }
  final expectedCheck = checkSchoolRules(expected);

  // 参考：予報
  final notes = <String>[];
  var forecastSevere = false;
  var forecastRough = false;
  final slot = forecast?.hourAt(target);
  if (slot != null) {
    final rain = slot.precipitation ?? 0;
    final wind = slot.windSpeed ?? 0;
    if (rain >= 30) {
      forecastSevere = true;
      notes.add('予報では朝6時ごろ 1時間に${rain.toStringAsFixed(0)}mm の激しい雨');
    } else if (rain >= 10) {
      forecastRough = true;
      notes.add('予報では朝6時ごろ 1時間に${rain.toStringAsFixed(0)}mm の強い雨');
    }
    if (wind >= 20) {
      forecastSevere = true;
      notes.add('予報では朝6時ごろ 風速${wind.toStringAsFixed(0)}m/s の猛烈な風');
    } else if (wind >= 12) {
      forecastRough = true;
      notes.add('予報では朝6時ごろ 風速${wind.toStringAsFixed(0)}m/s の強い風');
    }
    if (slot.code == 75 || slot.code == 86) {
      forecastSevere = true;
      notes.add('予報では朝6時ごろ 大雪');
    }
  }
  for (final t in typhoons) {
    notes.add('${typhoonLabel(t)}が発生しています');
  }

  // 大雨・河川氾濫・土砂災害のレベル3が2つ以上
  final threeCount = [Hazard.heavyRain, Hazard.flood, Hazard.landslide]
      .where((h) => warnings.warnings.any((w) => w.hazard == h && w.level >= 3))
      .length;

  final ClosureRisk risk;
  final List<String> reasons;
  if (isToday && n.hour >= 6 && nowCheck.stayHome) {
    risk = ClosureRisk.now;
    reasons = nowCheck.reasons;
  } else if (expectedCheck.stayHome) {
    risk = ClosureRisk.high;
    reasons = expectedCheck.reasons;
  } else if (nowCheck.stayHome) {
    // いまは当てはまるが、朝6時まで時間がある
    risk = hoursLeft <= 12 ? ClosureRisk.high : ClosureRisk.medium;
    reasons = [for (final r in nowCheck.reasons) 'いま $r'];
  } else if (forecastSevere || threeCount >= 2) {
    risk = ClosureRisk.medium;
    reasons = [if (threeCount >= 2) '大雨・河川氾濫・土砂災害のうち${threeCount}つにレベル3以上の警報'];
  } else if (forecastRough ||
      typhoons.isNotEmpty ||
      warnings.warnings.any((w) => w.level >= 3)) {
    risk = ClosureRisk.low;
    reasons = [
      for (final w in warnings.warnings)
        if (w.level >= 3) 'いま ${w.name}',
    ];
  } else {
    risk = ClosureRisk.none;
    reasons = const [];
  }

  return ClosurePrediction(
    target: target,
    risk: risk,
    reasons: reasons,
    notes: notes,
    isToday: isToday,
  );
}
