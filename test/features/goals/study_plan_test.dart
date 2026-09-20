import 'package:flutter_test/flutter_test.dart';
import 'package:school_planner/features/goals/goal.dart';
import 'package:school_planner/features/goals/study_plan.dart';
import 'package:school_planner/features/school_tests/school_test.dart';

void main() {
  test('科目を順番に割り振り、前日は見直し', () {
    final items = buildStudyPlan(
      examDate: DateTime(2026, 11, 25),
      subjects: ['数学Ⅰ', 'ECⅠ', '化学基礎'],
      days: 3,
      perDay: 2,
    );
    expect(items, [
      '11/22(日) 数学Ⅰ・ECⅠ',
      '11/23(月) 化学基礎・数学Ⅰ',
      '11/24(火) 全体の見直し・持ち物の確認',
    ]);
  });

  test('科目がなければ空', () {
    expect(
      buildStudyPlan(examDate: DateTime(2026, 11, 25), subjects: const []),
      isEmpty,
    );
  });

  test('2週間なら14日分', () {
    final items = buildStudyPlan(
      examDate: DateTime(2026, 11, 25),
      subjects: ['数学Ⅰ'],
    );
    expect(items.length, 14);
    expect(items.first, startsWith('11/11(水)'));
  });

  test('チェックリストの目標になる', () {
    final t = SchoolTest(
      id: 'abc',
      kind: SchoolTestKind.regularExam,
      title: '後期中間試験',
      date: DateTime(2026, 11, 25),
    );
    final g = studyPlanGoal(t, ['a', 'b'], 14);
    expect(g.id, 'plan_abc');
    expect(g.type, GoalProgressType.checklist);
    expect(g.milestones.length, 2);
    expect(g.startDate, DateTime(2026, 11, 11));
    expect(g.dueDate, DateTime(2026, 11, 25));
  });
}
