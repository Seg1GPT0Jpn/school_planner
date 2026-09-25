/// 持ち物
library;

import '../events/calendar_event.dart';
import '../recurring/recurring_schedule.dart';
import '../timetable/day_timetable_resolver.dart';

class BelongingSettings {
  const BelongingSettings({
    this.daily = const [],
    this.bySubject = const {},
    this.byRecurring = const {},
    this.byCategory = const {},
  });

  /// 学校がある日は毎日
  final List<String> daily;

  /// 科目名 → 持ち物
  final Map<String, List<String>> bySubject;

  /// 定期の予定の ID → 持ち物
  final Map<String, List<String>> byRecurring;

  /// 予定のカテゴリID → 持ち物（定期でない、ふつうの予定にも使える）
  final Map<String, List<String>> byCategory;

  BelongingSettings copyWith({
    List<String>? daily,
    Map<String, List<String>>? bySubject,
    Map<String, List<String>>? byRecurring,
    Map<String, List<String>>? byCategory,
  }) => BelongingSettings(
    daily: daily ?? this.daily,
    bySubject: bySubject ?? this.bySubject,
    byRecurring: byRecurring ?? this.byRecurring,
    byCategory: byCategory ?? this.byCategory,
  );
}

/// その日の持ち物（重なりは1つにまとめる）
///
/// [events] を渡すと、その日にある（定期・定期でないどちらも含む）予定の
/// カテゴリに登録した持ち物と、予定ごとに追加した持ち物（CalendarEvent.belongings）
/// も合わせて出す。渡さなければ今まで通り（科目・定期の予定のみ）。
List<String> belongingsFor({
  required DayTimetable day,
  required List<RecurringSchedule> recurring,
  required BelongingSettings settings,
  List<CalendarEvent> events = const [],
}) {
  final result = <String>[];
  void add(Iterable<String> items) {
    for (final x in items) {
      if (!result.contains(x)) result.add(x);
    }
  }

  if (day.status == DayStatus.school) {
    add(settings.daily);
    for (final l in day.lessons) {
      if (l.subject == null || l.status == LessonStatus.cancelled) continue;
      add(settings.bySubject[l.subject] ?? const []);
    }
  }
  for (final s in recurring) {
    if (s.id != null && s.occursOn(day.date)) {
      add(settings.byRecurring[s.id] ?? const []);
    }
  }
  for (final e in events) {
    if (e.isTravelEvent) continue;
    if (!e.occursOn(day.date)) continue;
    add(settings.byCategory[e.categoryId] ?? const []);
    add(e.belongings);
  }
  return result;
}
