import 'package:flutter_test/flutter_test.dart';
import 'package:school_planner/features/school_tests/school_test.dart';
import 'package:school_planner/features/todo/todo.dart';

void main() {
  final tests = [
    SchoolTest(
      id: 'a',
      kind: SchoolTestKind.assignment,
      title: 'プリント提出',
      subject: '数学Ⅰ',
      date: DateTime(2026, 9, 25),
    ),
    SchoolTest(
      id: 'q',
      kind: SchoolTestKind.quiz,
      title: '漢字テスト',
      date: DateTime(2026, 9, 24),
    ),
  ];

  test('提出物は ToDo に出るが、小テストは出ない', () {
    final list = mergeTodos(const [], tests);
    expect(list.length, 1);
    expect(list.single.title, '数学Ⅰ プリント提出');
    expect(list.single.isLinked, isTrue);
  });

  test('連動した ToDo の完了・チェック項目は保存したものを使う', () {
    final saved = Todo(
      id: linkedTodoId('a'),
      title: '',
      done: true,
      subtasks: const [Subtask('p.1', done: true), Subtask('p.2')],
      linkedTestId: 'a',
    );
    final t = mergeTodos([saved], tests).single;
    expect(t.done, isTrue);
    expect(t.progressText, '1/2');
  });

  test('期限が近い順、期限なしは最後', () {
    final sorted = sortTodos([
      const Todo(title: 'なし'),
      Todo(title: '後', dueDate: DateTime(2026, 10, 1)),
      Todo(title: '先', dueDate: DateTime(2026, 9, 20)),
    ]);
    expect(sorted.map((t) => t.title).toList(), ['先', '後', 'なし']);
  });

  test('期限切れの判定（完了したものは切れない）', () {
    final t = Todo(title: 'x', dueDate: DateTime(2026, 9, 18));
    expect(t.isOverdue(DateTime(2026, 9, 19)), isTrue);
    expect(t.copyWith(done: true).isOverdue(DateTime(2026, 9, 19)), isFalse);
  });
}
