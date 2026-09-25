/// 予定のカテゴリの保存・読み込み
library;

import 'package:cloud_firestore/cloud_firestore.dart';

import 'event_category.dart';

class EventCategoryRepository {
  EventCategoryRepository({required this.uid, FirebaseFirestore? firestore})
    : _db = firestore ?? FirebaseFirestore.instance;

  final String uid;
  final FirebaseFirestore _db;

  CollectionReference<Map<String, dynamic>> get _categories =>
      _db.collection('users').doc(uid).collection('event_categories');

  CollectionReference<Map<String, dynamic>> get _events =>
      _db.collection('users').doc(uid).collection('events');

  /// カテゴリを並び順どおりに見張る
  Stream<List<EventCategory>> watch() {
    return _categories.snapshots().map((snapshot) {
      final list = [
        for (final doc in snapshot.docs) _fromMap(doc.id, doc.data()),
      ]..sort((a, b) => a.order.compareTo(b.order));
      return list;
    });
  }

  /// カテゴリが1つもなければ、最初の既定カテゴリをすべて登録する。
  /// すでにカテゴリがある既存ユーザーには、あとから追加された既定カテゴリ
  /// （例：「テスト」）だけを補って追加する（他のカテゴリは変更しない）。
  Future<void> ensureDefaults() async {
    final existing = await _categories.limit(1).get();
    if (existing.docs.isEmpty) {
      final batch = _db.batch();
      for (final c in defaultEventCategories) {
        batch.set(_categories.doc(c.id), _toMap(c));
      }
      await batch.commit();
      return;
    }

    final missing = <EventCategory>[];
    for (final c in defaultEventCategories) {
      final doc = await _categories.doc(c.id).get();
      if (!doc.exists) missing.add(c);
    }
    if (missing.isEmpty) return;
    final batch = _db.batch();
    for (final c in missing) {
      batch.set(_categories.doc(c.id), _toMap(c));
    }
    await batch.commit();
  }

  /// 新しいカテゴリ用の ID を作る
  String newId() => _categories.doc().id;

  /// 保存する（追加・変更どちらも）
  Future<void> save(EventCategory category) {
    return _categories.doc(category.id).set(_toMap(category));
  }

  /// 並び順を保存する（渡された順番どおりに番号を振り直す）
  Future<void> reorder(List<EventCategory> ordered) async {
    final batch = _db.batch();
    for (var i = 0; i < ordered.length; i++) {
      batch.update(_categories.doc(ordered[i].id), {'order': i});
    }
    await batch.commit();
  }

  /// 削除する。このカテゴリの予定は「その他」に移す。
  Future<void> delete(String id) async {
    if (id == EventCategory.otherId) {
      throw ArgumentError('「その他」は削除できません');
    }

    // このカテゴリの予定を探す（新しい形・10-1 の古い形の両方）
    final byNewField = await _events.where('categoryId', isEqualTo: id).get();
    final byOldField = await _events.where('category', isEqualTo: id).get();

    final batch = _db.batch();
    for (final doc in [...byNewField.docs, ...byOldField.docs]) {
      batch.update(doc.reference, {'categoryId': EventCategory.otherId});
    }
    batch.delete(_categories.doc(id));
    await batch.commit();
  }

  static Map<String, dynamic> _toMap(EventCategory c) => {
    'name': c.name,
    'color': c.colorValue,
    'order': c.order,
    'growthLogEnabled': c.growthLogEnabled,
    'loadLevel': c.loadLevel.name,
  };

  static EventCategory _fromMap(String id, Map<String, dynamic> m) {
    return EventCategory(
      id: id,
      name: m['name'] as String? ?? '',
      colorValue: (m['color'] as num?)?.toInt() ?? 0xFF78909C,
      order: (m['order'] as num?)?.toInt() ?? 0,
      growthLogEnabled: m['growthLogEnabled'] as bool? ?? false,
      loadLevel:
          CategoryLoadLevel.values.asNameMap()[m['loadLevel']] ??
          CategoryLoadLevel.medium,
    );
  }
}
