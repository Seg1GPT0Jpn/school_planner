/// グループの保存・読み込み
library;

import 'package:cloud_firestore/cloud_firestore.dart';

import 'group.dart';

class GroupRepository {
  GroupRepository({required this.uid, FirebaseFirestore? firestore})
    : _db = firestore ?? FirebaseFirestore.instance;

  final String uid;
  final FirebaseFirestore _db;

  CollectionReference<Map<String, dynamic>> get _groups =>
      _db.collection('groups');

  /// 自分が入っているグループ一覧
  Stream<List<Group>> watchMyGroups() {
    return _groups
        .where('memberUids', arrayContains: uid)
        .snapshots()
        .map((s) => [for (final d in s.docs) _fromMap(d.id, d.data())]);
  }

  Stream<Group?> watchGroup(String groupId) {
    return _groups.doc(groupId).snapshots().map(
      (d) => d.exists ? _fromMap(d.id, d.data()!) : null,
    );
  }

  /// 新しいグループを作る（自分がオーナー兼、最初のメンバー）
  Future<String> create(String name) async {
    final code = generateInviteCode();
    final ref = await _groups.add({
      'name': name.trim(),
      'ownerUid': uid,
      'memberUids': [uid],
      'inviteCode': code,
      'createdAt': FieldValue.serverTimestamp(),
    });
    return ref.id;
  }

  Future<void> rename(String groupId, String name) =>
      _groups.doc(groupId).update({'name': name.trim()});

  /// 招待コードでグループに参加する。見つからなければ null を返す
  Future<Group?> joinByCode(String code) async {
    final trimmed = code.trim().toUpperCase();
    if (trimmed.isEmpty) return null;
    final snap = await _groups
        .where('inviteCode', isEqualTo: trimmed)
        .limit(1)
        .get();
    if (snap.docs.isEmpty) return null;
    final doc = snap.docs.first;
    await doc.reference.update({
      'memberUids': FieldValue.arrayUnion([uid]),
    });
    final fresh = await doc.reference.get();
    return _fromMap(fresh.id, fresh.data()!);
  }

  /// グループから抜ける（オーナーは、先にオーナーを譲るか削除する必要あり）
  Future<void> leave(String groupId) => _groups.doc(groupId).update({
    'memberUids': FieldValue.arrayRemove([uid]),
  });

  Future<void> delete(String groupId) async {
    final items = await _groups.doc(groupId).collection('items').get();
    for (final d in items.docs) {
      await d.reference.delete();
    }
    await _groups.doc(groupId).delete();
  }

  // ── グループ内の共有アイテム（お知らせ・共有ToDo）──

  CollectionReference<Map<String, dynamic>> _items(String groupId) =>
      _groups.doc(groupId).collection('items');

  Stream<List<GroupItem>> watchItems(String groupId) {
    return _items(groupId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((s) => [for (final d in s.docs) _itemFromMap(d.id, d.data())]);
  }

  Future<void> addItem(
    String groupId, {
    required GroupItemType type,
    required String text,
    String? authorName,
  }) {
    return _items(groupId).add({
      'type': type.name,
      'text': text.trim(),
      'authorUid': uid,
      'authorName': authorName,
      'done': false,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> setItemDone(String groupId, String itemId, bool done) =>
      _items(groupId).doc(itemId).update({'done': done});

  Future<void> deleteItem(String groupId, String itemId) =>
      _items(groupId).doc(itemId).delete();

  static Group _fromMap(String id, Map<String, dynamic> m) => Group(
    id: id,
    name: m['name'] as String? ?? '',
    ownerUid: m['ownerUid'] as String? ?? '',
    memberUids: [
      for (final x in (m['memberUids'] as List<dynamic>? ?? const []))
        if (x is String) x,
    ],
    inviteCode: m['inviteCode'] as String? ?? '',
  );

  static GroupItem _itemFromMap(String id, Map<String, dynamic> m) =>
      GroupItem(
        id: id,
        type: GroupItemType.values.firstWhere(
          (t) => t.name == m['type'],
          orElse: () => GroupItemType.announcement,
        ),
        text: m['text'] as String? ?? '',
        authorUid: m['authorUid'] as String? ?? '',
        authorName: m['authorName'] as String?,
        done: m['done'] as bool? ?? false,
        createdAt: (m['createdAt'] as Timestamp?)?.toDate(),
      );
}
