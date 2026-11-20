/// メトロノームのプリセット（曲ごとの設定）をFirestoreに保存する
library;

import 'package:cloud_firestore/cloud_firestore.dart';

import 'preset.dart';

class MetronomePresetRepository {
  MetronomePresetRepository({required this.uid, FirebaseFirestore? firestore})
    : _db = firestore ?? FirebaseFirestore.instance;

  final String uid;
  final FirebaseFirestore _db;

  CollectionReference<Map<String, dynamic>> get _col =>
      _db.collection('users').doc(uid).collection('metronome_presets');

  String newId() => _col.doc().id;

  Future<void> save(MetronomePreset preset) {
    return _col.doc(preset.id).set({
      ...preset.toMap(),
      'updatedAt': Timestamp.now(),
    });
  }

  Future<void> delete(String id) => _col.doc(id).delete();

  Stream<List<MetronomePreset>> watchAll() {
    return _col.orderBy('updatedAt', descending: true).snapshots().map(
      (snapshot) => [
        for (final doc in snapshot.docs)
          MetronomePreset.fromMap(
            doc.id,
            doc.data(),
            (doc.data()['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
          ),
      ],
    );
  }
}
