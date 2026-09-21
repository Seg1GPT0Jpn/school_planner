/// 成長ログの保存・読み込み
library;

import 'package:cloud_firestore/cloud_firestore.dart';

import 'growth_log.dart';

class GrowthLogRepository {
  GrowthLogRepository({required this.uid, FirebaseFirestore? firestore})
    : _db = firestore ?? FirebaseFirestore.instance;

  final String uid;
  final FirebaseFirestore _db;

  CollectionReference<Map<String, dynamic>> get _logs =>
      _db.collection('users').doc(uid).collection('growth_logs');

  /// あるカテゴリの記録すべて（新しい順にするのは呼び出し側で）
  Stream<List<GrowthLogEntry>> watchForCategory(String categoryId) {
    return _logs
        .where('categoryId', isEqualTo: categoryId)
        .snapshots()
        .map((s) => [for (final d in s.docs) _fromMap(d.id, d.data())]);
  }

  /// もっとも新しい記録（無ければ null）
  Future<GrowthLogEntry?> latestForCategory(
    String categoryId, {
    String? excludeId,
  }) async {
    final snap = await _logs.where('categoryId', isEqualTo: categoryId).get();
    final list = [
      for (final d in snap.docs)
        if (d.id != excludeId) _fromMap(d.id, d.data()),
    ]..sort((a, b) => b.date.compareTo(a.date));
    return list.isEmpty ? null : list.first;
  }

  Future<String> save(GrowthLogEntry entry) async {
    final data = _toMap(entry);
    if (entry.id == null) {
      final ref = await _logs.add(data);
      return ref.id;
    } else {
      await _logs.doc(entry.id).set(data);
      return entry.id!;
    }
  }

  Future<void> delete(String id) => _logs.doc(id).delete();

  static Map<String, dynamic> _toMap(GrowthLogEntry e) => {
    'categoryId': e.categoryId,
    'eventId': e.eventId,
    'title': e.title,
    'date': Timestamp.fromDate(e.date),
    'minutes': e.minutes,
    'rating': e.rating,
    'note': e.note,
    'nextGoal': e.nextGoal,
  };

  static GrowthLogEntry _fromMap(String id, Map<String, dynamic> m) {
    return GrowthLogEntry(
      id: id,
      categoryId: m['categoryId'] as String? ?? '',
      eventId: m['eventId'] as String?,
      title: m['title'] as String? ?? '',
      date: (m['date'] as Timestamp?)?.toDate() ?? DateTime.now(),
      minutes: (m['minutes'] as num?)?.toInt() ?? 0,
      rating: (m['rating'] as num?)?.toInt(),
      note: m['note'] as String? ?? '',
      nextGoal: m['nextGoal'] as String? ?? '',
    );
  }
}
