/// 勉強時間の目標の進み具合を計算して保存する
library;

import 'package:cloud_firestore/cloud_firestore.dart';

import '../goals/goal.dart';
import '../goals/goal_repository.dart';
import 'study.dart';

/// その目標の「今」（時間・小数1桁）
double studyHoursFor(Goal g, List<StudySession> sessions) {
  final from = g.startDate == null
      ? DateTime(2000)
      : DateTime(g.startDate!.year, g.startDate!.month, g.startDate!.day);
  final to = g.dueDate == null
      ? DateTime(2100)
      : DateTime(g.dueDate!.year, g.dueDate!.month, g.dueDate!.day + 1);
  final m = totalMinutes(
    [
      for (final s in sessions)
        if (g.subject == null || s.subject == g.subject) s,
    ],
    from,
    to,
  );
  return (m / 6).round() / 10;
}

/// 勉強時間の目標をすべて計算し直して保存する
Future<void> recomputeStudyGoals(
  String uid, {
  FirebaseFirestore? firestore,
}) async {
  final db = firestore ?? FirebaseFirestore.instance;
  final user = db.collection('users').doc(uid);
  final goals = await user
      .collection('goals')
      .where('type', isEqualTo: GoalProgressType.studyTime.name)
      .get();
  if (goals.docs.isEmpty) return;

  final sessions = await user.collection('study_sessions').get();
  final list = [
    for (final d in sessions.docs)
      StudySession(
        subject: d.data()['subject'] as String?,
        start: (d.data()['start'] as Timestamp).toDate(),
        minutes: (d.data()['minutes'] as num).toInt(),
      ),
  ];

  final batch = db.batch();
  for (final d in goals.docs) {
    final g = GoalRepository.goalFromMap(d.id, d.data());
    batch.update(d.reference, {'current': studyHoursFor(g, list)});
  }
  await batch.commit();
}
