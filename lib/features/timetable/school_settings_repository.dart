/// 学校の設定（休業日・特別な日課）の保存
library;

import 'package:cloud_firestore/cloud_firestore.dart';

import 'school_periods.dart';
import 'timetable_models.dart';
import 'week_cycle.dart';

class SchoolSettingsRepository {
  SchoolSettingsRepository({required this.uid, FirebaseFirestore? firestore})
    : _db = firestore ?? FirebaseFirestore.instance;

  final String uid;
  final FirebaseFirestore _db;

  CollectionReference<Map<String, dynamic>> _col(String name) =>
      _db.collection('users').doc(uid).collection(name);

  /// 学校休業日を追加する
  Future<void> addClosure(SchoolClosure c) {
    return _col(
      'closures',
    ).add({'start': dateKey(c.start), 'end': dateKey(c.end), 'title': c.title});
  }

  /// 学校休業日を削除する（開始日と名前が同じものを消す）
  Future<void> deleteClosure(SchoolClosure c) async {
    final found = await _col('closures')
        .where('start', isEqualTo: dateKey(c.start))
        .where('title', isEqualTo: c.title)
        .get();
    for (final doc in found.docs) {
      await doc.reference.delete();
    }
  }

  /// その日の日課（短縮・試験）を設定する
  Future<void> setSchedule(DateTime date, DaySchedule schedule, String? note) {
    return _col('timetable_overrides').doc(dateKey(date)).set({
      'date': dateKey(date),
      'schedule': schedule.name,
      'note': (note == null || note.trim().isEmpty) ? null : note.trim(),
    }, SetOptions(merge: true));
  }

  /// その日の日課の設定をやめる（通常日課に戻す）
  Future<void> clearSchedule(DateTime date) async {
    final doc = _col('timetable_overrides').doc(dateKey(date));
    final snapshot = await doc.get();
    if (!snapshot.exists) return;

    final data = snapshot.data()!;
    final changes = data['changes'] as List<dynamic>? ?? const [];
    if (data['weekType'] == null && changes.isEmpty) {
      await doc.delete();
    } else {
      await doc.update({'schedule': null, 'note': null});
    }
  }
}
