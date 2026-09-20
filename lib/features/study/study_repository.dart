/// 勉強時間とタイマーの保存
library;

import 'package:cloud_firestore/cloud_firestore.dart';

import 'pomodoro.dart';
import 'study.dart';
import 'study_goal.dart';

class RunningTimer {
  const RunningTimer(this.subject, this.startedAt, {this.pomodoro = false});
  final String? subject;
  final DateTime startedAt;

  /// ポモドーロ（25分集中＋5分休憩）で動いているか
  final bool pomodoro;
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

  Future<void> add(StudySession s) async {
    await _sessions.add({
      'subject': s.subject,
      'start': Timestamp.fromDate(s.start),
      'minutes': s.minutes,
      'memo': (s.memo?.trim().isEmpty ?? true) ? null : s.memo!.trim(),
    });
    await recomputeStudyGoals(uid, firestore: _db);
  }

  Future<void> delete(String id) async {
    await _sessions.doc(id).delete();
    await recomputeStudyGoals(uid, firestore: _db);
  }

  Stream<RunningTimer?> watchTimer() => _timer.snapshots().map((s) {
    final m = s.data();
    if (m == null || m['startedAt'] == null) return null;
    return RunningTimer(
      m['subject'] as String?,
      (m['startedAt'] as Timestamp).toDate(),
      pomodoro: m['pomodoro'] as bool? ?? false,
    );
  });

  /// タイマーを始める（始めた時刻を返す）
  Future<DateTime> startTimer(String? subject, {bool pomodoro = false}) async {
    final now = DateTime.now();
    await _timer.set({
      'subject': subject,
      'startedAt': Timestamp.fromDate(now),
      'pomodoro': pomodoro,
    });
    return now;
  }

  /// 止めて記録する（ポモドーロなら休憩の時間は数えない）
  Future<void> stopTimer(RunningTimer t) async {
    final elapsed = DateTime.now().difference(t.startedAt);
    final minutes = t.pomodoro
        ? pomodoroFocusMinutes(elapsed)
        : elapsed.inMinutes;
    if (minutes >= 1) {
      await add(
        StudySession(
          subject: t.subject,
          start: t.startedAt,
          minutes: minutes,
          memo: t.pomodoro ? 'ポモドーロ' : null,
        ),
      );
    }
    await _timer.delete();
  }

  Future<void> cancelTimer() => _timer.delete();
}
