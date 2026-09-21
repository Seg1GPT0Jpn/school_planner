/// レビュー・テストカルテ・学校イベントの保存と読み込み
///
/// 保存先（どれも users/{uid}/ の下なので、今のルールのまま使える）
/// - test_reviews/{テストの名前}：テストの点数とふり返り
/// - reviews/{期間の名前}：週・月・学期のふり返り
/// - event_links/{イベントの名前}：学校イベントに関係づける言葉
library;

import 'package:cloud_firestore/cloud_firestore.dart';

import '../goals/test_goal_link.dart';
import 'review_models.dart';

class ReviewRepository {
  ReviewRepository({required this.uid, FirebaseFirestore? firestore})
    : _db = firestore ?? FirebaseFirestore.instance;

  final String uid;
  final FirebaseFirestore _db;

  CollectionReference<Map<String, dynamic>> _col(String n) =>
      _db.collection('users').doc(uid).collection(n);

  // ───────── テストカルテ ─────────

  /// すべてのテストのふり返り（テストの名前 → 中身）
  Stream<Map<String, TestReview>> watchTestReviews() => _col('test_reviews')
      .snapshots()
      .map((s) => {for (final d in s.docs) d.id: TestReview.fromMap(d.data())});

  /// 保存する。手で登録したテストに目標点があれば、目標の「今の点数」も入れる
  Future<void> saveTestReview(
    String key,
    TestReview review, {
    String? testId,
    num? targetScore,
  }) async {
    await _col('test_reviews')
        .doc(key)
        .set({...review.toMap(), 'updatedAt': FieldValue.serverTimestamp()});
    if (testId != null && targetScore != null && review.score != null) {
      await _col('goals').doc(testGoalId(testId)).set({
        'current': review.score,
        'achieved': review.score! >= targetScore,
      }, SetOptions(merge: true));
    }
  }

  // ───────── 期間のふり返り ─────────

  Stream<String> watchPeriodNote(String key) =>
      _col('reviews')
          .doc(key)
          .snapshots()
          .map((s) => s.data()?['text'] as String? ?? '');

  Future<void> savePeriodNote(String key, String text) {
    final doc = _col('reviews').doc(key);
    if (text.trim().isEmpty) return doc.delete();
    return doc.set({
      'text': text.trim(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  // ───────── 学校イベント ─────────

  Stream<List<String>?> watchEventKeywords(String key) =>
      _col('event_links').doc(key).snapshots().map((s) {
        final v = s.data()?['keywords'];
        return v is List ? [for (final x in v) '$x'] : null;
      });

  Future<void> saveEventKeywords(String key, List<String> keywords) =>
      _col('event_links').doc(key).set({
        'keywords': keywords,
        'updatedAt': FieldValue.serverTimestamp(),
      });
}
