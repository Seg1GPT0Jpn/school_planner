/// 天気予報のデータ（Open-Meteo の JSON を読む）
///
/// Open-Meteo は無料・キー不要の天気 API。日本の予報には気象庁のモデルも使われる。
/// 画面に依存しない読み取りだけなので、テストしやすい。
library;

/// 学校（藤沢市）の場所
const double schoolLatitude = 35.3389;
const double schoolLongitude = 139.4900;
const String schoolPlaceName = '藤沢市';

/// 天気の種類（WMO の天気コード）を、日本語とマークにする
({String label, String icon}) weatherOf(int? code, {bool night = false}) =>
    switch (code) {
      0 => (label: '快晴', icon: night ? '🌙' : '☀️'),
      1 => (label: '晴れ', icon: night ? '🌙' : '🌤️'),
      2 => (label: '晴れ時々くもり', icon: '⛅'),
      3 => (label: 'くもり', icon: '☁️'),
      45 || 48 => (label: '霧', icon: '🌫️'),
      51 || 53 || 55 => (label: '霧雨', icon: '🌦️'),
      56 || 57 => (label: '着氷性の霧雨', icon: '🌧️'),
      61 => (label: '小雨', icon: '🌦️'),
      63 => (label: '雨', icon: '🌧️'),
      65 => (label: '強い雨', icon: '🌧️'),
      66 || 67 => (label: '着氷性の雨', icon: '🌧️'),
      71 => (label: '小雪', icon: '🌨️'),
      73 => (label: '雪', icon: '🌨️'),
      75 => (label: '大雪', icon: '❄️'),
      77 => (label: '霧雪', icon: '🌨️'),
      80 => (label: 'にわか雨', icon: '🌦️'),
      81 => (label: '強いにわか雨', icon: '🌧️'),
      82 => (label: '激しいにわか雨', icon: '⛈️'),
      85 || 86 => (label: 'にわか雪', icon: '🌨️'),
      95 => (label: '雷雨', icon: '⛈️'),
      96 || 99 => (label: 'ひょうを伴う雷雨', icon: '⛈️'),
      _ => (label: '—', icon: '❔'),
    };

/// 雨・雪などの「ぬれる」天気か（WMOコードが51以上）
bool isWetWeather(int? code) => code != null && code >= 51;

const _dirs = [
  '北',
  '北北東',
  '北東',
  '東北東',
  '東',
  '東南東',
  '南東',
  '南南東',
  '南',
  '南南西',
  '南西',
  '西南西',
  '西',
  '西北西',
  '北西',
  '北北西',
];

/// 風向き（度）を「北北東」のような16方位にする。風が吹いてくる方向。
String windDirectionText(num? degree) {
  if (degree == null) return '—';
  final i = (((degree % 360) + 360) % 360 / 22.5 + 0.5).floor() % 16;
  return _dirs[i];
}

/// 風の強さのめやす（m/s）
String windStrengthText(num? speed) {
  if (speed == null) return '';
  if (speed < 3) return 'おだやか';
  if (speed < 6) return 'やや強い';
  if (speed < 10) return '強い';
  if (speed < 15) return 'かなり強い（傘がさしにくい）';
  if (speed < 20) return '非常に強い（歩きにくい）';
  return '猛烈（外に出るのは危険）';
}

DateTime? _time(Object? v) => v is String ? DateTime.tryParse(v) : null;
double? _d(Object? v) => v is num ? v.toDouble() : null;
int? _i(Object? v) => v is num ? v.toInt() : null;

List<T?> _list<T>(Map<String, dynamic>? m, String key, T? Function(Object?) f) {
  final v = m?[key];
  if (v is! List) return const [];
  return [for (final x in v) f(x)];
}

/// いまの天気
class CurrentWeather {
  const CurrentWeather({
    required this.time,
    this.temperature,
    this.apparent,
    this.humidity,
    this.pressure,
    this.windSpeed,
    this.windDirection,
    this.precipitation,
    this.code,
    this.isDay = true,
    this.uvIndex,
    this.usAqi,
    this.europeanAqi,
    this.pm25,
    this.pm10,
  });

  final DateTime time;
  final double? temperature;

  /// 体感温度
  final double? apparent;

  /// 湿度（%）
  final double? humidity;

  /// 気圧（hPa、地上）
  final double? pressure;

  /// 風速（m/s）
  final double? windSpeed;

  /// 風向き（度）
  final double? windDirection;

  /// いまの降水量（mm）
  final double? precipitation;
  final int? code;
  final bool isDay;

  /// UV指数
  final double? uvIndex;

  /// 大気質指数（アメリカ基準、0〜500）
  final int? usAqi;

  /// 大気質指数（ヨーロッパ基準、0〜100超）
  final int? europeanAqi;

  /// 微小粒子状物質 PM2.5（µg/m³）
  final double? pm25;

  /// 浮遊粒子状物質 PM10（µg/m³）
  final double? pm10;

  CurrentWeather copyWith({
    int? usAqi,
    int? europeanAqi,
    double? pm25,
    double? pm10,
  }) => CurrentWeather(
    time: time,
    temperature: temperature,
    apparent: apparent,
    humidity: humidity,
    pressure: pressure,
    windSpeed: windSpeed,
    windDirection: windDirection,
    precipitation: precipitation,
    code: code,
    isDay: isDay,
    uvIndex: uvIndex,
    usAqi: usAqi ?? this.usAqi,
    europeanAqi: europeanAqi ?? this.europeanAqi,
    pm25: pm25 ?? this.pm25,
    pm10: pm10 ?? this.pm10,
  );
}

/// 大気質指数（アメリカ基準）のめやす
({String label, String description}) usAqiOf(int? aqi) => switch (aqi) {
  null => (label: '—', description: ''),
  <= 50 => (label: '良好', description: '空気の質は満足できる状態です'),
  <= 100 => (label: 'まあまあ', description: '敏感な人は影響を受ける可能性があります'),
  <= 150 => (label: '敏感な人に注意', description: '呼吸器疾患のある人などは長時間の屋外活動を控えめに'),
  <= 200 => (label: '健康に良くない', description: '誰でも影響を受け始める可能性があります'),
  <= 300 => (label: 'とても健康に良くない', description: '屋外での激しい運動は避けましょう'),
  _ => (label: '危険', description: '外出はできるだけ控えましょう'),
};

/// 1時間ごと（または15分ごと）の1つ
class WeatherSlot {
  const WeatherSlot({
    required this.time,
    this.temperature,
    this.apparent,
    this.precipitation,
    this.precipitationProbability,
    this.code,
    this.windSpeed,
    this.windDirection,
    this.humidity,
    this.pressure,
    this.uvIndex,
    this.usAqi,
    this.europeanAqi,
    this.pm25,
    this.pm10,
  });

  final DateTime time;
  final double? temperature;
  final double? apparent;
  final double? precipitation;
  final int? precipitationProbability;
  final int? code;
  final double? windSpeed;
  final double? windDirection;
  final double? humidity;
  final double? pressure;

  /// UV指数
  final double? uvIndex;

  /// 大気質指数（アメリカ基準）
  final int? usAqi;

  /// 大気質指数（ヨーロッパ基準）
  final int? europeanAqi;
  final double? pm25;
  final double? pm10;

  WeatherSlot copyWith({
    int? usAqi,
    int? europeanAqi,
    double? pm25,
    double? pm10,
  }) => WeatherSlot(
    time: time,
    temperature: temperature,
    apparent: apparent,
    precipitation: precipitation,
    precipitationProbability: precipitationProbability,
    code: code,
    windSpeed: windSpeed,
    windDirection: windDirection,
    humidity: humidity,
    pressure: pressure,
    uvIndex: uvIndex,
    usAqi: usAqi ?? this.usAqi,
    europeanAqi: europeanAqi ?? this.europeanAqi,
    pm25: pm25 ?? this.pm25,
    pm10: pm10 ?? this.pm10,
  );
}

/// 1日ぶん
class DailyWeather {
  const DailyWeather({
    required this.date,
    this.code,
    this.max,
    this.min,
    this.sunrise,
    this.sunset,
    this.precipitationSum,
    this.precipitationProbability,
    this.windSpeedMax,
    this.windDirection,
    this.uvIndexMax,
  });

  final DateTime date;
  final int? code;
  final double? max;
  final double? min;
  final DateTime? sunrise;
  final DateTime? sunset;

  /// 1日の総雨量（mm）
  final double? precipitationSum;
  final int? precipitationProbability;
  final double? windSpeedMax;
  final double? windDirection;

  /// その日の最大UV指数
  final double? uvIndexMax;
}

/// UV指数のめやす
({String label, String advice}) uvIndexOf(double? uv) => switch (uv) {
  null => (label: '—', advice: ''),
  <= 2 => (label: '弱い', advice: '対策は特に不要です'),
  <= 5 => (label: '中程度', advice: '日中はできるだけ日陰を利用しましょう'),
  <= 7 => (label: '強い', advice: '日焼け止め・帽子などの対策を'),
  <= 10 => (label: '非常に強い', advice: '日中の外出はできるだけ避け、しっかり対策を'),
  _ => (label: '極端に強い', advice: '日中の外出はなるべく避けましょう'),
};

/// 天気予報ぜんぶ
class WeatherForecast {
  const WeatherForecast({
    required this.fetchedAt,
    this.current,
    this.minutely = const [],
    this.hourly = const [],
    this.daily = const [],
  });

  final DateTime fetchedAt;
  final CurrentWeather? current;

  /// 15分ごとの降水量
  final List<WeatherSlot> minutely;
  final List<WeatherSlot> hourly;
  final List<DailyWeather> daily;

  /// now から hours 時間の15分ごとの降水量（今後の降水量グラフ）
  List<WeatherSlot> precipitationNext(DateTime now, {int hours = 6}) {
    final from = now.subtract(const Duration(minutes: 15));
    final to = now.add(Duration(hours: hours));
    return [
      for (final s in minutely)
        if (s.time.isAfter(from) && !s.time.isAfter(to)) s,
    ];
  }

  /// now から hours 時間の1時間ごとの予報
  List<WeatherSlot> hourlyNext(DateTime now, {int hours = 24}) {
    final from = DateTime(now.year, now.month, now.day, now.hour);
    final to = from.add(Duration(hours: hours));
    return [
      for (final s in hourly)
        if (!s.time.isBefore(from) && s.time.isBefore(to)) s,
    ];
  }

  /// その時刻の1時間ごとの予報（ちょうどがなければいちばん近いもの）
  WeatherSlot? hourAt(DateTime t) {
    WeatherSlot? best;
    Duration? gap;
    for (final s in hourly) {
      final g = s.time.difference(t).abs();
      if (gap == null || g < gap) {
        gap = g;
        best = s;
      }
    }
    return gap != null && gap <= const Duration(hours: 1) ? best : null;
  }

  DailyWeather? dayOf(DateTime d) {
    for (final x in daily) {
      if (x.date.year == d.year &&
          x.date.month == d.month &&
          x.date.day == d.day) {
        return x;
      }
    }
    return null;
  }

  /// 大気質（PM2.5・PM10・AQI）を、時刻を合わせてマージしたものを返す
  WeatherForecast mergeAirQuality(AirQuality aq) {
    ({int? usAqi, int? europeanAqi, double? pm25, double? pm10})? at(
      DateTime t,
    ) {
      AirQualitySlot? best;
      Duration? gap;
      for (final s in aq.hourly) {
        final g = s.time.difference(t).abs();
        if (gap == null || g < gap) {
          gap = g;
          best = s;
        }
      }
      if (best == null || gap! > const Duration(hours: 1)) return null;
      return (
        usAqi: best.usAqi,
        europeanAqi: best.europeanAqi,
        pm25: best.pm25,
        pm10: best.pm10,
      );
    }

    return WeatherForecast(
      fetchedAt: fetchedAt,
      current: current == null
          ? null
          : () {
              final m = at(current!.time);
              return m == null
                  ? current
                  : current!.copyWith(
                      usAqi: m.usAqi,
                      europeanAqi: m.europeanAqi,
                      pm25: m.pm25,
                      pm10: m.pm10,
                    );
            }(),
      minutely: minutely,
      hourly: [
        for (final s in hourly)
          () {
            final m = at(s.time);
            return m == null
                ? s
                : s.copyWith(
                    usAqi: m.usAqi,
                    europeanAqi: m.europeanAqi,
                    pm25: m.pm25,
                    pm10: m.pm10,
                  );
          }(),
      ],
      daily: daily,
    );
  }
}

/// 大気質の1時間ぶん
class AirQualitySlot {
  const AirQualitySlot({
    required this.time,
    this.usAqi,
    this.europeanAqi,
    this.pm25,
    this.pm10,
  });

  final DateTime time;
  final int? usAqi;
  final int? europeanAqi;
  final double? pm25;
  final double? pm10;
}

/// 大気質（Open-Meteo の大気質 API の結果）
class AirQuality {
  const AirQuality({this.hourly = const []});

  final List<AirQualitySlot> hourly;
}

/// Open-Meteo の大気質 API の JSON を読む
AirQuality parseOpenMeteoAirQuality(Map<String, dynamic> json) {
  final h = json['hourly'] as Map<String, dynamic>?;
  final hTime = _list(h, 'time', _time);
  final hUs = _list(h, 'us_aqi', _i);
  final hEu = _list(h, 'european_aqi', _i);
  final hPm25 = _list(h, 'pm2_5', _d);
  final hPm10 = _list(h, 'pm10', _d);

  T? at<T>(List<T?> l, int i) => i < l.length ? l[i] : null;

  return AirQuality(
    hourly: [
      for (var i = 0; i < hTime.length; i++)
        if (hTime[i] != null)
          AirQualitySlot(
            time: hTime[i]!,
            usAqi: at(hUs, i),
            europeanAqi: at(hEu, i),
            pm25: at(hPm25, i),
            pm10: at(hPm10, i),
          ),
    ],
  );
}

/// Open-Meteo の大気質 API に聞く URL
Uri openMeteoAirQualityUri({
  double latitude = schoolLatitude,
  double longitude = schoolLongitude,
  String timeZone = 'Asia/Tokyo',
}) => Uri.https('air-quality-api.open-meteo.com', '/v1/air-quality', {
  'latitude': '$latitude',
  'longitude': '$longitude',
  'timezone': timeZone,
  'forecast_days': '3',
  'hourly': ['pm10', 'pm2_5', 'us_aqi', 'european_aqi'].join(','),
});

/// Open-Meteo の JSON を読む
WeatherForecast parseOpenMeteo(
  Map<String, dynamic> json, {
  DateTime? fetchedAt,
}) {
  final c = json['current'] as Map<String, dynamic>?;
  final m = json['minutely_15'] as Map<String, dynamic>?;
  final h = json['hourly'] as Map<String, dynamic>?;
  final d = json['daily'] as Map<String, dynamic>?;

  final mTime = _list(m, 'time', _time);
  final mPrec = _list(m, 'precipitation', _d);

  final hTime = _list(h, 'time', _time);
  final hTemp = _list(h, 'temperature_2m', _d);
  final hApp = _list(h, 'apparent_temperature', _d);
  final hPrec = _list(h, 'precipitation', _d);
  final hPop = _list(h, 'precipitation_probability', _i);
  final hCode = _list(h, 'weather_code', _i);
  final hWs = _list(h, 'wind_speed_10m', _d);
  final hWd = _list(h, 'wind_direction_10m', _d);
  final hHum = _list(h, 'relative_humidity_2m', _d);
  final hPres = _list(h, 'surface_pressure', _d);
  final hUv = _list(h, 'uv_index', _d);

  final dTime = _list(d, 'time', _time);
  final dCode = _list(d, 'weather_code', _i);
  final dMax = _list(d, 'temperature_2m_max', _d);
  final dMin = _list(d, 'temperature_2m_min', _d);
  final dRise = _list(d, 'sunrise', _time);
  final dSet = _list(d, 'sunset', _time);
  final dSum = _list(d, 'precipitation_sum', _d);
  final dPop = _list(d, 'precipitation_probability_max', _i);
  final dWs = _list(d, 'wind_speed_10m_max', _d);
  final dWd = _list(d, 'wind_direction_10m_dominant', _d);
  final dUv = _list(d, 'uv_index_max', _d);

  T? at<T>(List<T?> l, int i) => i < l.length ? l[i] : null;

  return WeatherForecast(
    fetchedAt: fetchedAt ?? DateTime.now(),
    current: c == null || _time(c['time']) == null
        ? null
        : CurrentWeather(
            time: _time(c['time'])!,
            temperature: _d(c['temperature_2m']),
            apparent: _d(c['apparent_temperature']),
            humidity: _d(c['relative_humidity_2m']),
            pressure: _d(c['surface_pressure']),
            windSpeed: _d(c['wind_speed_10m']),
            windDirection: _d(c['wind_direction_10m']),
            precipitation: _d(c['precipitation']),
            code: _i(c['weather_code']),
            isDay: _i(c['is_day']) != 0,
            uvIndex: _d(c['uv_index']),
          ),
    minutely: [
      for (var i = 0; i < mTime.length; i++)
        if (mTime[i] != null)
          WeatherSlot(time: mTime[i]!, precipitation: at(mPrec, i)),
    ],
    hourly: [
      for (var i = 0; i < hTime.length; i++)
        if (hTime[i] != null)
          WeatherSlot(
            time: hTime[i]!,
            temperature: at(hTemp, i),
            apparent: at(hApp, i),
            precipitation: at(hPrec, i),
            precipitationProbability: at(hPop, i),
            code: at(hCode, i),
            windSpeed: at(hWs, i),
            windDirection: at(hWd, i),
            humidity: at(hHum, i),
            pressure: at(hPres, i),
            uvIndex: at(hUv, i),
          ),
    ],
    daily: [
      for (var i = 0; i < dTime.length; i++)
        if (dTime[i] != null)
          DailyWeather(
            date: dTime[i]!,
            code: at(dCode, i),
            max: at(dMax, i),
            min: at(dMin, i),
            sunrise: at(dRise, i),
            sunset: at(dSet, i),
            precipitationSum: at(dSum, i),
            precipitationProbability: at(dPop, i),
            windSpeedMax: at(dWs, i),
            windDirection: at(dWd, i),
            uvIndexMax: at(dUv, i),
          ),
    ],
  );
}

/// Open-Meteo に聞く URL（藤沢市・10日分・風は m/s）
Uri openMeteoUri({
  double latitude = schoolLatitude,
  double longitude = schoolLongitude,
  String timeZone = 'Asia/Tokyo',
}) => Uri.https('api.open-meteo.com', '/v1/forecast', {
  'latitude': '$latitude',
  'longitude': '$longitude',
  'timezone': timeZone,
  'forecast_days': '10',
  'wind_speed_unit': 'ms',
  'current': [
    'temperature_2m',
    'apparent_temperature',
    'relative_humidity_2m',
    'surface_pressure',
    'wind_speed_10m',
    'wind_direction_10m',
    'precipitation',
    'weather_code',
    'is_day',
    'uv_index',
  ].join(','),
  'minutely_15': 'precipitation',
  'forecast_minutely_15': '32',
  'hourly': [
    'temperature_2m',
    'apparent_temperature',
    'precipitation',
    'precipitation_probability',
    'weather_code',
    'wind_speed_10m',
    'wind_direction_10m',
    'relative_humidity_2m',
    'surface_pressure',
    'uv_index',
  ].join(','),
  'daily': [
    'weather_code',
    'temperature_2m_max',
    'temperature_2m_min',
    'sunrise',
    'sunset',
    'precipitation_sum',
    'precipitation_probability_max',
    'wind_speed_10m_max',
    'wind_direction_10m_dominant',
    'uv_index_max',
  ].join(','),
});
