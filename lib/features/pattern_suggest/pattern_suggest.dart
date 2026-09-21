/// 行動パターンから「定期の予定にしませんか？」を提案する
///
/// 同じタイトル・同じ曜日の予定が何週も続いていたら、定期の予定として
/// まとめて登録できるように提案する。新しいデータは持たず、既存の予定
/// （EventRepository）と、すでに登録済みの定期の予定から計算するだけ。
library;

import '../events/calendar_event.dart';
import '../recurring/recurring_schedule.dart';
import '../timetable/school_periods.dart';

DateTime _day(DateTime d) => DateTime(d.year, d.month, d.day);

class PatternSuggestion {
  const PatternSuggestion({
    required this.key,
    required this.title,
    required this.weekday,
    required this.start,
    required this.end,
    required this.categoryId,
    required this.occurrences,
    this.location,
  });

  /// このカードを閉じた記憶に使う、一意なキー
  final String key;

  final String title;

  /// 1=月 〜 7=日
  final int weekday;

  final ClockTime start;
  final ClockTime end;
  final String categoryId;
  final String? location;

  /// 直近で何週にわたって見つかったか
  final int occurrences;

  String get weekdayLabel => weekdayLabelOf(weekday);
}

/// 過去の予定から、「毎週◯曜日の◯◯」のようなパターンを見つける
List<PatternSuggestion> detectPatternSuggestions({
  required List<CalendarEvent> events,
  required List<RecurringSchedule> existingRecurring,
  DateTime? now,
  int minOccurrences = 3,
  int lookbackDays = 63,
}) {
  final today = _day(now ?? DateTime.now());
  final since = today.subtract(Duration(days: lookbackDays));

  final groups = <String, List<CalendarEvent>>{};
  for (final e in events) {
    if (e.isAllDay || e.isTravelEvent) continue;
    if (isRecurringInstance(e)) continue; // すでに定期の予定なら対象外
    final title = e.title.trim();
    if (title.isEmpty) continue;
    if (e.start.isBefore(since) || e.start.isAfter(today)) continue;

    final key = '$title|${e.start.weekday}';
    groups.putIfAbsent(key, () => []).add(e);
  }

  final existingKeys = <String>{
    for (final r in existingRecurring)
      for (final w in r.weekdays) '${r.title.trim()}|$w',
  };

  final suggestions = <PatternSuggestion>[];
  for (final list in groups.values) {
    // 同じ週に何度あっても1回として数える（毎週かどうかを見たいので）
    final weeks = <int>{for (final e in list) _day(e.start).difference(since).inDays ~/ 7};
    if (weeks.length < minOccurrences) continue;

    list.sort((a, b) => a.start.compareTo(b.start));
    final last = list.last;
    final title = last.title.trim();
    final weekday = last.start.weekday;
    if (existingKeys.contains('$title|$weekday')) continue;

    final start = ClockTime(last.start.hour, last.start.minute);
    final durationMinutes = last.end.difference(last.start).inMinutes;
    final endTotal =
        start.totalMinutes + (durationMinutes > 0 ? durationMinutes : 60);
    final end = ClockTime((endTotal ~/ 60) % 24, endTotal % 60);

    suggestions.add(
      PatternSuggestion(
        key: '$title|$weekday|${start.totalMinutes}',
        title: title,
        weekday: weekday,
        start: start,
        end: end,
        categoryId: last.categoryId,
        location: last.location,
        occurrences: weeks.length,
      ),
    );
  }

  suggestions.sort((a, b) => b.occurrences.compareTo(a.occurrences));
  return suggestions;
}
