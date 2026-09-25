/// 練習履歴：ロングトーン分析の結果を日付つきで保存し、時系列で比較できるようにする
library;

import 'package:cloud_firestore/cloud_firestore.dart';

class LongToneSessionRecord {
  const LongToneSessionRecord({
    required this.id,
    required this.date,
    required this.instrumentId,
    required this.pitchClass,
    required this.octave,
    required this.meanCents,
    required this.stabilityPercent,
    required this.holdSeconds,
  });

  final String id;
  final DateTime date;
  final String instrumentId;

  /// 0〜11（C=0）
  final int pitchClass;
  final int octave;

  final double meanCents;
  final double stabilityPercent;
  final double holdSeconds;
}

class PracticeHistoryRepository {
  PracticeHistoryRepository({required this.uid, FirebaseFirestore? firestore})
    : _db = firestore ?? FirebaseFirestore.instance;

  final String uid;
  final FirebaseFirestore _db;

  CollectionReference<Map<String, dynamic>> get _col =>
      _db.collection('users').doc(uid).collection('tuner_long_tone_history');

  Future<void> save(LongToneSessionRecord r) {
    return _col.doc(r.id).set({
      'date': Timestamp.fromDate(r.date),
      'instrumentId': r.instrumentId,
      'pitchClass': r.pitchClass,
      'octave': r.octave,
      'meanCents': r.meanCents,
      'stabilityPercent': r.stabilityPercent,
      'holdSeconds': r.holdSeconds,
    });
  }

  String newId() => _col.doc().id;

  /// 同じ楽器・同じ音の、これまでの記録を新しい順に見る（改善したかの比較用）
  Stream<List<LongToneSessionRecord>> watchFor({
    required String instrumentId,
    required int pitchClass,
    required int octave,
    int limit = 20,
  }) {
    return _col
        .where('instrumentId', isEqualTo: instrumentId)
        .where('pitchClass', isEqualTo: pitchClass)
        .where('octave', isEqualTo: octave)
        .orderBy('date', descending: true)
        .limit(limit)
        .snapshots()
        .map((snapshot) => [for (final doc in snapshot.docs) _fromDoc(doc)]);
  }

  /// 直近の練習記録（楽器を問わず、全体の履歴一覧用）
  Stream<List<LongToneSessionRecord>> watchRecent({int limit = 30}) {
    return _col
        .orderBy('date', descending: true)
        .limit(limit)
        .snapshots()
        .map((snapshot) => [for (final doc in snapshot.docs) _fromDoc(doc)]);
  }

  LongToneSessionRecord _fromDoc(QueryDocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data();
    return LongToneSessionRecord(
      id: doc.id,
      date: (d['date'] as Timestamp).toDate(),
      instrumentId: d['instrumentId'] as String? ?? '',
      pitchClass: (d['pitchClass'] as num?)?.toInt() ?? 0,
      octave: (d['octave'] as num?)?.toInt() ?? 4,
      meanCents: (d['meanCents'] as num?)?.toDouble() ?? 0,
      stabilityPercent: (d['stabilityPercent'] as num?)?.toDouble() ?? 0,
      holdSeconds: (d['holdSeconds'] as num?)?.toDouble() ?? 0,
    );
  }
}
