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
}

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
}

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
}

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
  ].join(','),
});
