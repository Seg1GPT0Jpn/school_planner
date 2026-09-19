/// その日の時間割を最終決定する
library;

import 'school_periods.dart';
import 'timetable_models.dart';
import 'week_cycle.dart';

/// 最終決定された授業の状態
enum LessonStatus {
  /// 通常どおり
  normal,

  /// 特定日の変更あり
  changed,

  /// 通常はない時限に追加
  added,

  /// 休講
  cancelled,

  /// 時間割が未設定（空きコマ）
  empty,
}

/// 最終決定された1コマ
class ResolvedLesson {
  const ResolvedLesson({
    required this.period,
    required this.start,
    required this.end,
    required this.status,
    this.subject,
    this.room,
    this.teacher,
    this.memo,
  });

  final int period;
  final ClockTime start;
  final ClockTime end;
  final LessonStatus status;
  final String? subject;
  final String? room;
  final String? teacher;
  final String? memo;

  /// 時刻はそのまま、授業の中身だけを other のものにする（入れ替え用）
  ResolvedLesson withContentOf(ResolvedLesson other) {
    return ResolvedLesson(
      period: period,
      start: start,
      end: end,
      status: LessonStatus.changed,
      subject: other.subject,
      room: other.room,
      teacher: other.teacher,
      memo: other.memo,
    );
  }
}

/// その日の状態
enum DayStatus {
  /// 授業あり
  school,

  /// 土日などで授業なし
  noSchool,

  /// 学校休業日（夏休み・臨時休校など）
  closed,

  /// 国民の祝日・休日
  holiday,

  /// Ⅰ週/Ⅱ週を判定できない（基準日が未設定など）
  weekUnknown,
}

/// 最終決定された1日分の時間割
class DayTimetable {
  const DayTimetable({
    required this.date,
    required this.status,
    required this.lessons,
    this.weekType,
    this.isWeekOverridden = false,
    this.isDayWeekTypeOverridden = false,
    this.hasDayOverride = false,
    this.closureTitle,
    this.holidayName,
    this.note,
  });

  final DateTime date;
  final DayStatus status;
  final List<ResolvedLesson> lessons;

  /// この日に使われた時間割の週
  final WeekType? weekType;

  /// この週に週単位override が設定されているか
  final bool isWeekOverridden;

  /// この日だけ、使う時間割の週が変更されているか
  final bool isDayWeekTypeOverridden;

  final bool hasDayOverride;

  /// 学校休業日の名前（例：夏休み）
  final String? closureTitle;

  /// 祝日の名前（例：敬老の日）
  final String? holidayName;

  final String? note;

  /// 「時間割変更あり」の表示に使う
  bool get hasChanges =>
      isDayWeekTypeOverridden ||
      lessons.any(
        (l) =>
            l.status == LessonStatus.changed ||
            l.status == LessonStatus.added ||
            l.status == LessonStatus.cancelled,
      );
}

/// 通常時間割・週の判定・例外を組み合わせて、その日の時間割を決める
class DayTimetableResolver {
  DayTimetableResolver({
    required this.weekCalculator,
    required List<TimetableSlot> slots,
    List<DayOverride> dayOverrides = const [],
    List<SchoolClosure> closures = const [],
    Map<String, String> holidays = const {},
  }) : _slots = {
         for (final s in slots) _slotKey(s.weekType, s.weekday, s.period): s,
       },
       _dayOverrides = {for (final o in dayOverrides) dateKey(o.date): o},
       _closures = closures,
       _holidays = holidays;

  final WeekCycleCalculator weekCalculator;
  final Map<String, TimetableSlot> _slots;
  final Map<String, DayOverride> _dayOverrides;
  final List<SchoolClosure> _closures;

  /// 祝日の一覧（キー：dateKey、値：祝日名）
  final Map<String, String> _holidays;

  static String _slotKey(WeekType weekType, int weekday, int period) =>
      '${weekType.name}-$weekday-$period';

  /// その日の時間割を最終決定する
  DayTimetable resolve(DateTime date) {
    final day = dateOnly(date);

    // ① 学校休業日（最優先）
    for (final closure in _closures) {
      if (closure.contains(day)) {
        return DayTimetable(
          date: day,
          status: DayStatus.closed,
          lessons: const [],
          closureTitle: closure.title,
        );
      }
    }

    // ② 国民の祝日・休日
    final holidayName = _holidays[dateKey(day)];
    if (holidayName != null) {
      return DayTimetable(
        date: day,
        status: DayStatus.holiday,
        lessons: const [],
        holidayName: holidayName,
      );
    }

    final weekday = day.weekday;
    final dayOverride = _dayOverrides[dateKey(day)];
    final isSchoolWeekday = SchoolPeriods.schoolWeekdays.contains(weekday);

    // ③ 土日で、特定日の変更もなければ授業なし
    if (!isSchoolWeekday && dayOverride == null) {
      return DayTimetable(
        date: day,
        status: DayStatus.noSchool,
        lessons: const [],
      );
    }

    // ④ Ⅰ週かⅡ週か
    //   特定日の指定 → 週単位override → 基準日の自動判定 の順に優先
    final dayWeekType = dayOverride?.weekType;
    final weekType = dayWeekType ?? weekCalculator.weekTypeFor(day);

    // 通常時間割を並べる
    final lessons = <int, ResolvedLesson>{};
    for (final period in SchoolPeriods.periodsFor(weekday)) {
      final slot = weekType == null
          ? null
          : _slots[_slotKey(weekType, weekday, period.number)];
      lessons[period.number] = ResolvedLesson(
        period: period.number,
        start: period.start,
        end: period.end,
        status: slot == null ? LessonStatus.empty : LessonStatus.normal,
        subject: slot?.subject,
        room: slot?.room,
        teacher: slot?.teacher,
        memo: slot?.memo,
      );
    }

    // 特定日の時限ごとの変更を上から重ねる
    if (dayOverride != null) {
      for (final change in dayOverride.changes) {
        _applyChange(lessons, change);
      }
    }

    final sortedLessons = lessons.values.toList()
      ..sort((a, b) => a.period.compareTo(b.period));

    return DayTimetable(
      date: day,
      status: (weekType == null && isSchoolWeekday)
          ? DayStatus.weekUnknown
          : DayStatus.school,
      lessons: sortedLessons,
      weekType: weekType,
      isWeekOverridden: weekCalculator.isOverridden(day),
      isDayWeekTypeOverridden: dayWeekType != null,
      hasDayOverride: dayOverride != null,
      note: dayOverride?.note,
    );
  }

  /// 変更を1つ適用する
  void _applyChange(Map<int, ResolvedLesson> lessons, PeriodChange change) {
    final base = lessons[change.period];

    switch (change.type) {
      case PeriodChangeType.replace:
        final standard = (change.period >= 1 && change.period <= 5)
            ? SchoolPeriods.byNumber(change.period)
            : null;
        final start = change.start ?? base?.start ?? standard?.start;
        final end = change.end ?? base?.end ?? standard?.end;
        if (start == null || end == null) {
          throw ArgumentError('${change.period}限の時刻を指定してください');
        }
        lessons[change.period] = ResolvedLesson(
          period: change.period,
          start: start,
          end: end,
          status: base == null ? LessonStatus.added : LessonStatus.changed,
          subject: change.subject ?? base?.subject,
          room: change.room ?? base?.room,
          teacher: change.teacher ?? base?.teacher,
          memo: change.memo ?? base?.memo,
        );

      case PeriodChangeType.cancel:
        if (base == null) return; // もともとない時限は何もしない
        lessons[change.period] = ResolvedLesson(
          period: base.period,
          start: base.start,
          end: base.end,
          status: LessonStatus.cancelled,
          subject: base.subject,
          room: base.room,
          teacher: base.teacher,
          memo: change.memo ?? base.memo,
        );

      case PeriodChangeType.swap:
        final other = lessons[change.otherPeriod];
        if (base == null || other == null) {
          throw ArgumentError(
            '${change.period}限と${change.otherPeriod}限は入れ替えできません',
          );
        }
        lessons[change.period] = base.withContentOf(other);
        lessons[change.otherPeriod!] = other.withContentOf(base);
    }
  }
}
