/// 楽譜データの保存・読み込み（Firestore）
library;

import 'package:cloud_firestore/cloud_firestore.dart';

import 'model/score.dart';

class ScoreRepository {
  ScoreRepository({required this.uid, FirebaseFirestore? firestore})
    : _db = firestore ?? FirebaseFirestore.instance;

  final String uid;
  final FirebaseFirestore _db;

  CollectionReference<Map<String, dynamic>> get _scores =>
      _db.collection('users').doc(uid).collection('scores');

  /// 曲の一覧（新規作成画面用。中身の全データではなく一覧に必要な分だけ）
  Stream<List<Score>> watchAll() => _scores
      .orderBy('updatedAt', descending: true)
      .snapshots()
      .map(
        (s) => [
          for (final d in s.docs)
            Score.fromMap(
              d.id,
              d.data(),
              updatedAt: (d.data()['updatedAt'] as Timestamp?)?.toDate(),
            ),
        ],
      );

  /// 1曲ぶんを見張る（編集画面用）
  Stream<Score?> watch(String id) => _scores.doc(id).snapshots().map((d) {
    if (!d.exists) return null;
    final data = d.data();
    if (data == null) return null;
    return Score.fromMap(
      d.id,
      data,
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate(),
    );
  });

  /// 保存する（新しい曲なら追加、既存なら上書き）。保存した ID を返す
  Future<String> save(Score score) async {
    final data = {...score.toMap(), 'updatedAt': FieldValue.serverTimestamp()};
    if (score.id.isEmpty) {
      final ref = await _scores.add(data);
      return ref.id;
    }
    await _scores.doc(score.id).set(data, SetOptions(merge: false));
    return score.id;
  }

  Future<void> delete(String id) => _scores.doc(id).delete();
}
