/// テスト目標（定期テスト・模試ぜんたいの目標）の保存・読み込み
library;

import 'package:cloud_firestore/cloud_firestore.dart';

import '../timetable/week_cycle.dart';
import 'exam_goal.dart';

class ExamGoalRepository {
  ExamGoalRepository({required this.uid, FirebaseFirestore? firestore})
    : _db = firestore ?? FirebaseFirestore.instance;

  final String uid;
  final FirebaseFirestore _db;

  CollectionReference<Map<String, dynamic>> get _col =>
      _db.collection('users').doc(uid).collection('exam_goals');

  static DateTime? _date(Object? v) {
    if (v is! String) return null;
    final p = v.split('-').map(int.parse).toList();
    return DateTime(p[0], p[1], p[2]);
  }

  Stream<List<ExamGoal>> watch() => _col.snapshots().map(
    (s) => [for (final d in s.docs) fromMap(d.id, d.data())],
  );

  Future<String> save(ExamGoal g) async {
    final data = toMap(g);
    if (g.id == null) {
      final doc = await _col.add(data);
      return doc.id;
    }
    await _col.doc(g.id).set(data);
    return g.id!;
  }

  Future<void> delete(String id) => _col.doc(id).delete();

  static Map<String, dynamic> toMap(ExamGoal g) => {
    'title': g.title.trim(),
    'kind': g.kind.name,
    'examDate': g.examDate == null ? null : dateKey(g.examDate!),
    'examEndDate': g.examEndDate == null ? null : dateKey(g.examEndDate!),
    'subjects': [for (final s in g.subjects) s.toMap()],
    'memo': (g.memo?.trim().isEmpty ?? true) ? null : g.memo!.trim(),
  };

  static ExamGoal fromMap(String id, Map<String, dynamic> m) => ExamGoal(
    id: id,
    title: m['title'] as String? ?? '',
    kind:
        ExamGoalKind.values.asNameMap()[m['kind']] ??
        ExamGoalKind.regularExam,
    examDate: _date(m['examDate']),
    examEndDate: _date(m['examEndDate']),
    subjects: [
      for (final x in (m['subjects'] as List<dynamic>? ?? const []))
        ExamSubjectGoal.fromMap(Map<String, dynamic>.from(x as Map)),
    ],
    memo: m['memo'] as String?,
  );
}
