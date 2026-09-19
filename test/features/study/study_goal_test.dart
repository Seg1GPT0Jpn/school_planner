import 'package:flutter_test/flutter_test.dart';
import 'package:school_planner/features/goals/goal.dart';
import 'package:school_planner/features/study/study.dart';
import 'package:school_planner/features/study/study_goal.dart';

void main() {
  final sessions = [
    StudySession(subject: '数学Ⅰ', start: DateTime(2026, 9, 20, 10), minutes: 90),
    StudySession(
      subject: '数学Ⅰ',
      start: DateTime(2026, 9, 22, 20),
      minutes: 120,
    ),
    StudySession(subject: 'ECⅠ', start: DateTime(2026, 9, 21), minutes: 60),
    StudySession(subject: '数学Ⅰ', start: DateTime(2026, 9, 19), minutes: 30),
  ];

  test('科目と期間で数える（数え始める日〜期限の日）', () {
    final g = Goal(
      title: '今週 数学 5時間',
      type: GoalProgressType.studyTime,
      subject: '数学Ⅰ',
      startDate: DateTime(2026, 9, 20),
      dueDate: DateTime(2026, 9, 26),
      target: 5,
    );
    expect(studyHoursFor(g, sessions), 3.5);
  });

  test('科目なしならすべての科目', () {
    final g = Goal(
      title: '今週 合計',
      type: GoalProgressType.studyTime,
      startDate: DateTime(2026, 9, 20),
      dueDate: DateTime(2026, 9, 26),
    );
    expect(studyHoursFor(g, sessions), 4.5);
  });

  test('表示は「3.5/5時間」', () {
    const g = Goal(
      title: 'x',
      type: GoalProgressType.studyTime,
      current: 3.5,
      target: 5,
    );
    expect(g.progressText, '3.5/5時間');
    expect(g.progress, 0.7);
  });
}
