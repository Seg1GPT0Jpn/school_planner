import 'package:flutter_test/flutter_test.dart';
import 'package:school_planner/features/goals/goal.dart';

void main() {
  test('数値の進み具合', () {
    const g = Goal(title: 'LEAP', current: 1300, target: 2000, unit: '語');
    expect(g.progress, closeTo(0.65, 0.001));
    expect(g.progressText, '1300/2000語');
  });

  test('チェックリストの進み具合', () {
    const g = Goal(
      title: '英検',
      type: GoalProgressType.checklist,
      milestones: [Milestone('単語', done: true), Milestone('過去問')],
    );
    expect(g.progress, 0.5);
    expect(g.progressText, '1/2');
  });

  test('達成したら100%', () {
    const g = Goal(title: 'x', current: 10, target: 100, achieved: true);
    expect(g.progress, 1);
  });

  test('短期 → 長期、期限が近い順', () {
    final sorted = sortGoals([
      Goal(title: '長', term: GoalTerm.long, dueDate: DateTime(2026, 10, 1)),
      Goal(title: '短後', dueDate: DateTime(2026, 12, 1)),
      Goal(title: '短先', dueDate: DateTime(2026, 10, 1)),
    ]);
    expect(sorted.map((g) => g.title).toList(), ['短先', '短後', '長']);
  });
}
