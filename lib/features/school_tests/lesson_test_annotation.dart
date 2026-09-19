/// 時間割の授業に、小テストの印を付ける
library;

import '../timetable/day_timetable_resolver.dart';
import 'weekly_lesson_test.dart';

/// その日の授業のうち、毎週のテストがある授業に印を付ける
DayTimetable annotateLessonTests(
  DayTimetable day,
  List<WeeklyLessonTestCalculator> calculators,
) {
  if (day.status != DayStatus.school) return day;

  var lessons = day.lessons;
  var changed = false;

  for (final calculator in calculators) {
    final occurrence = calculator.occurrenceOn(day.date);
    if (occurrence == null) continue;

    final label = '${occurrence.rule.title} ${occurrence.rangeLabel}';
    lessons = [
      for (final lesson in lessons)
        lesson.period == occurrence.lesson.period
            ? lesson.withTestLabel(label)
            : lesson,
    ];
    changed = true;
  }

  return changed ? day.withLessons(lessons) : day;
}
