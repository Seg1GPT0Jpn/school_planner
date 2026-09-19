/// 目標とふり返りの保存・読み込み
library;

import 'package:cloud_firestore/cloud_firestore.dart';

import '../timetable/week_cycle.dart';
import 'goal.dart';

class Reflection {
  const Reflection(this.date, this.text);
  final DateTime date;
  final String text;
}

class GoalRepository {
  GoalRepository({required this.uid, FirebaseFirestore? firestore})
    : _db = firestore ?? FirebaseFirestore.instance;

  final String uid;
  final FirebaseFirestore _db;

  CollectionReference<Map<String, dynamic>> _col(String n) =>
      _db.collection('users').doc(uid).collection(n);

  static DateTime? _date(Object? v) {
    if (v is! String) return null;
    final p = v.split('-').map(int.parse).toList();
    return DateTime(p[0], p[1], p[2]);
  }

  // ---------------- 目標 ----------------

  Stream<List<Goal>> watchGoals() =>
      _col('goals')
          .snapshots()
          .map((s) => [for (final d in s.docs) goalFromMap(d.id, d.data())]);

  Future<void> saveGoal(Goal g) async {
    final data = goalToMap(g);
    if (g.id == null) {
      await _col('goals').add(data);
    } else {
      await _col('goals').doc(g.id).set(data);
    }
  }

  Future<void> deleteGoal(String id) => _col('goals').doc(id).delete();

  static Map<String, dynamic> goalToMap(Goal g) => {
    'title': g.title.trim(),
    'term': g.term.name,
    'dueDate': g.dueDate == null ? null : dateKey(g.dueDate!),
    'type': g.type.name,
    'current': g.current,
    'target': g.target,
    'unit': g.unit,
    'milestones': [
      for (final m in g.milestones) {'title': m.title, 'done': m.done},
    ],
    'achieved': g.achieved,
    'subject': g.subject,
    'memo': (g.memo?.trim().isEmpty ?? true) ? null : g.memo!.trim(),
  };

  static Goal goalFromMap(String id, Map<String, dynamic> m) => Goal(
    id: id,
    title: m['title'] as String? ?? '',
    term: GoalTerm.values.asNameMap()[m['term']] ?? GoalTerm.short,
    dueDate: _date(m['dueDate']),
    type:
        GoalProgressType.values.asNameMap()[m['type']] ?? GoalProgressType.none,
    current: m['current'] as num? ?? 0,
    target: m['target'] as num? ?? 100,
    unit: m['unit'] as String? ?? '',
    milestones: [
      for (final x in (m['milestones'] as List<dynamic>? ?? const []))
        Milestone(
          (x as Map)['title'] as String? ?? '',
          done: x['done'] as bool? ?? false,
        ),
    ],
    achieved: m['achieved'] as bool? ?? false,
    subject: m['subject'] as String?,
    memo: m['memo'] as String?,
  );

  // ---------------- ふり返り（1日1つ） ----------------

  Stream<List<Reflection>> watchReflections() =>
      _col('reflections').snapshots().map((s) {
        final list = [
          for (final d in s.docs)
            if (_date(d.id) != null)
              Reflection(_date(d.id)!, d.data()['text'] as String? ?? ''),
        ]..sort((a, b) => b.date.compareTo(a.date));
        return list;
      });

  Future<void> saveReflection(DateTime date, String text) {
    final doc = _col('reflections').doc(dateKey(date));
    if (text.trim().isEmpty) return doc.delete();
    return doc.set({
      'text': text.trim(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }
}
