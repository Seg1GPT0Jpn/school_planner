/// イントネーションマップ：楽器ごとに「どの音が高くなりやすいか」を積み上げる
///
/// ロングトーン分析を1回終えるたびに、その音の平均セントを記録していき、
/// 半音ごとの「平均・最大・最小・記録回数」を Firestore に貯めていく。
library;

import 'dart:math' as math;

import 'package:cloud_firestore/cloud_firestore.dart';

class NoteIntonationStat {
  const NoteIntonationStat({
    required this.pitchClass,
    required this.meanCents,
    required this.maxCents,
    required this.minCents,
    required this.sampleCount,
    required this.lastUpdated,
  });

  final int pitchClass;
  final double meanCents;
  final double maxCents;
  final double minCents;
  final int sampleCount;
  final DateTime lastUpdated;

  /// 記録回数が少ない（3回未満）うちは、まだ参考程度という扱いにする
  bool get isReliable => sampleCount >= 3;
}

class IntonationMapRepository {
  IntonationMapRepository({
    required this.uid,
    required this.instrumentId,
    FirebaseFirestore? firestore,
  }) : _db = firestore ?? FirebaseFirestore.instance;

  final String uid;
  final String instrumentId;
  final FirebaseFirestore _db;

  CollectionReference<Map<String, dynamic>> get _col => _db
      .collection('users')
      .doc(uid)
      .collection('tuner_intonation_map')
      .doc(instrumentId)
      .collection('notes');

  /// 半音ごとの統計を見張る（0〜11 の pitchClass をキーにした Map）
  Stream<Map<int, NoteIntonationStat>> watch() {
    return _col.snapshots().map((snapshot) {
      final map = <int, NoteIntonationStat>{};
      for (final doc in snapshot.docs) {
        final pc = int.tryParse(doc.id);
        if (pc == null) continue;
        final d = doc.data();
        map[pc] = NoteIntonationStat(
          pitchClass: pc,
          meanCents: (d['meanCents'] as num?)?.toDouble() ?? 0,
          maxCents: (d['maxCents'] as num?)?.toDouble() ?? 0,
          minCents: (d['minCents'] as num?)?.toDouble() ?? 0,
          sampleCount: (d['sampleCount'] as num?)?.toInt() ?? 0,
          lastUpdated: DateTime.fromMillisecondsSinceEpoch(
            (d['lastUpdated'] as num?)?.toInt() ??
                DateTime.now().millisecondsSinceEpoch,
          ),
        );
      }
      return map;
    });
  }

  /// この音の、新しい1回ぶんの平均セントを記録する（移動平均で積み上げる）
  Future<void> record(int pitchClass, double meanCents) async {
    final pc = ((pitchClass % 12) + 12) % 12;
    final docRef = _col.doc('$pc');
    await _db.runTransaction((tx) async {
      final snap = await tx.get(docRef);
      final now = DateTime.now().millisecondsSinceEpoch;
      if (!snap.exists) {
        tx.set(docRef, {
          'meanCents': meanCents,
          'maxCents': meanCents,
          'minCents': meanCents,
          'sampleCount': 1,
          'lastUpdated': now,
        });
        return;
      }
      final d = snap.data()!;
      final count = (d['sampleCount'] as num?)?.toInt() ?? 0;
      final prevMean = (d['meanCents'] as num?)?.toDouble() ?? 0;
      final newCount = count + 1;
      final newMean = (prevMean * count + meanCents) / newCount;
      tx.update(docRef, {
        'meanCents': newMean,
        'maxCents': math.max((d['maxCents'] as num?)?.toDouble() ?? meanCents, meanCents),
        'minCents': math.min((d['minCents'] as num?)?.toDouble() ?? meanCents, meanCents),
        'sampleCount': newCount,
        'lastUpdated': now,
      });
    });
  }
}
