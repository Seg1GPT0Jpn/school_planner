/// 誕生日の保存・読み込み
library;

import 'package:cloud_firestore/cloud_firestore.dart';

import 'birthday.dart';

class BirthdayRepository {
  BirthdayRepository({required this.uid, FirebaseFirestore? firestore})
    : _db = firestore ?? FirebaseFirestore.instance;

  final String uid;
  final FirebaseFirestore _db;

  CollectionReference<Map<String, dynamic>> get _items =>
      _db.collection('users').doc(uid).collection('birthdays');

  Stream<List<Birthday>> watch() {
    return _items.snapshots().map(
      (s) => [for (final d in s.docs) _fromMap(d.id, d.data())],
    );
  }

  /// 保存して、保存した誕生日の ID を返す（新規でも既存でも）
  Future<String> save(Birthday b) async {
    final data = _toMap(b);
    if (b.id == null) {
      final ref = await _items.add(data);
      return ref.id;
    } else {
      await _items.doc(b.id).update(data);
      return b.id!;
    }
  }

  Future<void> delete(String id) => _items.doc(id).delete();

  static Map<String, dynamic> _toMap(Birthday b) => {
    'name': b.name.trim(),
    'month': b.month,
    'day': b.day,
    'year': b.year,
    'memo': (b.memo == null || b.memo!.trim().isEmpty) ? null : b.memo!.trim(),
  };

  static Birthday _fromMap(String id, Map<String, dynamic> m) => Birthday(
    id: id,
    name: m['name'] as String? ?? '',
    month: (m['month'] as num?)?.toInt() ?? 1,
    day: (m['day'] as num?)?.toInt() ?? 1,
    year: (m['year'] as num?)?.toInt(),
    memo: m['memo'] as String?,
  );
}
