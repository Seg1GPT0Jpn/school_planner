/// 毎週のテストのルール（初期値）
library;

import 'weekly_lesson_test.dart';

/// LEAP 単語テスト：その週の最初の ECⅠ、9/28 の週に 1201〜1300、100語ずつ、2300 まで
final WeeklyLessonTestRule leapRule = WeeklyLessonTestRule(
  id: 'leap',
  subject: 'ECⅠ',
  title: 'LEAP単語テスト',
  baseWeekDate: DateTime(2026, 9, 28),
  baseRangeStart: 1201,
  rangeStep: 100,
  endNumber: 2300,
);
