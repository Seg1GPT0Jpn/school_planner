/// 成績の保存
library;

import 'package:cloud_firestore/cloud_firestore.dart';

import '../timetable/week_cycle.dart';
import 'grade.dart';

class GradeRepository {
  GradeRepository({required this.uid, FirebaseFirestore? firestore})
    : _db = firestore ?? FirebaseFirestore.instance;

  final String uid;
  final FirebaseFirestore _db;

  CollectionReference<Map<String, dynamic>> get _col =>
      _db.collection('users').doc(uid).collection('exams');

  Stream<List<Exam>> watch() => _col.snapshots().map(
    (s) =>
        [for (final d in s.docs) fromMap(d.id, d.data())]
          ..sort((a, b) => b.date.compareTo(a.date)),
  );

  Future<void> save(Exam e) async {
    if (e.id == null) {
      await _col.add(toMap(e));
    } else {
      await _col.doc(e.id).set(toMap(e));
    }
  }

  Future<void> delete(String id) => _col.doc(id).delete();

  static Map<String, dynamic> toMap(Exam e) => {
    'title': e.title.trim(),
    'kind': e.kind.name,
    'date': dateKey(e.date),
    'totalRank': e.totalRank,
    'entries': [
      for (final x in e.entries)
        {
          'subject': x.subject,
          'score': x.score,
          'max': x.max,
          'average': x.average,
          'rank': x.rank,
        },
    ],
  };

  static Exam fromMap(String id, Map<String, dynamic> m) {
    final p = (m['date'] as String).split('-').map(int.parse).toList();
    return Exam(
      id: id,
      title: m['title'] as String? ?? '',
      kind: ExamKind.values.asNameMap()[m['kind']] ?? ExamKind.regular,
      date: DateTime(p[0], p[1], p[2]),
      totalRank: (m['totalRank'] as num?)?.toInt(),
      entries: [
        for (final x in (m['entries'] as List<dynamic>? ?? const []))
          GradeEntry(
            subject: (x as Map)['subject'] as String,
            score: x['score'] as num,
            max: x['max'] as num? ?? 100,
            average: x['average'] as num?,
            rank: (x['rank'] as num?)?.toInt(),
          ),
      ],
    );
  }
}
