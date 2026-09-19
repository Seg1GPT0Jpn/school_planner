/// 持ち物
library;

import '../recurring/recurring_schedule.dart';
import '../timetable/day_timetable_resolver.dart';

class BelongingSettings {
  const BelongingSettings({
    this.daily = const [],
    this.bySubject = const {},
    this.byRecurring = const {},
  });

  /// 学校がある日は毎日
  final List<String> daily;

  /// 科目名 → 持ち物
  final Map<String, List<String>> bySubject;

  /// 定期の予定の ID → 持ち物
  final Map<String, List<String>> byRecurring;

  BelongingSettings copyWith({
    List<String>? daily,
    Map<String, List<String>>? bySubject,
    Map<String, List<String>>? byRecurring,
  }) => BelongingSettings(
    daily: daily ?? this.daily,
    bySubject: bySubject ?? this.bySubject,
    byRecurring: byRecurring ?? this.byRecurring,
  );
}

/// その日の持ち物（重なりは1つにまとめる）
List<String> belongingsFor({
  required DayTimetable day,
  required List<RecurringSchedule> recurring,
  required BelongingSettings settings,
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
  return result;
}
