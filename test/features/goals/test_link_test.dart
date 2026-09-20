import 'package:flutter_test/flutter_test.dart';
import 'package:school_planner/features/goals/goal.dart';
import 'package:school_planner/features/goals/test_goal_link.dart';
import 'package:school_planner/features/grades/grade.dart';
import 'package:school_planner/features/grades/last_grade_hint.dart';
import 'package:school_planner/features/school_tests/school_test.dart';
import 'package:school_planner/features/todo/todo.dart';

void main() {
  final exam = SchoolTest(
    id: 'abc',
    kind: SchoolTestKind.regularExam,
    title: '後期期末試験',
    date: DateTime(2027, 3, 1),
    subject: '数学Ⅰ',
    targetScore: 80,
    studyTodo: true,
  );

  test('目標点から目標を作る', () {
    final g = goalForTest(exam);
    expect(g.id, 'test_abc');
    expect(g.title, '数学Ⅰ 後期期末試験で80点');
    expect(g.type, GoalProgressType.number);
    expect(g.target, 80);
    expect(g.unit, '点');
    expect(g.dueDate, DateTime(2027, 3, 1));
    expect(g.subject, '数学Ⅰ');
  });

  test('保存する項目に「今の点数」「達成」は入れない（上書きしない）', () {
    final m = testGoalFields(exam);
    expect(m.containsKey('current'), isFalse);
    expect(m.containsKey('achieved'), isFalse);
    expect(m['target'], 80);
  });

  test('テスト勉強の ToDo が出る（小さな項目つき）', () {
    final list = mergeTodos(const [], [exam]);
    expect(list.single.title, '数学Ⅰ 後期期末試験の勉強');
    expect(
      list.single.subtasks.map((s) => s.title).toList(),
      studySubtaskPresets,
    );
  });

  test('「ToDo に出す」にしていないテストは出ない', () {
    final t = SchoolTest(
      id: 'x',
      kind: SchoolTestKind.quiz,
      title: '漢字テスト',
      date: DateTime(2027, 3, 1),
    );
    expect(mergeTodos(const [], [t]), isEmpty);
  });

  test('前回の成績のヒント', () {
    final exams = [
      Exam(
        title: '前期期末試験',
        date: DateTime(2026, 7, 10),
        entries: const [GradeEntry(subject: '数学Ⅰ', score: 70)],
      ),
      Exam(
        title: '後期中間試験',
        date: DateTime(2026, 11, 25),
        entries: const [
          GradeEntry(
            subject: '数学Ⅰ',
            score: 82,
            average: 65,
            deviation: 61,
            rank: 12,
          ),
        ],
      ),
    ];
    final last = latestGradeFor(exams, '数学Ⅰ')!;
    expect(
      gradeHintText(last.$1, last.$2),
      '前回 後期中間試験（11/25）82/100点・平均65・偏差値61・12位',
    );
    expect(latestGradeFor(exams, '化学基礎'), isNull);
  });
}
