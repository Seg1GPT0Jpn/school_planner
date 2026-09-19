/// 時間割の授業に、小テストの印を付ける
library;

import '../timetable/day_timetable_resolver.dart';
import 'school_test.dart';
import 'weekly_lesson_test.dart';

/// その日の授業のうち、小テストがある授業に印を付ける
///
/// - 毎週のテスト（LEAP など）
/// - 手で登録した小テストのうち、時限を指定したもの
DayTimetable annotateLessonTests(
  DayTimetable day,
  List<WeeklyLessonTestCalculator> calculators, {
  List<SchoolTest> manualTests = const [],
}) {
  if (day.status != DayStatus.school) return day;

  // 時限 → その授業に付ける名前の一覧
  final labels = <int, List<String>>{};

  for (final calculator in calculators) {
    final occurrence = calculator.occurrenceOn(day.date);
    if (occurrence == null) continue;
    labels
        .putIfAbsent(occurrence.lesson.period, () => [])
        .add('${occurrence.rule.title} ${occurrence.rangeLabel}');
  }

  for (final test in manualTests) {
    final period = test.period;
    if (period == null || !test.isOn(day.date)) continue;
    if (!day.lessons.any((l) => l.period == period)) continue;
    labels.putIfAbsent(period, () => []).add(test.lessonLabel);
  }

  if (labels.isEmpty) return day;

  return day.withLessons([
    for (final lesson in day.lessons)
      labels[lesson.period] == null
          ? lesson
          : lesson.withTestLabel(labels[lesson.period]!.join(' / ')),
  ]);
}
