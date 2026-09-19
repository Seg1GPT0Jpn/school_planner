/// 定期の予定（塾・部活など、毎週決まった曜日と時刻の予定）
library;

import '../events/calendar_event.dart';
import '../events/event_category.dart';
import '../timetable/school_periods.dart';
import '../timetable/week_cycle.dart';

/// カレンダーに出すときの予定IDの頭につける印
const String recurringIdPrefix = 'recurring:';

DateTime _day(DateTime d) => DateTime(d.year, d.month, d.day);

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
  });

  final String? id;
  final String title;

  /// 曜日（1=月 〜 7=日）
  final int weekday;

  final ClockTime start;
  final ClockTime end;

  /// この日から（null なら最初から）
  final DateTime? validFrom;

  /// この日まで（null ならずっと）
  final DateTime? validUntil;

  final String categoryId;
  final String? location;

  /// 休みにした日（dateKey）
  final Set<String> skippedDates;

  /// その日に行うか
  bool occursOn(DateTime date) {
    final d = _day(date);
    if (d.weekday != weekday) return false;
    if (validFrom != null && d.isBefore(_day(validFrom!))) return false;
    if (validUntil != null && d.isAfter(_day(validUntil!))) return false;
    return !skippedDates.contains(dateKey(d));
  }

  /// その日の分を、カレンダー用の予定にする
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

  /// 入力内容の確認（問題がなければ null）
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
    return null;
  }
}

/// from 〜 to（to は含まない）の定期の予定を、カレンダー用の予定に展開する
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

/// カレンダーの予定が、定期の予定から作られたものか
bool isRecurringInstance(CalendarEvent e) =>
    e.id?.startsWith(recurringIdPrefix) ?? false;

/// カレンダーの予定から、元の定期の予定のIDと日付を取り出す
(String, DateTime)? parseRecurringInstance(CalendarEvent e) {
  if (!isRecurringInstance(e)) return null;
  final rest = e.id!.substring(recurringIdPrefix.length);
  final i = rest.lastIndexOf(':');
  final p = rest.substring(i + 1).split('-').map(int.parse).toList();
  return (rest.substring(0, i), DateTime(p[0], p[1], p[2]));
}
