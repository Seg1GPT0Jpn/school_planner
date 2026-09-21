/// 予定が入っていない「空き時間」を見つける
library;

import '../events/calendar_event.dart';
import '../timetable/day_timetable_resolver.dart';
import '../timetable/school_periods.dart';

/// 1つの空き時間
class FreeSlot {
  const FreeSlot({required this.start, required this.end});

  final DateTime start;
  final DateTime end;

  int get minutes => end.difference(start).inMinutes;

  /// 「1時間20分」のような表示
  String get lengthLabel {
    final h = minutes ~/ 60, m = minutes % 60;
    if (h == 0) return '$m分';
    if (m == 0) return '$h時間';
    return '$h時間$m分';
  }
}

/// その日の授業（空きコマ・自習・カットされたコマを除く）と予定から、
/// 空いている時間を探す
List<FreeSlot> findFreeSlots({
  required DateTime day,
  DayTimetable? timetable,
  required List<CalendarEvent> events,
  ClockTime windowStart = const ClockTime(7, 0),
  ClockTime windowEnd = const ClockTime(23, 0),
  int minMinutes = 20,
}) {
  DateTime at(ClockTime t) =>
      DateTime(day.year, day.month, day.day, t.hour, t.minute);
  final dayStart = DateTime(day.year, day.month, day.day);
  final dayEnd = DateTime(day.year, day.month, day.day + 1);

  // ふさがっている時間帯を集める
  final busy = <(DateTime, DateTime)>[];

  if (timetable != null && timetable.status == DayStatus.school) {
    for (final l in timetable.lessons) {
      if (l.status == LessonStatus.empty || l.status == LessonStatus.cancelled) {
        continue;
      }
      busy.add((at(l.start), at(l.end)));
    }
  }

  for (final e in events) {
    if (e.isAllDay) continue;
    if (!e.start.isBefore(dayEnd) || !e.end.isAfter(dayStart)) continue;
    final s = e.start.isBefore(dayStart) ? dayStart : e.start;
    final en = e.end.isAfter(dayEnd) ? dayEnd : e.end;
    if (en.isAfter(s)) busy.add((s, en));
  }

  busy.sort((a, b) => a.$1.compareTo(b.$1));

  // 重なっている時間帯どうしをつなげる
  final merged = <(DateTime, DateTime)>[];
  for (final b in busy) {
    if (merged.isNotEmpty && !b.$1.isAfter(merged.last.$2)) {
      final last = merged.removeLast();
      merged.add((last.$1, b.$2.isAfter(last.$2) ? b.$2 : last.$2));
    } else {
      merged.add(b);
    }
  }

  // すき間を探す
  final slots = <FreeSlot>[];
  var cursor = at(windowStart);
  final limit = at(windowEnd);
  for (final b in merged) {
    if (b.$1.isAfter(cursor) && b.$1.isAfter(limit)) break;
    if (b.$1.isAfter(cursor)) {
      final end = b.$1.isBefore(limit) ? b.$1 : limit;
      if (end.difference(cursor).inMinutes >= minMinutes) {
        slots.add(FreeSlot(start: cursor, end: end));
      }
    }
    if (b.$2.isAfter(cursor)) cursor = b.$2;
    if (!cursor.isBefore(limit)) break;
  }
  if (cursor.isBefore(limit) &&
      limit.difference(cursor).inMinutes >= minMinutes) {
    slots.add(FreeSlot(start: cursor, end: limit));
  }
  return slots;
}
