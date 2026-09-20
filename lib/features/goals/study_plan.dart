/// 定期テスト前の勉強計画（毎日の科目を自動で割り振る）
library;

import 'dart:math' as math;

import '../school_tests/school_test.dart';
import 'goal.dart';

const _wd = ['月', '火', '水', '木', '金', '土', '日'];

/// 例：11/22(日)
String planDayLabel(DateTime d) => '${d.month}/${d.day}(${_wd[d.weekday - 1]})';

/// 勉強計画の目標の ID（テスト1つにつき1つ）
String studyPlanGoalId(String testId) => 'plan_$testId';

/// テストの [days] 日前から前日までの計画を作る
///
/// 科目を順番に [perDay] 個ずつ割り振り、前日は「全体の見直し」にする。
List<String> buildStudyPlan({
  required DateTime examDate,
  required List<String> subjects,
  int days = 14,
  int perDay = 2,
}) {
  if (subjects.isEmpty || days <= 0) return [];
  final items = <String>[];
  var k = 0;
  for (var i = days; i >= 1; i--) {
    final day = DateTime(examDate.year, examDate.month, examDate.day - i);
    if (i == 1) {
      items.add('${planDayLabel(day)} 全体の見直し・持ち物の確認');
      continue;
    }
    final n = math.min(perDay, subjects.length);
    final today = [
      for (var j = 0; j < n; j++) subjects[(k + j) % subjects.length],
    ];
    k += n;
    items.add('${planDayLabel(day)} ${today.join('・')}');
  }
  return items;
}

/// 計画を「チェックリスト」の目標にする
Goal studyPlanGoal(SchoolTest t, List<String> items, int days) => Goal(
  id: studyPlanGoalId(t.id!),
  title: '${t.title}の勉強計画',
  term: GoalTerm.short,
  startDate: DateTime(t.date.year, t.date.month, t.date.day - days),
  dueDate: t.date,
  type: GoalProgressType.checklist,
  milestones: [for (final s in items) Milestone(s)],
);
