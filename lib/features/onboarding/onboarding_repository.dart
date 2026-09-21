/// 初回ログイン時の案内（オンボーディング）の進み具合の保存・読み込み
library;

import 'package:cloud_firestore/cloud_firestore.dart';

class OnboardingRepository {
  OnboardingRepository({required this.uid, FirebaseFirestore? firestore})
    : _db = firestore ?? FirebaseFirestore.instance;

  final String uid;
  final FirebaseFirestore _db;

  DocumentReference<Map<String, dynamic>> get _doc =>
      _db.collection('users').doc(uid).collection('settings').doc('onboarding');

  /// 案内の状態を見張る
  Stream<DocumentSnapshot<Map<String, dynamic>>> watch() => _doc.snapshots();

  Future<DocumentSnapshot<Map<String, dynamic>>> fetch() => _doc.get();

  /// 利用規約・プライバシーポリシーに同意した
  Future<void> markAgreed() => _doc.set({
    'tosAcceptedAt': FieldValue.serverTimestamp(),
    'privacyAcceptedAt': FieldValue.serverTimestamp(),
  }, SetOptions(merge: true));

  /// チュートリアルを終えた（スキップもふくむ）
  Future<void> markTutorialDone({required bool skipped}) => _doc.set({
    'tutorialCompletedAt': FieldValue.serverTimestamp(),
    'tutorialSkipped': skipped,
  }, SetOptions(merge: true));

  /// 案内をぜんぶ終えた（ホーム画面に進んでよい）
  Future<void> markCompleted() => _doc.set({
    'completedAt': FieldValue.serverTimestamp(),
  }, SetOptions(merge: true));

  /// 案内をやり直したいとき用（今は設定画面などからは呼んでいない）
  Future<void> reset() => _doc.delete();

  static bool isCompleted(Map<String, dynamic>? data) =>
      data != null && data['completedAt'] != null;

  /// 案内を作る前から使っていた人か（予定・ToDo・時間割のどれかが1件でもあるか）
  ///
  /// これが true の人には、あとから追加した案内（同意・時程ウィザードなど）を
  /// 今さら強制しない。ログインのたびに毎回この確認が走るわけではなく、
  /// 案内が「終わっていない」状態のときだけ呼ばれる。
  Future<bool> hasExistingData() async {
    final col = _db.collection('users').doc(uid);
    final results = await Future.wait([
      col.collection('events').limit(1).get(),
      col.collection('todos').limit(1).get(),
      col.collection('timetable_slots').limit(1).get(),
    ]);
    return results.any((s) => s.docs.isNotEmpty);
  }
}
