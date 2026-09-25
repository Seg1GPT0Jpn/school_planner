/// 学校の「時間枠」の定義
///
/// 時限の時刻・曜日ごとのコマ数・日課ごとの時程は、アプリ全体でこのファイルだけを参照する。
/// 中身は「時程の設定」（users/{uid}/settings/school_schedule）で変えられる。
/// 何も設定していないときは [ScheduleConfig.standard]（今の学校の時程）を使う。
library;

import '../../core/japanese_holidays.dart';
import 'week_cycle.dart';

/// 時刻（時・分）を表すクラス
class ClockTime implements Comparable<ClockTime> {
  const ClockTime(this.hour, this.minute);

  final int hour;
  final int minute;

  /// 0:00 からの経過分数（比較や計算に使う）
  int get totalMinutes => hour * 60 + minute;

  /// 「8:50」「08:50」のどちらでも読む（読めなければ null）
  static ClockTime? tryParse(Object? v) {
    if (v is! String) return null;
    final m = RegExp(r'^(\d{1,2}):(\d{2})$').firstMatch(v.trim());
    if (m == null) return null;
    final h = int.parse(m.group(1)!), min = int.parse(m.group(2)!);
    if (h > 23 || min > 59) return null;
    return ClockTime(h, min);
  }

  /// 分からつくる
  factory ClockTime.fromMinutes(int minutes) {
    final m = ((minutes % 1440) + 1440) % 1440;
    return ClockTime(m ~/ 60, m % 60);
  }

  ClockTime addMinutes(int minutes) =>
      ClockTime.fromMinutes(totalMinutes + minutes);

  @override
  int compareTo(ClockTime other) => totalMinutes.compareTo(other.totalMinutes);

  @override
  bool operator ==(Object other) =>
      other is ClockTime && other.hour == hour && other.minute == minute;

  @override
  int get hashCode => Object.hash(hour, minute);

  /// 「08:50」のような表示用の文字列
  @override
  String toString() {
    final h = hour.toString().padLeft(2, '0');
    final m = minute.toString().padLeft(2, '0');
    return '$h:$m';
  }
}

/// 1コマ分の授業時間（何時間目か・開始時刻・終了時刻）
class SchoolPeriod {
  const SchoolPeriod({
    required this.number,
    required this.start,
    required this.end,
  });

  /// 何時間目か
  final int number;
  final ClockTime start;
  final ClockTime end;

  /// 「1限」のような表示用の名前
  String get label => '$number限';

  /// 授業の長さ（分）
  int get durationMinutes => end.totalMinutes - start.totalMinutes;

  Map<String, dynamic> toMap() => {
    'number': number,
    'start': '$start',
    'end': '$end',
  };

  static SchoolPeriod? fromMap(Object? m) {
    if (m is! Map) return null;
    final n = m['number'];
    final s = ClockTime.tryParse(m['start']);
    final e = ClockTime.tryParse(m['end']);
    if (n is! num || s == null || e == null) return null;
    return SchoolPeriod(number: n.toInt(), start: s, end: e);
  }

  @override
  bool operator ==(Object other) =>
      other is SchoolPeriod &&
      other.number == number &&
      other.start == start &&
      other.end == end;

  @override
  int get hashCode => Object.hash(number, start, end);
}

/// 日課（その日の時程の種類）
enum DaySchedule {
  regular('通常日課'),
  shortened('短縮日課'),
  exam('試験日課'),
  custom('特殊日課');

  const DaySchedule(this.label);

  /// 画面表示用の名前
  final String label;

  /// 昼休みがあるか
  ///
  /// 特殊日課（custom）は、その日ごとに決めた時限（[DayOverride.customPeriods]）を
  /// そのまま使うので、共通の昼休み時刻（[SchoolPeriods.lunchStart] など）には
  /// 対応しない（昼休みを入れたければ、時限と時限の間の休み時間として表現する）。
  bool get hasLunch => this == DaySchedule.regular;

  /// Ⅰ週/Ⅱ週の通常時間割を使うか（試験日課は使わない）
  bool get usesRegularTimetable => this != DaySchedule.exam;
}

/// その日の授業が終わる時刻（分）。授業のない日（祝日・土日など）は null
///
/// 移動時間の目安（travel機能）や、定期の予定を「放課後の何分後から」に
/// する機能など、「放課後」を基準にする機能から共通で使う。
int? schoolEndMinutesOn(DateTime day) {
  if (japaneseHolidays.containsKey(dateKey(day))) return null;
  final periods = SchoolPeriods.periodsFor(day.weekday);
  if (periods.isEmpty) return null;
  return periods.last.end.totalMinutes;
}

/// 時程の設定（学校ごと・人ごとに変えられる）
class ScheduleConfig {
  const ScheduleConfig({
    required this.periods,
    required this.periodCounts,
    required this.lunchAfterPeriod,
    required this.lunchStart,
    required this.lunchEnd,
    required this.shortened,
    required this.examPeriods,
    this.useWeekCycle = true,
  });

  /// 通常日課の時限（いちばんコマ数が多い日のぶんまで。番号順）
  final List<SchoolPeriod> periods;

  /// 曜日（月=1 … 日=7）ごとのコマ数（0 なら授業なし）
  final Map<int, int> periodCounts;

  /// 昼休みは何時間目のあとか（0 なら昼休みなし）
  final int lunchAfterPeriod;
  final ClockTime lunchStart;
  final ClockTime lunchEnd;

  /// 短縮日課の時程（キー：その曜日の通常のコマ数）
  final Map<int, List<SchoolPeriod>> shortened;

  /// 試験日課の時程
  final List<SchoolPeriod> examPeriods;

  /// Ⅰ週・Ⅱ週で時間割が変わるか（false なら毎週同じ）
  final bool useWeekCycle;

  /// 今の学校の時程（何も設定していないときはこれ）
  static const standard = ScheduleConfig(
    // 通常日課（70分授業）
    periods: [
      SchoolPeriod(number: 1, start: ClockTime(8, 50), end: ClockTime(10, 0)),
      SchoolPeriod(number: 2, start: ClockTime(10, 10), end: ClockTime(11, 20)),
      SchoolPeriod(number: 3, start: ClockTime(11, 30), end: ClockTime(12, 40)),
      SchoolPeriod(number: 4, start: ClockTime(13, 30), end: ClockTime(14, 40)),
      SchoolPeriod(number: 5, start: ClockTime(14, 50), end: ClockTime(16, 0)),
    ],
    // 月火木=5、水金=4、土日=0
    periodCounts: {1: 5, 2: 5, 3: 4, 4: 5, 5: 4, 6: 0, 7: 0},
    lunchAfterPeriod: 3,
    lunchStart: ClockTime(12, 40),
    lunchEnd: ClockTime(13, 25),
    shortened: {
      // 通常5コマの曜日（40分 × 5）
      5: [
        SchoolPeriod(number: 1, start: ClockTime(8, 50), end: ClockTime(9, 30)),
        SchoolPeriod(
          number: 2,
          start: ClockTime(9, 40),
          end: ClockTime(10, 20),
        ),
        SchoolPeriod(
          number: 3,
          start: ClockTime(10, 30),
          end: ClockTime(11, 10),
        ),
        SchoolPeriod(
          number: 4,
          start: ClockTime(11, 20),
          end: ClockTime(12, 0),
        ),
        SchoolPeriod(
          number: 5,
          start: ClockTime(12, 10),
          end: ClockTime(12, 50),
        ),
      ],
      // 通常4コマの曜日（50分 × 4）
      4: [
        SchoolPeriod(number: 1, start: ClockTime(8, 50), end: ClockTime(9, 40)),
        SchoolPeriod(
          number: 2,
          start: ClockTime(9, 50),
          end: ClockTime(10, 40),
        ),
        SchoolPeriod(
          number: 3,
          start: ClockTime(10, 50),
          end: ClockTime(11, 40),
        ),
        SchoolPeriod(
          number: 4,
          start: ClockTime(11, 50),
          end: ClockTime(12, 40),
        ),
      ],
    },
    // 定期試験の日（3コマ）
    examPeriods: [
      SchoolPeriod(number: 1, start: ClockTime(9, 0), end: ClockTime(10, 0)),
      SchoolPeriod(number: 2, start: ClockTime(10, 15), end: ClockTime(11, 15)),
      SchoolPeriod(number: 3, start: ClockTime(11, 30), end: ClockTime(12, 30)),
    ],
  );

  /// 授業がある曜日
  Set<int> get schoolWeekdays => {
    for (final e in periodCounts.entries)
      if (e.value > 0) e.key,
  };

  int periodCountFor(int weekday) {
    final n = periodCounts[weekday] ?? 0;
    return n.clamp(0, periods.length);
  }

  /// 通常のコマ数ごとの短縮日課（なければ通常日課のまま）
  List<SchoolPeriod> shortenedFor(int regularCount) {
    final s = shortened[regularCount];
    if (s != null && s.isNotEmpty) return s;
    return periods.take(regularCount).toList();
  }

  /// 設定画面で必要な「通常のコマ数」の種類（例：[4, 5]）
  List<int> get distinctCounts => ({
    for (final w in periodCounts.keys)
      if (periodCountFor(w) > 0) periodCountFor(w),
  }.toList()..sort());

  ScheduleConfig copyWith({
    List<SchoolPeriod>? periods,
    Map<int, int>? periodCounts,
    int? lunchAfterPeriod,
    ClockTime? lunchStart,
    ClockTime? lunchEnd,
    Map<int, List<SchoolPeriod>>? shortened,
    List<SchoolPeriod>? examPeriods,
    bool? useWeekCycle,
  }) => ScheduleConfig(
    periods: periods ?? this.periods,
    periodCounts: periodCounts ?? this.periodCounts,
    lunchAfterPeriod: lunchAfterPeriod ?? this.lunchAfterPeriod,
    lunchStart: lunchStart ?? this.lunchStart,
    lunchEnd: lunchEnd ?? this.lunchEnd,
    shortened: shortened ?? this.shortened,
    examPeriods: examPeriods ?? this.examPeriods,
    useWeekCycle: useWeekCycle ?? this.useWeekCycle,
  );

  Map<String, dynamic> toMap() => {
    'periods': [for (final p in periods) p.toMap()],
    'periodCounts': {for (final e in periodCounts.entries) '${e.key}': e.value},
    'lunchAfterPeriod': lunchAfterPeriod,
    'lunchStart': '$lunchStart',
    'lunchEnd': '$lunchEnd',
    'shortened': {
      for (final e in shortened.entries)
        '${e.key}': [for (final p in e.value) p.toMap()],
    },
    'examPeriods': [for (final p in examPeriods) p.toMap()],
    'useWeekCycle': useWeekCycle,
  };

  static List<SchoolPeriod> _periods(Object? v) {
    if (v is! List) return const [];
    return [for (final x in v) ?SchoolPeriod.fromMap(x)]
      ..sort((a, b) => a.number.compareTo(b.number));
  }

  /// 保存されたものを読む（こわれていたり足りなかったりしたら、今の学校の時程を使う）
  static ScheduleConfig fromMap(Map<String, dynamic>? m) {
    const d = standard;
    if (m == null) return d;

    final periods = _periods(m['periods']);
    final counts = <int, int>{};
    final rawCounts = m['periodCounts'];
    if (rawCounts is Map) {
      for (final e in rawCounts.entries) {
        final k = int.tryParse('${e.key}');
        final v = e.value;
        if (k != null && k >= 1 && k <= 7 && v is num) counts[k] = v.toInt();
      }
    }
    final shortened = <int, List<SchoolPeriod>>{};
    final rawShort = m['shortened'];
    if (rawShort is Map) {
      for (final e in rawShort.entries) {
        final k = int.tryParse('${e.key}');
        final list = _periods(e.value);
        if (k != null && list.isNotEmpty) shortened[k] = list;
      }
    }
    final exam = _periods(m['examPeriods']);

    return ScheduleConfig(
      periods: periods.isEmpty ? d.periods : periods,
      periodCounts: counts.isEmpty ? d.periodCounts : counts,
      lunchAfterPeriod: m['lunchAfterPeriod'] is num
          ? (m['lunchAfterPeriod'] as num).toInt()
          : d.lunchAfterPeriod,
      lunchStart: ClockTime.tryParse(m['lunchStart']) ?? d.lunchStart,
      lunchEnd: ClockTime.tryParse(m['lunchEnd']) ?? d.lunchEnd,
      shortened: rawShort is Map ? shortened : d.shortened,
      examPeriods: exam.isEmpty ? d.examPeriods : exam,
      useWeekCycle: m['useWeekCycle'] is bool
          ? m['useWeekCycle'] as bool
          : d.useWeekCycle,
    );
  }

  /// 設定の中身がおかしくないかを調べる（問題がなければ空）
  List<String> problems() {
    final out = <String>[];
    void check(String name, List<SchoolPeriod> list) {
      for (var i = 0; i < list.length; i++) {
        final p = list[i];
        if (p.number != i + 1) {
          out.add('$name：時限の番号が1から順になっていません');
          return;
        }
        if (p.end.totalMinutes <= p.start.totalMinutes) {
          out.add('$name：${p.number}限の終わりが始まりより前です');
        }
        if (i > 0 && p.start.totalMinutes < list[i - 1].end.totalMinutes) {
          out.add('$name：${p.number}限が${list[i - 1].number}限と重なっています');
        }
      }
    }

    if (periods.isEmpty) out.add('通常日課の時限が1つもありません');
    check('通常日課', periods);
    for (final e in shortened.entries) {
      check('短縮日課（${e.key}コマの日）', e.value);
    }
    check('試験日課', examPeriods);
    if (lunchAfterPeriod > 0 &&
        lunchEnd.totalMinutes <= lunchStart.totalMinutes) {
      out.add('昼休みの終わりが始まりより前です');
    }
    return out;
  }
}

/// 学校の時間枠（このクラスはインスタンスを作らずに使う）
///
/// 中身は [config]。時間割のデータを読んだときに、設定した時程に入れかわる。
class SchoolPeriods {
  SchoolPeriods._();

  /// いま使っている時程
  static ScheduleConfig config = ScheduleConfig.standard;

  // ---------------- 通常日課 ----------------

  /// 全時限の標準時刻
  static List<SchoolPeriod> get all => config.periods;

  /// 昼休み（通常日課のみ）
  static ClockTime get lunchStart => config.lunchStart;
  static ClockTime get lunchEnd => config.lunchEnd;

  /// 昼休みは何時間目のあとか（0 なら昼休みなし）
  static int get lunchAfterPeriod => config.lunchAfterPeriod;

  // ---------------- 試験日課 ----------------

  static List<SchoolPeriod> get examPeriods => config.examPeriods;

  // ---------------- 曜日 ----------------

  /// 授業がある曜日
  static Set<int> get schoolWeekdays => config.schoolWeekdays;

  /// その曜日の通常の授業数
  static int periodCountFor(int weekday) => config.periodCountFor(weekday);

  /// その曜日の通常日課の時限一覧
  static List<SchoolPeriod> periodsFor(int weekday) =>
      all.take(periodCountFor(weekday)).toList();

  /// 日課と曜日から、その日の時限一覧を決める
  ///
  /// 特殊日課（[DaySchedule.custom]）は、日によって時限の長さがバラバラなので、
  /// ここではなく [DayOverride.customPeriods] から直接決める
  /// （[DayTimetableResolver] を参照）。この関数が custom で呼ばれることはないが、
  /// switch を全パターン対応させるために空リストを返す。
  static List<SchoolPeriod> periodsForSchedule(
    DaySchedule schedule,
    int weekday,
  ) {
    switch (schedule) {
      case DaySchedule.regular:
        return periodsFor(weekday);
      case DaySchedule.shortened:
        final count = periodCountFor(weekday);
        if (count == 0) return const [];
        return config.shortenedFor(count);
      case DaySchedule.exam:
        return examPeriods;
      case DaySchedule.custom:
        return const [];
    }
  }

  /// その曜日に、その時限が「通常の授業」として存在するか
  static bool isRegularPeriod(int weekday, int periodNumber) {
    return periodNumber >= 1 && periodNumber <= periodCountFor(weekday);
  }

  /// その番号の時限があるか
  static bool hasPeriod(int periodNumber) =>
      all.any((p) => p.number == periodNumber);

  /// 時限の番号から通常日課の標準時刻を取り出す（ない番号はエラー）
  static SchoolPeriod byNumber(int periodNumber) {
    return all.firstWhere(
      (p) => p.number == periodNumber,
      orElse: () => throw ArgumentError('存在しない時限です: $periodNumber'),
    );
  }
}
