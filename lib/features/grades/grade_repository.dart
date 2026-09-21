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

  DocumentReference<Map<String, dynamic>> get _user =>
      _db.collection('users').doc(uid);

  CollectionReference<Map<String, dynamic>> get _col =>
      _user.collection('exams');

  /// 目標ライン（settings/grade_targets）
  DocumentReference<Map<String, dynamic>> get _targetsDoc =>
      _user.collection('settings').doc('grade_targets');

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

  // ---------------- 目標ライン ----------------

  Stream<Map<String, GradeTarget>> watchTargets() =>
      _targetsDoc.snapshots().map((s) => targetsFromMap(s.data()));

  /// ひとつの科目の目標ラインを保存（空なら消す）
  Future<void> saveTarget(
    Map<String, GradeTarget> current,
    String key,
    GradeTarget target,
  ) {
    final next = {...current};
    if (target.isEmpty) {
      next.remove(key);
    } else {
      next[key] = target;
    }
    return _targetsDoc.set(targetsToMap(next));
  }

  // ---------------- 変換 ----------------

  static Map<String, dynamic> toMap(Exam e) => {
    'title': e.title.trim(),
    'kind': e.kind.name,
    'date': dateKey(e.date),
    'totalRank': e.totalRank,
    // 自動で計算した偏差値は保存しない（元の数字からいつでも計算し直す）
    'totalDeviation': e.totalDeviationSource == DeviationSource.entered
        ? e.totalDeviation
        : null,
    'participants': e.participants,
    'entries': [
      for (final x in e.entries)
        {
          'subject': x.subject,
          'score': x.score,
          'max': x.max,
          'average': x.average,
          'rank': x.rank,
          'deviation': x.deviationSource == DeviationSource.entered
              ? x.deviation
              : null,
          'stdDev': x.stdDev,
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
      totalDeviation: m['totalDeviation'] as num?,
      participants: (m['participants'] as num?)?.toInt(),
      entries: [
        for (final x in (m['entries'] as List<dynamic>? ?? const []))
          GradeEntry(
            subject: (x as Map)['subject'] as String,
            score: x['score'] as num,
            max: x['max'] as num? ?? 100,
            average: x['average'] as num?,
            rank: (x['rank'] as num?)?.toInt(),
            deviation: x['deviation'] as num?,
            stdDev: x['stdDev'] as num?,
          ),
      ],
    ).withAutoDeviations();
  }

  static Map<String, dynamic> targetsToMap(Map<String, GradeTarget> t) => {
    'targets': {
      for (final e in t.entries)
        e.key: {
          'score': e.value.score,
          'deviation': e.value.deviation,
          'rank': e.value.rank,
        },
    },
  };

  static Map<String, GradeTarget> targetsFromMap(Map<String, dynamic>? m) {
    final raw = m?['targets'] as Map<String, dynamic>? ?? const {};
    return {
      for (final e in raw.entries)
        e.key: GradeTarget(
          score: (e.value as Map)['score'] as num?,
          deviation: e.value['deviation'] as num?,
          rank: (e.value['rank'] as num?)?.toInt(),
        ),
    };
  }
}
