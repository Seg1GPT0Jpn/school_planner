/// テストに入れた「目標点」から、目標を自動で作る
library;

import 'package:cloud_firestore/cloud_firestore.dart';

import '../school_tests/school_test.dart';
import 'goal.dart';
import 'goal_repository.dart';

/// テストから作る目標の ID（テスト1つにつき目標1つ）
String testGoalId(String testId) => 'test_$testId';

String _n(num v) => v == v.roundToDouble() ? '${v.toInt()}' : '$v';

/// テストから作る目標（例：数学Ⅰ 後期期末試験で80点）
Goal goalForTest(SchoolTest t) => Goal(
  id: testGoalId(t.id!),
  title: '${t.displayTitle}で${_n(t.targetScore!)}点',
  term: GoalTerm.short,
  dueDate: t.date,
  type: GoalProgressType.number,
  target: t.targetScore!,
  unit: '点',
  subject: t.subject,
);

/// 目標を作る・直す（目標点が空なら消す）
///
/// 「今の点数」「達成」など、あとから自分で入れたものは上書きしない。
Future<void> syncTestGoal(
  String uid,
  SchoolTest t, {
  FirebaseFirestore? firestore,
}) async {
  if (t.id == null) return;
  final db = firestore ?? FirebaseFirestore.instance;
  final doc = db
      .collection('users')
      .doc(uid)
      .collection('goals')
      .doc(testGoalId(t.id!));
  if (t.targetScore == null || !t.kind.isTest) {
    await doc.delete();
    return;
  }
  await doc.set(testGoalFields(t), SetOptions(merge: true));
}

/// 保存する項目（今の点数・達成・メモなどは含めない）
Map<String, dynamic> testGoalFields(SchoolTest t) =>
    GoalRepository.goalToMap(goalForTest(t))
      ..remove('current')
      ..remove('achieved')
      ..remove('milestones')
      ..remove('memo');

/// テストを消したときに、目標も消す
Future<void> deleteTestGoal(
  String uid,
  String testId, {
  FirebaseFirestore? firestore,
}) => (firestore ?? FirebaseFirestore.instance)
    .collection('users')
    .doc(uid)
    .collection('goals')
    .doc(testGoalId(testId))
    .delete();
