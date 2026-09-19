/// ToDo（やること）
library;

import '../school_tests/school_test.dart';

DateTime _day(DateTime d) => DateTime(d.year, d.month, d.day);

/// 小さなチェック項目
class Subtask {
  const Subtask(this.title, {this.done = false});
  final String title;
  final bool done;
}

class Todo {
  const Todo({
    this.id,
    required this.title,
    this.dueDate,
    this.subject,
    this.memo,
    this.done = false,
    this.subtasks = const [],
    this.linkedTestId,
  });

  final String? id;
  final String title;
  final DateTime? dueDate;
  final String? subject;
  final String? memo;
  final bool done;
  final List<Subtask> subtasks;

  /// 提出物などから自動で作られたものなら、その元の ID
  final String? linkedTestId;

  bool get isLinked => linkedTestId != null;

  /// 期限切れか
  bool isOverdue(DateTime today) =>
      !done && dueDate != null && _day(dueDate!).isBefore(_day(today));

  /// 小さなチェック項目の進み具合（例：1/3）。項目がなければ null
  String? get progressText => subtasks.isEmpty
      ? null
      : '${subtasks.where((s) => s.done).length}/${subtasks.length}';

  Todo copyWith({bool? done, List<Subtask>? subtasks, String? memo}) => Todo(
    id: id,
    title: title,
    dueDate: dueDate,
    subject: subject,
    memo: memo ?? this.memo,
    done: done ?? this.done,
    subtasks: subtasks ?? this.subtasks,
    linkedTestId: linkedTestId,
  );
}

/// ToDo に自動で出す種類
const Set<SchoolTestKind> todoKinds = {
  SchoolTestKind.assignment,
  SchoolTestKind.homework,
  SchoolTestKind.report,
};

String linkedTodoId(String testId) => 'test_$testId';

/// 自分で作った ToDo と、提出物などから作る ToDo をまとめる
List<Todo> mergeTodos(List<Todo> own, List<SchoolTest> tests) {
  final saved = {
    for (final t in own)
      if (t.id != null) t.id!: t,
  };
  return [
    for (final t in own)
      if (!t.isLinked) t,
    for (final test in tests)
      if (test.id != null && todoKinds.contains(test.kind))
        () {
          final s = saved[linkedTodoId(test.id!)];
          return Todo(
            id: linkedTodoId(test.id!),
            title: test.displayTitle,
            dueDate: test.date,
            subject: test.subject,
            memo: s?.memo ?? test.memo,
            done: s?.done ?? false,
            subtasks: s?.subtasks ?? const [],
            linkedTestId: test.id,
          );
        }(),
  ];
}

/// 期限が近い順（期限なしは最後）
List<Todo> sortTodos(List<Todo> list) => [...list]
  ..sort((a, b) {
    if (a.dueDate == null && b.dueDate == null) {
      return a.title.compareTo(b.title);
    }
    if (a.dueDate == null) return 1;
    if (b.dueDate == null) return -1;
    return a.dueDate!.compareTo(b.dueDate!);
  });
