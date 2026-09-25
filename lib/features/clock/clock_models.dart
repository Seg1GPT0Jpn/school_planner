/// アラーム・タイマー・ストップウォッチ・お休み時間（Google の時計アプリ相当）のデータ
library;

import '../timetable/school_periods.dart' show ClockTime;

/// 曜日の1文字（1=月 〜 7=日）
String clockWeekdayLabel(int weekday) =>
    const ['月', '火', '水', '木', '金', '土', '日'][weekday - 1];

/// アラーム鳴動中の音量ボタンの動作
///
/// ※ 音量ボタンを横取りする権限は、ふつうのアプリ（Google の「時計」のような
/// システムアプリを除く）には基本的に与えられていない。ここでの動作は、
/// アラーム画面がいちばん手前に出ている（フォアグラウンドの）ときに、
/// アプリ内で押された音量ボタンを拾って再現する「できる範囲の近似」。
/// 画面ロック中などアプリの外で押された音量ボタンには反応できない。
enum AlarmVolumeButtonAction {
  adjustVolume('音量を調節する', 'ふつうの音量ボタンとして使う（既定の動作）'),
  snooze('スヌーズする', '音量ボタンを押すとスヌーズします'),
  stop('止める', '音量ボタンを押すと止めます'),
  doNothing('なにもしない', '音量ボタンを押しても何も起きません');

  const AlarmVolumeButtonAction(this.label, this.description);
  final String label;
  final String description;
}

/// アラームの種類
enum AlarmKind {
  normal('通常のアラーム'),
  wakeUp('起床時専用アラーム');

  const AlarmKind(this.label);
  final String label;
}

const List<int> snoozeMinuteChoices = [5, 10, 15, 20, 25, 30];
const List<int> dismissMinuteChoices = [5, 10, 15, 20, 25, 30];

/// アラーム1件
class Alarm {
  Alarm({
    this.id,
    required this.time,
    this.label = '',
    this.enabled = true,
    this.kind = AlarmKind.normal,
    Set<int>? weekdays,
    this.specificDate,
    this.soundPath,
    this.soundName,
    this.volume = 0.85,
    this.gradualVolume = true,
    this.snoozeMinutes = 5,
    this.dismissAfterMinutes = 15,
    this.volumeButtonAction = AlarmVolumeButtonAction.snooze,
    this.vibrate = true,
    this.includeWeather = false,
    this.bedtimeLinked = false,
  }) : weekdays = weekdays ?? {};

  /// Firestore の ID（まだ保存していなければ null）
  final String? id;

  final ClockTime time;

  /// アラームの名前（未設定なら「アラーム」として表示）
  final String label;
  final bool enabled;
  final AlarmKind kind;

  /// 繰り返す曜日（1=月〜7=日）。空なら「特定の日にち」か「次の1回だけ」
  final Set<int> weekdays;

  /// 特定の日にちだけ鳴らすとき（weekdays が空のときだけ使う）
  final DateTime? specificDate;

  /// カスタムの音（デバイスのファイルのパス）。null なら既定のアラーム音
  final String? soundPath;

  /// 選んだ音のファイル名（表示用）
  final String? soundName;

  /// 音量（0〜1）
  final double volume;

  /// 徐々に音量を上げるか
  final bool gradualVolume;

  /// スヌーズの長さ（分）
  final int snoozeMinutes;

  /// 消音（自動で止まる）までの時間（分）
  final int dismissAfterMinutes;

  /// 鳴動中の音量ボタンの動作
  final AlarmVolumeButtonAction volumeButtonAction;
  final bool vibrate;

  /// 天気予報をアラーム画面に含めるか
  final bool includeWeather;

  /// お休み時間機能の「起きる時間」から自動でつくられたアラームか
  /// （お休み時間のスケジュールを変えると、これも一緒に更新される）
  final bool bedtimeLinked;

  bool get repeats => weekdays.isNotEmpty;

  bool get isOneOff => weekdays.isEmpty && specificDate == null;

  String get displayLabel => label.trim().isEmpty
      ? (kind == AlarmKind.wakeUp ? '起床アラーム' : 'アラーム')
      : label.trim();

  /// 曜日を「月・火」のような文字にする（繰り返しなしなら空文字）
  String get weekdayText {
    if (weekdays.isEmpty) return '';
    final list = weekdays.toList()..sort();
    if (list.length == 5 && !list.contains(6) && !list.contains(7)) {
      return '平日';
    }
    if (list.length == 2 && list.contains(6) && list.contains(7)) {
      return '週末';
    }
    return list.map(clockWeekdayLabel).join('・');
  }

  /// 予定の説明（一覧に出す短い文）
  String get scheduleText {
    if (repeats) return '毎週 $weekdayText';
    if (specificDate != null) {
      return '${specificDate!.month}/${specificDate!.day}のみ';
    }
    return '次の1回のみ';
  }

  /// 次に鳴る日時（enabled が false なら null）
  DateTime? nextFire(DateTime from) {
    if (!enabled) return null;
    if (weekdays.isNotEmpty) {
      for (var i = 0; i < 8; i++) {
        final d = DateTime(
          from.year,
          from.month,
          from.day + i,
          time.hour,
          time.minute,
        );
        if (weekdays.contains(d.weekday) && d.isAfter(from)) return d;
      }
      return null;
    }
    if (specificDate != null) {
      final d = DateTime(
        specificDate!.year,
        specificDate!.month,
        specificDate!.day,
        time.hour,
        time.minute,
      );
      return d.isAfter(from) ? d : null;
    }
    final today = DateTime(from.year, from.month, from.day, time.hour, time.minute);
    return today.isAfter(from) ? today : today.add(const Duration(days: 1));
  }

  Alarm copyWith({
    ClockTime? time,
    String? label,
    bool? enabled,
    AlarmKind? kind,
    Set<int>? weekdays,
    DateTime? specificDate,
    bool clearSpecificDate = false,
    String? soundPath,
    String? soundName,
    bool clearSound = false,
    double? volume,
    bool? gradualVolume,
    int? snoozeMinutes,
    int? dismissAfterMinutes,
    AlarmVolumeButtonAction? volumeButtonAction,
    bool? vibrate,
    bool? includeWeather,
    bool? bedtimeLinked,
  }) => Alarm(
    id: id,
    time: time ?? this.time,
    label: label ?? this.label,
    enabled: enabled ?? this.enabled,
    kind: kind ?? this.kind,
    weekdays: weekdays ?? this.weekdays,
    specificDate: clearSpecificDate ? null : (specificDate ?? this.specificDate),
    soundPath: clearSound ? null : (soundPath ?? this.soundPath),
    soundName: clearSound ? null : (soundName ?? this.soundName),
    volume: volume ?? this.volume,
    gradualVolume: gradualVolume ?? this.gradualVolume,
    snoozeMinutes: snoozeMinutes ?? this.snoozeMinutes,
    dismissAfterMinutes: dismissAfterMinutes ?? this.dismissAfterMinutes,
    volumeButtonAction: volumeButtonAction ?? this.volumeButtonAction,
    vibrate: vibrate ?? this.vibrate,
    includeWeather: includeWeather ?? this.includeWeather,
    bedtimeLinked: bedtimeLinked ?? this.bedtimeLinked,
  );

  String? validate() {
    if (weekdays.isEmpty && specificDate == null) return null;
    return null;
  }
}

/// 鳴る時刻が近い順に並べる
List<Alarm> sortAlarms(List<Alarm> alarms, DateTime now) {
  final list = [...alarms];
  list.sort((a, b) {
    final fa = a.nextFire(now);
    final fb = b.nextFire(now);
    if (fa == null && fb == null) return a.time.compareTo(b.time);
    if (fa == null) return 1;
    if (fb == null) return -1;
    return fa.compareTo(fb);
  });
  return list;
}

/// タイマーのクイック選択（分）
const List<int> timerQuickPicks = [1, 5, 10, 15];

/// お休み時間のスケジュール
class BedtimeSchedule {
  const BedtimeSchedule({
    this.enabled = false,
    this.bedTime = const ClockTime(23, 0),
    this.wakeTime = const ClockTime(6, 30),
    Set<int>? days,
    this.sleepSoundPath,
    this.sleepSoundName,
    this.sleepSoundStartsMinutesBefore = 15,
  }) : days = days ?? const {1, 2, 3, 4, 5, 6, 7};

  final bool enabled;

  /// 寝る時刻
  final ClockTime bedTime;

  /// 起きる時刻（アラーム機能の「起床時専用アラーム」になる）
  final ClockTime wakeTime;

  /// このスケジュールを使う曜日
  final Set<int> days;

  /// お休み時間の何分前から安眠サウンドを流せるようにするか
  final int sleepSoundStartsMinutesBefore;
  final String? sleepSoundPath;
  final String? sleepSoundName;

  BedtimeSchedule copyWith({
    bool? enabled,
    ClockTime? bedTime,
    ClockTime? wakeTime,
    Set<int>? days,
    String? sleepSoundPath,
    String? sleepSoundName,
    bool clearSleepSound = false,
    int? sleepSoundStartsMinutesBefore,
  }) => BedtimeSchedule(
    enabled: enabled ?? this.enabled,
    bedTime: bedTime ?? this.bedTime,
    wakeTime: wakeTime ?? this.wakeTime,
    days: days ?? this.days,
    sleepSoundPath: clearSleepSound ? null : (sleepSoundPath ?? this.sleepSoundPath),
    sleepSoundName: clearSleepSound ? null : (sleepSoundName ?? this.sleepSoundName),
    sleepSoundStartsMinutesBefore:
        sleepSoundStartsMinutesBefore ?? this.sleepSoundStartsMinutesBefore,
  );

  /// 睡眠時間（分）。日をまたぐ場合も計算する
  int get sleepDurationMinutes {
    var m = wakeTime.totalMinutes - bedTime.totalMinutes;
    if (m <= 0) m += 24 * 60;
    return m;
  }

  String get sleepDurationText {
    final h = sleepDurationMinutes ~/ 60;
    final m = sleepDurationMinutes % 60;
    return m == 0 ? '$h時間' : '$h時間$m分';
  }
}

/// タイマー・ストップウォッチ・アラームの既定値（アプリ全体の好み）
class ClockSettings {
  const ClockSettings({
    this.timerSoundPath,
    this.timerSoundName,
    this.timerGradualVolume = false,
    this.timerVibrate = true,
    this.defaultAlarmSoundPath,
    this.defaultAlarmSoundName,
    this.bedtime = const BedtimeSchedule(),
  });

  final String? timerSoundPath;
  final String? timerSoundName;
  final bool timerGradualVolume;
  final bool timerVibrate;

  /// 新しいアラームを追加したときの既定の音
  final String? defaultAlarmSoundPath;
  final String? defaultAlarmSoundName;

  final BedtimeSchedule bedtime;

  ClockSettings copyWith({
    String? timerSoundPath,
    String? timerSoundName,
    bool clearTimerSound = false,
    bool? timerGradualVolume,
    bool? timerVibrate,
    String? defaultAlarmSoundPath,
    String? defaultAlarmSoundName,
    bool clearDefaultAlarmSound = false,
    BedtimeSchedule? bedtime,
  }) => ClockSettings(
    timerSoundPath: clearTimerSound ? null : (timerSoundPath ?? this.timerSoundPath),
    timerSoundName: clearTimerSound ? null : (timerSoundName ?? this.timerSoundName),
    timerGradualVolume: timerGradualVolume ?? this.timerGradualVolume,
    timerVibrate: timerVibrate ?? this.timerVibrate,
    defaultAlarmSoundPath: clearDefaultAlarmSound
        ? null
        : (defaultAlarmSoundPath ?? this.defaultAlarmSoundPath),
    defaultAlarmSoundName: clearDefaultAlarmSound
        ? null
        : (defaultAlarmSoundName ?? this.defaultAlarmSoundName),
    bedtime: bedtime ?? this.bedtime,
  );

  static Map<String, dynamic> _bedtimeToMap(BedtimeSchedule b) => {
    'enabled': b.enabled,
    'bedTime': '${b.bedTime.hour}:${b.bedTime.minute}',
    'wakeTime': '${b.wakeTime.hour}:${b.wakeTime.minute}',
    'days': b.days.toList()..sort(),
    'sleepSoundPath': b.sleepSoundPath,
    'sleepSoundName': b.sleepSoundName,
    'sleepSoundStartsMinutesBefore': b.sleepSoundStartsMinutesBefore,
  };

  static BedtimeSchedule _bedtimeFromMap(Object? v) {
    if (v is! Map) return const BedtimeSchedule();
    final m = Map<String, dynamic>.from(v);
    return BedtimeSchedule(
      enabled: m['enabled'] as bool? ?? false,
      bedTime: ClockTime.tryParse(m['bedTime']) ?? const ClockTime(23, 0),
      wakeTime: ClockTime.tryParse(m['wakeTime']) ?? const ClockTime(6, 30),
      days: {
        for (final d in (m['days'] as List<dynamic>? ?? const [1, 2, 3, 4, 5, 6, 7]))
          (d as num).toInt(),
      },
      sleepSoundPath: m['sleepSoundPath'] as String?,
      sleepSoundName: m['sleepSoundName'] as String?,
      sleepSoundStartsMinutesBefore:
          (m['sleepSoundStartsMinutesBefore'] as num?)?.toInt() ?? 15,
    );
  }

  Map<String, dynamic> toMap() => {
    'timerSoundPath': timerSoundPath,
    'timerSoundName': timerSoundName,
    'timerGradualVolume': timerGradualVolume,
    'timerVibrate': timerVibrate,
    'defaultAlarmSoundPath': defaultAlarmSoundPath,
    'defaultAlarmSoundName': defaultAlarmSoundName,
    'bedtime': _bedtimeToMap(bedtime),
  };

  factory ClockSettings.fromMap(Map<String, dynamic>? m) {
    if (m == null) return const ClockSettings();
    return ClockSettings(
      timerSoundPath: m['timerSoundPath'] as String?,
      timerSoundName: m['timerSoundName'] as String?,
      timerGradualVolume: m['timerGradualVolume'] as bool? ?? false,
      timerVibrate: m['timerVibrate'] as bool? ?? true,
      defaultAlarmSoundPath: m['defaultAlarmSoundPath'] as String?,
      defaultAlarmSoundName: m['defaultAlarmSoundName'] as String?,
      bedtime: _bedtimeFromMap(m['bedtime']),
    );
  }
}
