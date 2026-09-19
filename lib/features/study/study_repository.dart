/// 勉強時間とタイマーの保存
library;

import 'package:cloud_firestore/cloud_firestore.dart';

import 'study.dart';

/// 動いているタイマー
class RunningTimer {
  const RunningTimer(this.subject, this.startedAt);
  final String? subject;
  final DateTime startedAt;
}

class StudyRepository {
  StudyRepository({required this.uid, FirebaseFirestore? firestore})
    : _db = firestore ?? FirebaseFirestore.instance;

  final String uid;
  final FirebaseFirestore _db;

  CollectionReference<Map<String, dynamic>> get _sessions =>
      _db.collection('users').doc(uid).collection('study_sessions');

  DocumentReference<Map<String, dynamic>> get _timer => _db
      .collection('users')
      .doc(uid)
      .collection('settings')
      .doc('study_timer');

  Stream<List<StudySession>> watchSessions() => _sessions.snapshots().map(
    (s) => [
      for (final d in s.docs)
        StudySession(
          id: d.id,
          subject: d.data()['subject'] as String?,
          start: (d.data()['start'] as Timestamp).toDate(),
          minutes: (d.data()['minutes'] as num).toInt(),
          memo: d.data()['memo'] as String?,
        ),
    ]..sort((a, b) => b.start.compareTo(a.start)),
  );

  Future<void> add(StudySession s) => _sessions.add({
    'subject': s.subject,
    'start': Timestamp.fromDate(s.start),
    'minutes': s.minutes,
    'memo': (s.memo?.trim().isEmpty ?? true) ? null : s.memo!.trim(),
  });

  Future<void> delete(String id) => _sessions.doc(id).delete();

  // ---------------- タイマー ----------------

  Stream<RunningTimer?> watchTimer() => _timer.snapshots().map((s) {
    final m = s.data();
    if (m == null || m['startedAt'] == null) return null;
    return RunningTimer(
      m['subject'] as String?,
      (m['startedAt'] as Timestamp).toDate(),
    );
  });

  Future<void> startTimer(String? subject) => _timer.set({
    'subject': subject,
    'startedAt': Timestamp.fromDate(DateTime.now()),
  });

  /// 止めて記録する（1分未満は記録しない）
  Future<void> stopTimer(RunningTimer t) async {
    final minutes = DateTime.now().difference(t.startedAt).inMinutes;
    if (minutes >= 1) {
      await add(
        StudySession(subject: t.subject, start: t.startedAt, minutes: minutes),
      );
    }
    await _timer.delete();
  }

  Future<void> cancelTimer() => _timer.delete();
}
