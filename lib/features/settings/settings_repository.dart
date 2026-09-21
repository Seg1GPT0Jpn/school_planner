/// 設定の保存と読み出し（users/{uid}/settings/app）
library;

import 'package:cloud_firestore/cloud_firestore.dart';

import 'app_settings.dart';

class SettingsRepository {
  SettingsRepository({required this.uid});

  final String uid;

  DocumentReference<Map<String, dynamic>> get _doc => FirebaseFirestore.instance
      .collection('users')
      .doc(uid)
      .collection('settings')
      .doc('app');

  Stream<AppSettings> watch() =>
      _doc.snapshots().map((s) => AppSettings.fromMap(s.data()));

  Future<AppSettings> load() async =>
      AppSettings.fromMap((await _doc.get()).data());

  Future<void> save(AppSettings settings) =>
      _doc.set(settings.toMap(), SetOptions(merge: true));
}
