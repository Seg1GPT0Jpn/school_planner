/// タイマー・お休み時間などの既定値の保存（users/{uid}/settings/clock）
library;

import 'package:cloud_firestore/cloud_firestore.dart';

import 'clock_models.dart';

class ClockSettingsRepository {
  ClockSettingsRepository({required this.uid});

  final String uid;

  DocumentReference<Map<String, dynamic>> get _doc => FirebaseFirestore.instance
      .collection('users')
      .doc(uid)
      .collection('settings')
      .doc('clock');

  Stream<ClockSettings> watch() =>
      _doc.snapshots().map((s) => ClockSettings.fromMap(s.data()));

  Future<ClockSettings> load() async =>
      ClockSettings.fromMap((await _doc.get()).data());

  Future<void> save(ClockSettings settings) =>
      _doc.set(settings.toMap(), SetOptions(merge: true));
}
