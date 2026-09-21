/// ToDo の保存・読み込み
library;

import 'package:cloud_firestore/cloud_firestore.dart';

import '../timetable/week_cycle.dart';
import 'todo.dart';

class TodoRepository {
  TodoRepository({required this.uid, FirebaseFirestore? firestore})
    : _db = firestore ?? FirebaseFirestore.instance;

  final String uid;
  final FirebaseFirestore _db;

  CollectionReference<Map<String, dynamic>> get _col =>
      _db.collection('users').doc(uid).collection('todos');

  Stream<List<Todo>> watch() => _col.snapshots().map(
    (s) => [for (final d in s.docs) fromMap(d.id, d.data())],
  );

  Future<void> save(Todo t) async {
    if (t.id == null) {
      await _col.add(toMap(t));
    } else {
      await _col.doc(t.id).set(toMap(t));
    }
  }

  Future<void> delete(String id) => _col.doc(id).delete();

  static Map<String, dynamic> toMap(Todo t) => {
    'title': t.title.trim(),
    'dueDate': t.dueDate == null ? null : dateKey(t.dueDate!),
    'subject': t.subject,
    'memo': (t.memo?.trim().isEmpty ?? true) ? null : t.memo!.trim(),
    'done': t.done,
    'doneAt': t.doneAt == null ? null : Timestamp.fromDate(t.doneAt!),
    'subtasks': [
      for (final s in t.subtasks) {'title': s.title, 'done': s.done},
    ],
    'linkedTestId': t.linkedTestId,
  };

  static Todo fromMap(String id, Map<String, dynamic> m) {
    DateTime? due;
    if (m['dueDate'] is String) {
      final p = (m['dueDate'] as String).split('-').map(int.parse).toList();
      due = DateTime(p[0], p[1], p[2]);
    }
    return Todo(
      id: id,
      title: m['title'] as String? ?? '',
      dueDate: due,
      subject: m['subject'] as String?,
      memo: m['memo'] as String?,
      done: m['done'] as bool? ?? false,
      doneAt: (m['doneAt'] as Timestamp?)?.toDate(),
      subtasks: [
        for (final s in (m['subtasks'] as List<dynamic>? ?? const []))
          Subtask(
            (s as Map)['title'] as String? ?? '',
            done: s['done'] as bool? ?? false,
          ),
      ],
      linkedTestId: m['linkedTestId'] as String?,
    );
  }
}
