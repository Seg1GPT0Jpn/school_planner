/// その日の時間割を最終決定する
library;

import 'dart:collection';

import 'school_periods.dart';
import 'timetable_models.dart';
import 'week_cycle.dart';

enum LessonStatus { normal, changed, added, cancelled, empty }

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
    this.testLabel,
  });

  final int period;
  final ClockTime start;
  final ClockTime end;
  final LessonStatus status;
  final String? subject;
  final String? room;
  final String? teacher;
  final String? memo;

  /// この授業で行う小テスト（例：LEAP単語テスト 1201〜1300）
  final String? testLabel;

  ResolvedLesson withContentOf(ResolvedLesson other) => ResolvedLesson(
    period: period,
    start: start,
    end: end,
    status: LessonStatus.changed,
    subject: other.subject,
    room: other.room,
    teacher: other.teacher,
    memo: other.memo,
  );

  ResolvedLesson withTestLabel(String label) => ResolvedLesson(
    period: period,
    start: start,
    end: end,
    status: status,
    subject: subject,
    room: room,
    teacher: teacher,
    memo: memo,
    testLabel: label,
  );
}

enum DayStatus { school, noSchool, closed, holiday, weekUnknown }

class DayTimetable {
  const DayTimetable({
    required this.date,
    required this.status,
    required this.lessons,
    this.schedule = DaySchedule.regular,
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
  final DaySchedule schedule;
  final WeekType? weekType;
  final bool isWeekOverridden;
  final bool isDayWeekTypeOverridden;
  final bool hasDayOverride;
  final String? closureTitle;
  final String? holidayName;
  final String? note;

  bool get hasChanges =>
      schedule != DaySchedule.regular ||
      isDayWeekTypeOverridden ||
      lessons.any(
        (l) =>
            l.status == LessonStatus.changed ||
            l.status == LessonStatus.added ||
            l.status == LessonStatus.cancelled,
      );

  bool get hasTests => lessons.any((l) => l.testLabel != null);

  DayTimetable withLessons(List<ResolvedLesson> newLessons) => DayTimetable(
    date: date,
    status: status,
    lessons: newLessons,
    schedule: schedule,
    weekType: weekType,
    isWeekOverridden: isWeekOverridden,
    isDayWeekTypeOverridden: isDayWeekTypeOverridden,
    hasDayOverride: hasDayOverride,
    closureTitle: closureTitle,
    holidayName: holidayName,
    note: note,
  );
}

class DayTimetableResolver {
  DayTimetableResolver({
    required this.weekCalculator,
    required List<TimetableSlot> slots,
    List<DayOverride> dayOverrides = const [],
    List<SchoolClosure> closures = const [],
    Map<String, String> holidays = const {},
    this.postProcess,
    this.slotsForDate,
  }) : _slots = _toMap(slots),
       _dayOverrides = {for (final o in dayOverrides) dateKey(o.date): o},
       _closures = closures,
       _holidays = holidays;

  final WeekCycleCalculator weekCalculator;
  final Map<String, TimetableSlot> _slots;
  final Map<String, DayOverride> _dayOverrides;
  final List<SchoolClosure> _closures;
  final Map<String, String> _holidays;

  /// 計算の最後に通す「仕上げの係」（小テストの印を付けるなど）
  final DayTimetable Function(DayTimetable day)? postProcess;

  /// 日付ごとに使う時間割（切り替え日つきの時間割。null なら slots を使う）
  final List<TimetableSlot> Function(DateTime date)? slotsForDate;

  /// 版ごとの表を、何度も作らないための記録
  final Map<List<TimetableSlot>, Map<String, TimetableSlot>> _versionMaps =
      HashMap.identity();

  static String _slotKey(WeekType weekType, int weekday, int period) =>
      '${weekType.name}-$weekday-$period';

  static Map<String, TimetableSlot> _toMap(List<TimetableSlot> slots) => {
    for (final s in slots) _slotKey(s.weekType, s.weekday, s.period): s,
  };

  Map<String, TimetableSlot> _slotMapFor(DateTime day) {
    final f = slotsForDate;
    if (f == null) return _slots;
    final list = f(day);
    return _versionMaps.putIfAbsent(list, () => _toMap(list));
  }

  DayTimetable resolve(DateTime date) {
    final day = _resolveTimetable(date);
    return postProcess == null ? day : postProcess!(day);
  }

  DayTimetable _resolveTimetable(DateTime date) {
    final day = dateOnly(date);

    // ① 学校休業日
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

    // ② 祝日
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

    // ③ 土日
    if (!isSchoolWeekday && dayOverride == null) {
      return DayTimetable(
        date: day,
        status: DayStatus.noSchool,
        lessons: const [],
      );
    }

    // ④ Ⅰ週かⅡ週か
    final dayWeekType = dayOverride?.weekType;
    final weekType = dayWeekType ?? weekCalculator.weekTypeFor(day);

    // ⑤ 日課と時限
    final schedule = dayOverride?.schedule ?? DaySchedule.regular;
    final periods = SchoolPeriods.periodsForSchedule(schedule, weekday);
    final slotMap = _slotMapFor(day);

    final lessons = <int, ResolvedLesson>{};
    for (final period in periods) {
      final slot = (weekType == null || !schedule.usesRegularTimetable)
          ? null
          : slotMap[_slotKey(weekType, weekday, period.number)];
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

    if (dayOverride != null) {
      for (final change in dayOverride.changes) {
        _applyChange(lessons, change, periods);
      }
    }

    final sortedLessons = lessons.values.toList()
      ..sort((a, b) => a.period.compareTo(b.period));

    final isWeekUnknown =
        weekType == null && isSchoolWeekday && schedule.usesRegularTimetable;

    return DayTimetable(
      date: day,
      status: isWeekUnknown ? DayStatus.weekUnknown : DayStatus.school,
      lessons: sortedLessons,
      schedule: schedule,
      weekType: weekType,
      isWeekOverridden: weekCalculator.isOverridden(day),
      isDayWeekTypeOverridden: dayWeekType != null,
      hasDayOverride: dayOverride != null,
      note: dayOverride?.note,
    );
  }

  void _applyChange(
    Map<int, ResolvedLesson> lessons,
    PeriodChange change,
    List<SchoolPeriod> schedulePeriods,
  ) {
    final base = lessons[change.period];

    switch (change.type) {
      case PeriodChangeType.replace:
        SchoolPeriod? standard;
        for (final p in schedulePeriods) {
          if (p.number == change.period) standard = p;
        }
        if (standard == null && change.period >= 1 && change.period <= 5) {
          standard = SchoolPeriods.byNumber(change.period);
        }
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
        if (base == null) return;
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
