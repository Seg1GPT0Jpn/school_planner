/// 定期の予定（塾・部活など、毎週決まった曜日と時刻の予定）
library;

import '../events/calendar_event.dart';
import '../events/event_category.dart';
import '../timetable/school_periods.dart';
import '../timetable/week_cycle.dart';

const String recurringIdPrefix = 'recurring:';

DateTime _day(DateTime d) => DateTime(d.year, d.month, d.day);

/// 毎回のミニテストの設定
class RecurringTestConfig {
  const RecurringTestConfig({
    required this.title,
    this.baseDate,
    this.baseStart,
    this.step = 50,
    this.withReview = false,
  });

  final String title;

  /// この日の範囲が baseStart から（どちらも null なら範囲なし）
  final DateTime? baseDate;
  final int? baseStart;

  /// 1回で進む数
  final int step;

  /// 前回の範囲も出すか
  final bool withReview;

  bool get hasRange => baseDate != null && baseStart != null;
}

class RecurringSchedule {
  const RecurringSchedule({
    this.id,
    required this.title,
    required this.weekday,
    required this.start,
    required this.end,
    this.validFrom,
    this.validUntil,
    this.categoryId = EventCategory.otherId,
    this.location,
    this.skippedDates = const {},
    this.test,
  });

  final String? id;
  final String title;

  /// 曜日（1=月 〜 7=日）
  final int weekday;

  final ClockTime start;
  final ClockTime end;
  final DateTime? validFrom;
  final DateTime? validUntil;
  final String categoryId;
  final String? location;

  /// 休みにした日（dateKey）
  final Set<String> skippedDates;

  /// 毎回のミニテスト（なければ null）
  final RecurringTestConfig? test;

  bool occursOn(DateTime date) {
    final d = _day(date);
    if (d.weekday != weekday) return false;
    if (validFrom != null && d.isBefore(_day(validFrom!))) return false;
    if (validUntil != null && d.isAfter(_day(validUntil!))) return false;
    return !skippedDates.contains(dateKey(d));
  }

  CalendarEvent toEvent(DateTime date) {
    final d = _day(date);
    return CalendarEvent(
      id: '$recurringIdPrefix$id:${dateKey(d)}',
      title: title,
      start: d.add(Duration(minutes: start.totalMinutes)),
      end: d.add(Duration(minutes: end.totalMinutes)),
      location: location,
      categoryId: categoryId,
    );
  }

  String? validate() {
    if (title.trim().isEmpty) return '名前を入力してください';
    if (end.totalMinutes <= start.totalMinutes) {
      return '終了時刻は開始時刻より後にしてください';
    }
    if (validFrom != null &&
        validUntil != null &&
        _day(validUntil!).isBefore(_day(validFrom!))) {
      return '終了日は開始日より後にしてください';
    }
    if (test != null && test!.title.trim().isEmpty) {
      return 'ミニテストの名前を入力してください';
    }
    return null;
  }
}

List<CalendarEvent> expandRecurring(
  List<RecurringSchedule> schedules,
  DateTime from,
  DateTime to,
) {
  final result = <CalendarEvent>[];
  for (
    var d = _day(from);
    d.isBefore(to);
    d = DateTime(d.year, d.month, d.day + 1)
  ) {
    for (final s in schedules) {
      if (s.occursOn(d)) result.add(s.toEvent(d));
    }
  }
  return result;
}

bool isRecurringInstance(CalendarEvent e) =>
    e.id?.startsWith(recurringIdPrefix) ?? false;

(String, DateTime)? parseRecurringInstance(CalendarEvent e) {
  if (!isRecurringInstance(e)) return null;
  final rest = e.id!.substring(recurringIdPrefix.length);
  final i = rest.lastIndexOf(':');
  final p = rest.substring(i + 1).split('-').map(int.parse).toList();
  return (rest.substring(0, i), DateTime(p[0], p[1], p[2]));
}
