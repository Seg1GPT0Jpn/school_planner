import 'package:flutter_test/flutter_test.dart';
import 'package:school_planner/features/weather/jma_warnings.dart';
import 'package:school_planner/features/weather/school_closure.dart';
import 'package:school_planner/features/weather/weather_models.dart';

/// 2026/9/21 16時ごろの、藤沢市の実際の r8 データ（一部）
final _r8 = [
  {
    'reportDatetime': '2026-09-21T15:21:00+09:00',
    'dataTypeCode': 'VPWW55',
    'headlineText': '神奈川県では、２２日未明まで土砂災害に警戒してください。',
    'warning': {
      'class20Items': [
        {
          'areaCode': '1420500',
          'kinds': [
            {
              'code': '43',
              'status': '継続',
              'properties': [
                {
                  'type': '大雨浸水危険度',
                  'significancyPart': {
                    'locals': [
                      {'code': '41'},
                    ],
                  },
                },
              ],
            },
          ],
        },
        {
          // ほかの市（読まない）
          'areaCode': '1410000',
          'kinds': [
            {'code': '33', 'status': '発表'},
          ],
        },
      ],
    },
  },
  {
    'reportDatetime': '2026-09-21T14:23:00+09:00',
    'dataTypeCode': 'VPWW56',
    'warning': {
      'class20Items': [
        {
          'areaCode': '1420500',
          'kinds': [
            {
              'code': '49',
              'status': '継続',
              'properties': [
                {
                  'type': '土砂災害危険度',
                  'criteriaPeriod': {
                    'locals': [
                      {
                        'sentence': '２１日１４時から２２日０時まで、警戒レベル４相当',
                        'code': '41',
                        'time': '2026-09-21T14:00:00+09:00',
                        'duration': 'PT10H',
                      },
                    ],
                  },
                },
              ],
            },
          ],
        },
      ],
    },
  },
  {
    'reportDatetime': '2026-09-21T16:04:00+09:00',
    'dataTypeCode': 'VPWW58',
    'warning': {
      'class20Items': [
        {
          'areaCode': '1420500',
          'kinds': [
            {'code': '05', 'status': '発表'},
            {'code': '15', 'status': '解除'},
          ],
        },
      ],
    },
  },
  {
    'reportDatetime': '2026-09-21T01:01:00+09:00',
    'dataTypeCode': 'VPWW61',
    'warning': {
      'class20Items': [
        {
          'areaCode': '1420500',
          'kinds': [
            {
              'code': '14',
              'status': '継続',
              'additions': ['竜巻'],
            },
          ],
        },
      ],
    },
  },
];

AreaWarnings _warnings(List<String> codes) => AreaWarnings(
  reportTime: null,
  warnings: [
    for (final c in codes)
      ActiveWarning(
        code: c,
        name: warningName(warningCodes[c]!.hazard, warningCodes[c]!.level),
        hazard: warningCodes[c]!.hazard,
        level: warningCodes[c]!.level,
        status: '発表',
      ),
  ],
);

RuleCheck _check(List<String> codes) =>
    checkSchoolRules(levelsOf(_warnings(codes).warnings));

bool _weekday(DateTime d) => d.weekday <= DateTime.friday;

void main() {
  // ───────────── 気象庁の警報を読む ─────────────
  group('警報（r8）', () {
    final w = parseAreaWarnings(_r8);

    test('藤沢市の、出ている警報・注意報だけを読む', () {
      expect(w.warnings.map((x) => x.code).toSet(), {'43', '49', '05', '14'});
      expect(w.maxLevel, 4);
      expect(w.reportTime, DateTime.parse('2026-09-21T16:04:00+09:00'));
      expect(w.headline, contains('土砂災害に警戒'));
    });

    test('名前とレベル', () {
      final byCode = {for (final x in w.warnings) x.code: x};
      expect(byCode['43']!.name, 'レベル4大雨危険警報');
      expect(byCode['49']!.name, 'レベル4土砂災害危険警報');
      expect(byCode['05']!.name, '暴風警報');
      expect(byCode['05']!.level, 3);
      expect(byCode['14']!.name, '雷注意報');
      expect(byCode['14']!.additions, ['竜巻']);
      expect(w.sorted.first.level, 4);
    });

    test('これからの見通し（時間帯と警戒レベル）', () {
      final p = w.warnings.firstWhere((x) => x.code == '49').periods.single;
      expect(p.level, 4);
      expect(p.start, DateTime.parse('2026-09-21T14:00:00+09:00'));
      expect(p.end, DateTime.parse('2026-09-22T00:00:00+09:00'));
      expect(p.covers(DateTime.parse('2026-09-21T20:00:00+09:00')), isTrue);
      expect(p.covers(DateTime.parse('2026-09-22T06:00:00+09:00')), isFalse);
    });

    test('名前のつけかた', () {
      expect(warningName(Hazard.flood, 3), 'レベル3氾濫警報');
      expect(warningName(Hazard.heavyRain, 5), 'レベル5大雨特別警報');
      expect(warningName(Hazard.snow, 3), '大雪警報');
      expect(warningName(Hazard.blizzard, 2), '暴風雪注意報');
    });

    test('台風', () {
      final t = parseTyphoons([
        {
          'tropicalCyclone': 'TC2630',
          'typhoonNumber': '2625',
          'category': 'TY',
        },
      ]);
      expect(t, ['2625']);
      expect(typhoonLabel('2625'), '台風25号');
      expect(parseTyphoons(null), isEmpty);
    });

    test('こわれたデータでも落ちない', () {
      expect(parseAreaWarnings(null).warnings, isEmpty);
      expect(parseAreaWarnings({'x': 1}).warnings, isEmpty);
    });
  });

  // ───────────── 学校のきまり ─────────────
  group('学校のきまり', () {
    test('① レベル4以上', () {
      expect(_check(['43']).stayHome, isTrue);
      expect(_check(['49']).reasons.single, startsWith('①'));
      expect(_check(['35']).stayHome, isTrue); // 暴風特別警報
    });

    test('② 大雨・河川氾濫・土砂災害のレベル3が3つそろう', () {
      expect(_check(['03', '04', '09']).reasons.single, startsWith('②'));
      expect(_check(['03', '09']).stayHome, isFalse);
    });

    test('③ 大雪警報・暴風雪警報', () {
      expect(_check(['06']).reasons.single, startsWith('③'));
      expect(_check(['02']).stayHome, isTrue);
      expect(_check(['12']).stayHome, isFalse); // 大雪注意報
    });

    test('暴風警報だけでは自宅待機にならない', () {
      expect(_check(['05', '15', '07']).stayHome, isFalse);
    });
  });

  // ───────────── 予測 ─────────────
  group('自宅待機の予測', () {
    test('次に判定される朝6時', () {
      // 月曜5時 → 今日の6時
      expect(
        nextJudgeTime(DateTime(2026, 9, 21, 5), _weekday),
        DateTime(2026, 9, 21, 6),
      );
      // 月曜9時 → 火曜の6時
      expect(
        nextJudgeTime(DateTime(2026, 9, 21, 9), _weekday),
        DateTime(2026, 9, 22, 6),
      );
      // 金曜10時 → 月曜の6時
      expect(
        nextJudgeTime(DateTime(2026, 9, 25, 10), _weekday),
        DateTime(2026, 9, 28, 6),
      );
    });

    // 端末の時間帯によらないよう、ここではふつうの（その場所の）時刻で書く
    final target = DateTime(2026, 9, 22, 6);

    test('いまレベル4、朝まで10時間 → 高い', () {
      final p = predictClosure(
        now: DateTime(2026, 9, 21, 20),
        target: target,
        warnings: _warnings(['49']),
      );
      expect(p.risk, ClosureRisk.high);
      expect(p.reasons.single, startsWith('いま ①'));
    });

    test('見通しの時間帯が朝6時にかかる → 高い', () {
      final w = AreaWarnings(
        reportTime: null,
        warnings: [
          ActiveWarning(
            code: '09',
            name: 'レベル3土砂災害警報',
            hazard: Hazard.landslide,
            level: 3,
            status: '発表',
            periods: [
              WarningPeriod(
                start: DateTime(2026, 9, 22, 3),
                end: DateTime(2026, 9, 22, 9),
                sentence: '２２日３時から９時まで、警戒レベル４相当',
                level: 4,
              ),
            ],
          ),
        ],
      );
      final p = predictClosure(
        now: DateTime(2026, 9, 21, 18),
        target: target,
        warnings: w,
      );
      expect(p.risk, ClosureRisk.high);
      expect(p.reasons.single, contains('警戒レベル4相当'));
    });

    test('朝7時で条件にあてはまる → いまあてはまる', () {
      final p = predictClosure(
        now: DateTime(2026, 9, 22, 7),
        target: DateTime(2026, 9, 22, 6),
        warnings: _warnings(['43']),
      );
      expect(p.isToday, isTrue);
      expect(p.risk, ClosureRisk.now);
    });

    test('予報と台風は参考', () {
      WeatherForecast rain(double mm) => WeatherForecast(
        fetchedAt: DateTime(2026, 9, 21),
        hourly: [WeatherSlot(time: target, precipitation: mm)],
      );
      final now = DateTime(2026, 9, 21, 20);
      final none = _warnings([]);

      expect(
        predictClosure(
          now: now,
          target: target,
          warnings: none,
          forecast: rain(35),
        ).risk,
        ClosureRisk.medium,
      );
      expect(
        predictClosure(
          now: now,
          target: target,
          warnings: none,
          forecast: rain(12),
        ).risk,
        ClosureRisk.low,
      );
      expect(
        predictClosure(
          now: now,
          target: target,
          warnings: none,
          typhoons: ['2625'],
        ).risk,
        ClosureRisk.low,
      );
      expect(
        predictClosure(
          now: now,
          target: target,
          warnings: none,
          forecast: rain(0),
        ).risk,
        ClosureRisk.none,
      );
    });

    test('大雨・河川氾濫・土砂災害のレベル3が2つ → ありうる', () {
      final p = predictClosure(
        now: DateTime(2026, 9, 21, 20),
        target: target,
        warnings: _warnings(['03', '09']),
      );
      expect(p.risk, ClosureRisk.medium);
    });
  });

  // ───────────── 天気予報を読む ─────────────
  group('天気予報（Open-Meteo）', () {
    final f = parseOpenMeteo({
      'current': {
        'time': '2026-09-21T16:00',
        'temperature_2m': 24.3,
        'apparent_temperature': 26.1,
        'relative_humidity_2m': 88,
        'surface_pressure': 1003.2,
        'wind_speed_10m': 11.4,
        'wind_direction_10m': 200,
        'precipitation': 2.5,
        'weather_code': 63,
        'is_day': 1,
      },
      'minutely_15': {
        'time': ['2026-09-21T16:00', '2026-09-21T16:15', '2026-09-21T23:00'],
        'precipitation': [1.2, 0.8, 0.0],
      },
      'hourly': {
        'time': ['2026-09-21T16:00', '2026-09-21T17:00'],
        'temperature_2m': [24.3, 23.9],
        'precipitation_probability': [90, null],
        'weather_code': [63, 61],
      },
      'daily': {
        'time': ['2026-09-21', '2026-09-22'],
        'temperature_2m_max': [26.0, 28.5],
        'temperature_2m_min': [21.1, 20.4],
        'sunrise': ['2026-09-21T05:33', '2026-09-22T05:34'],
        'sunset': ['2026-09-21T17:41', '2026-09-22T17:40'],
        'precipitation_sum': [48.6, 0.2],
      },
    });

    test('いま', () {
      final c = f.current!;
      expect(c.temperature, 24.3);
      expect(c.apparent, 26.1);
      expect(c.humidity, 88);
      expect(c.pressure, 1003.2);
      expect(windDirectionText(c.windDirection), '南南西');
      expect(weatherOf(c.code).label, '雨');
    });

    test('今後の降水量・1時間ごと・毎日', () {
      final now = DateTime(2026, 9, 21, 16, 5);
      expect(f.precipitationNext(now).map((s) => s.precipitation), [1.2, 0.8]);
      expect(f.hourly.first.precipitationProbability, 90);
      expect(f.hourly.last.precipitationProbability, isNull);
      expect(f.hourlyNext(now).length, 2);
      expect(f.dayOf(now)!.max, 26.0);
      expect(f.dayOf(now)!.precipitationSum, 48.6);
      expect(f.dayOf(now)!.sunrise, DateTime(2026, 9, 21, 5, 33));
    });

    test('風向き・風の強さ', () {
      expect(windDirectionText(0), '北');
      expect(windDirectionText(90), '東');
      expect(windDirectionText(350), '北');
      expect(windStrengthText(2), 'おだやか');
      expect(windStrengthText(25), contains('猛烈'));
    });

    test('空のデータでも落ちない', () {
      final e = parseOpenMeteo({});
      expect(e.current, isNull);
      expect(e.hourly, isEmpty);
    });
  });
}
