/// つづりの設定（Googleカレンダーの「設定」にあたるもの）
library;

/// 日付の書き方
enum DateStyle {
  ymdSlash('2026/9/21'),
  ymdJa('2026年9月21日'),
  mdJa('9月21日'),
  dmySlash('21/9/2026');

  const DateStyle(this.sample);

  /// 設定画面に出す見本
  final String sample;
}

/// 週の始まり
enum WeekStart {
  sunday('日曜日', DateTime.sunday),
  monday('月曜日', DateTime.monday),
  saturday('土曜日', DateTime.saturday);

  const WeekStart(this.label, this.weekday);

  final String label;

  /// DateTime.weekday と同じ番号（月=1 … 日=7）
  final int weekday;
}

/// カレンダーの「カスタムビュー」で見せる長さ
enum CustomViewRange {
  days2('2日間', 2),
  days3('3日間', 3),
  days4('4日間', 4),
  days5('5日間', 5),
  days6('6日間', 6),
  days7('7日間', 7),
  weeks2('2週間', 14),
  month('1か月', 31);

  const CustomViewRange(this.label, this.days);

  final String label;
  final int days;
}

const _weekdayJa = ['月', '火', '水', '木', '金', '土', '日'];

/// 設定にしたがって日付を文字にする
String formatDateWith(DateTime d, DateStyle style, {bool weekday = false}) {
  final base = switch (style) {
    DateStyle.ymdSlash => '${d.year}/${d.month}/${d.day}',
    DateStyle.ymdJa => '${d.year}年${d.month}月${d.day}日',
    DateStyle.mdJa => '${d.month}月${d.day}日',
    DateStyle.dmySlash => '${d.day}/${d.month}/${d.year}',
  };
  return weekday ? '$base(${_weekdayJa[d.weekday - 1]})' : base;
}

/// 設定にしたがって時刻を文字にする（分は 0〜1439）
String formatMinutesWith(int minutes, {required bool use24Hour}) {
  final m = ((minutes % 1440) + 1440) % 1440;
  final h = m ~/ 60;
  final mm = (m % 60).toString().padLeft(2, '0');
  if (use24Hour) return '$h:$mm';
  final ampm = h < 12 ? '午前' : '午後';
  var h12 = h % 12;
  if (h12 == 0) h12 = 12;
  return '$ampm$h12:$mm';
}

/// 時刻つきの日付
String formatDateTimeWith(
  DateTime d, {
  required DateStyle style,
  required bool use24Hour,
  bool weekday = true,
}) =>
    '${formatDateWith(d, style, weekday: weekday)} '
    '${formatMinutesWith(d.hour * 60 + d.minute, use24Hour: use24Hour)}';

/// 「◯分前」の言い方
String reminderLabel(int minutes) {
  if (minutes <= 0) return '予定の時刻';
  if (minutes % 1440 == 0) return '${minutes ~/ 1440}日前';
  if (minutes % 60 == 0) return '${minutes ~/ 60}時間前';
  return '$minutes分前';
}

/// 選べる「◯分前」
const reminderChoices = [0, 5, 10, 15, 30, 60, 120, 1440];

/// 選べる「予定のデフォルトの長さ」（分）
const durationChoices = [15, 30, 45, 60, 70, 90, 120];

/// つづり全体の設定
class AppSettings {
  const AppSettings({
    // 表示
    this.weekStart = WeekStart.sunday,
    this.showWeekend = true,
    this.dimPastEvents = true,
    this.boostShortEvents = true,
    this.customView = CustomViewRange.days3,
    // 言語と地域
    this.dateStyle = DateStyle.mdJa,
    this.use24Hour = true,
    // 予定
    this.defaultEventMinutes = 60,
    this.speedyEvents = false,
    // 通知
    this.defaultReminderMinutes = 30,
    this.allDayReminderMinutes = 7 * 60,
    this.notificationSound = true,
    // タイムゾーン
    this.timeZone = 'Asia/Tokyo',
    this.showWorldClock = false,
    this.secondTimeZone = '',
    // そのほか
    this.offlineEnabled = true,
    this.keyboardShortcuts = true,
  });

  // ── 表示 ──

  /// 週の始まり
  final WeekStart weekStart;

  /// 土日も出す
  final bool showWeekend;

  /// 終わった予定をうすく出す
  final bool dimPastEvents;

  /// 短い予定も読めるようにする（週・日ビューで最低の高さを確保）
  final bool boostShortEvents;

  /// カスタムビューの長さ
  final CustomViewRange customView;

  // ── 言語と地域 ──

  final DateStyle dateStyle;

  /// 24時間表示（OFF なら午前・午後）
  final bool use24Hour;

  // ── 予定 ──

  /// 新しい予定のはじめの長さ（分）
  final int defaultEventMinutes;

  /// 少し早く終わらせて、次の予定までの余裕を作る
  final bool speedyEvents;

  // ── 通知 ──

  /// 予定の既定の「◯分前」
  final int defaultReminderMinutes;

  /// 終日の予定を知らせる時刻（その日の0時からの分）
  final int allDayReminderMinutes;

  /// 通知に音を出す
  final bool notificationSound;

  // ── タイムゾーン ──

  final String timeZone;

  /// 世界時計（2つめのタイムゾーンも出す）
  final bool showWorldClock;

  final String secondTimeZone;

  // ── そのほか ──

  /// オフラインでも使えるようにする
  final bool offlineEnabled;

  /// キーボードショートカットを使う
  final bool keyboardShortcuts;

  /// 実際に使う長さ（少し早く終わる設定のとき短くする）
  int get eventMinutes {
    if (!speedyEvents) return defaultEventMinutes;
    final short = defaultEventMinutes > 60
        ? defaultEventMinutes - 10
        : defaultEventMinutes - 5;
    return short < 5 ? defaultEventMinutes : short;
  }

  /// 週の始まりから並べた曜日（例：日月火水木金土）
  List<String> get weekdayLabels => [
    for (var i = 0; i < 7; i++) _weekdayJa[(weekStart.weekday - 1 + i) % 7],
  ];

  /// その日を含む週の、はじめの日
  DateTime startOfWeek(DateTime d) {
    final base = DateTime(d.year, d.month, d.day);
    final offset = (base.weekday - weekStart.weekday + 7) % 7;
    return DateTime(base.year, base.month, base.day - offset);
  }

  String date(DateTime d, {bool weekday = false}) =>
      formatDateWith(d, dateStyle, weekday: weekday);

  String time(int minutes) => formatMinutesWith(minutes, use24Hour: use24Hour);

  String timeOf(DateTime d) => time(d.hour * 60 + d.minute);

  AppSettings copyWith({
    WeekStart? weekStart,
    bool? showWeekend,
    bool? dimPastEvents,
    bool? boostShortEvents,
    CustomViewRange? customView,
    DateStyle? dateStyle,
    bool? use24Hour,
    int? defaultEventMinutes,
    bool? speedyEvents,
    int? defaultReminderMinutes,
    int? allDayReminderMinutes,
    bool? notificationSound,
    String? timeZone,
    bool? showWorldClock,
    String? secondTimeZone,
    bool? offlineEnabled,
    bool? keyboardShortcuts,
  }) => AppSettings(
    weekStart: weekStart ?? this.weekStart,
    showWeekend: showWeekend ?? this.showWeekend,
    dimPastEvents: dimPastEvents ?? this.dimPastEvents,
    boostShortEvents: boostShortEvents ?? this.boostShortEvents,
    customView: customView ?? this.customView,
    dateStyle: dateStyle ?? this.dateStyle,
    use24Hour: use24Hour ?? this.use24Hour,
    defaultEventMinutes: defaultEventMinutes ?? this.defaultEventMinutes,
    speedyEvents: speedyEvents ?? this.speedyEvents,
    defaultReminderMinutes:
        defaultReminderMinutes ?? this.defaultReminderMinutes,
    allDayReminderMinutes: allDayReminderMinutes ?? this.allDayReminderMinutes,
    notificationSound: notificationSound ?? this.notificationSound,
    timeZone: timeZone ?? this.timeZone,
    showWorldClock: showWorldClock ?? this.showWorldClock,
    secondTimeZone: secondTimeZone ?? this.secondTimeZone,
    offlineEnabled: offlineEnabled ?? this.offlineEnabled,
    keyboardShortcuts: keyboardShortcuts ?? this.keyboardShortcuts,
  );

  Map<String, dynamic> toMap() => {
    'weekStart': weekStart.name,
    'showWeekend': showWeekend,
    'dimPastEvents': dimPastEvents,
    'boostShortEvents': boostShortEvents,
    'customView': customView.name,
    'dateStyle': dateStyle.name,
    'use24Hour': use24Hour,
    'defaultEventMinutes': defaultEventMinutes,
    'speedyEvents': speedyEvents,
    'defaultReminderMinutes': defaultReminderMinutes,
    'allDayReminderMinutes': allDayReminderMinutes,
    'notificationSound': notificationSound,
    'timeZone': timeZone,
    'showWorldClock': showWorldClock,
    'secondTimeZone': secondTimeZone,
    'offlineEnabled': offlineEnabled,
    'keyboardShortcuts': keyboardShortcuts,
  };

  /// 知らない値・足りない値は、はじめの設定にもどす
  static AppSettings fromMap(Map<String, dynamic>? m) {
    const d = AppSettings();
    if (m == null) return d;

    T pick<T extends Enum>(List<T> values, Object? name, T fallback) {
      for (final v in values) {
        if (v.name == name) return v;
      }
      return fallback;
    }

    bool flag(String key, bool fallback) =>
        m[key] is bool ? m[key] as bool : fallback;

    int number(String key, int fallback, {int min = 0, int max = 100000}) {
      final v = m[key];
      if (v is! num) return fallback;
      final i = v.toInt();
      return i < min || i > max ? fallback : i;
    }

    String text(String key, String fallback) =>
        m[key] is String ? m[key] as String : fallback;

    return AppSettings(
      weekStart: pick(WeekStart.values, m['weekStart'], d.weekStart),
      showWeekend: flag('showWeekend', d.showWeekend),
      dimPastEvents: flag('dimPastEvents', d.dimPastEvents),
      boostShortEvents: flag('boostShortEvents', d.boostShortEvents),
      customView: pick(CustomViewRange.values, m['customView'], d.customView),
      dateStyle: pick(DateStyle.values, m['dateStyle'], d.dateStyle),
      use24Hour: flag('use24Hour', d.use24Hour),
      defaultEventMinutes: number(
        'defaultEventMinutes',
        d.defaultEventMinutes,
        min: 5,
        max: 600,
      ),
      speedyEvents: flag('speedyEvents', d.speedyEvents),
      defaultReminderMinutes: number(
        'defaultReminderMinutes',
        d.defaultReminderMinutes,
        max: 10080,
      ),
      allDayReminderMinutes: number(
        'allDayReminderMinutes',
        d.allDayReminderMinutes,
        max: 1439,
      ),
      notificationSound: flag('notificationSound', d.notificationSound),
      timeZone: text('timeZone', d.timeZone),
      showWorldClock: flag('showWorldClock', d.showWorldClock),
      secondTimeZone: text('secondTimeZone', d.secondTimeZone),
      offlineEnabled: flag('offlineEnabled', d.offlineEnabled),
      keyboardShortcuts: flag('keyboardShortcuts', d.keyboardShortcuts),
    );
  }
}
