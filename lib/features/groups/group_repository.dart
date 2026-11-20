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

  /// 招待コード（6文字）→ グループID の対応表
  /// まだメンバーでない人でも、コードさえ知っていればグループIDだけ引ける
  CollectionReference<Map<String, dynamic>> get _inviteCodes =>
      _db.collection('inviteCodes');

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
    await _inviteCodes.doc(code).set({'groupId': ref.id, 'ownerUid': uid});
    return ref.id;
  }

  Future<void> rename(String groupId, String name) =>
      _groups.doc(groupId).update({'name': name.trim()});

  /// 招待コードでグループに参加する。見つからなければ null を返す
  Future<Group?> joinByCode(String code) async {
    final trimmed = code.trim().toUpperCase();
    if (trimmed.isEmpty) return null;
    // まず対応表でグループIDを引く（メンバーでなくても読める場所）
    final codeDoc = await _inviteCodes.doc(trimmed).get();
    if (!codeDoc.exists) return null;
    final groupId = codeDoc.data()?['groupId'] as String?;
    if (groupId == null) return null;
    final ref = _groups.doc(groupId);
    // 自分を memberUids に加える（この更新自体は誰でもできる設計）
    await ref.update({
      'memberUids': FieldValue.arrayUnion([uid]),
    });
    // メンバーになった後なので、ここからは普通に読める
    final fresh = await ref.get();
    if (!fresh.exists) return null;
    return _fromMap(fresh.id, fresh.data()!);
  }

  /// 古いグループ（この仕組みより前に作られたもの）が、まだ対応表に
  /// 載っていなければ載せる。オーナー本人が開いたときに自動で呼ぶ想定
  Future<void> ensureInviteCodeIndexed(Group g) async {
    if (!g.isOwner(uid)) return;
    if (g.inviteCode.isEmpty) return;
    final doc = await _inviteCodes.doc(g.inviteCode).get();
    if (doc.exists) return;
    await _inviteCodes.doc(g.inviteCode).set({
      'groupId': g.id,
      'ownerUid': uid,
    });
  }

  /// グループから抜ける（オーナーは、先にオーナーを譲るか削除する必要あり）
  Future<void> leave(String groupId) => _groups.doc(groupId).update({
    'memberUids': FieldValue.arrayRemove([uid]),
  });

  Future<void> delete(String groupId) async {
    final doc = await _groups.doc(groupId).get();
    final code = doc.data()?['inviteCode'] as String?;
    final items = await _groups.doc(groupId).collection('items').get();
    for (final d in items.docs) {
      await d.reference.delete();
    }
    await _groups.doc(groupId).delete();
    if (code != null && code.isNotEmpty) {
      await _inviteCodes.doc(code).delete();
    }
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
