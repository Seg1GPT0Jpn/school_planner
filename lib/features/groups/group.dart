/// グループ（部活・友達など、複数人で使う場所）のデータ
library;

/// グループ1件
class Group {
  const Group({
    required this.id,
    required this.name,
    required this.ownerUid,
    required this.memberUids,
    required this.inviteCode,
  });

  final String id;
  final String name;
  final String ownerUid;

  /// このグループに入っている人のID一覧
  final List<String> memberUids;

  /// ほかの人がこのグループに参加するための合言葉（英数字）
  final String inviteCode;

  bool isOwner(String uid) => ownerUid == uid;
  int get memberCount => memberUids.length;
}

/// グループ内の共有アイテムの種類
enum GroupItemType {
  /// お知らせ（連絡事項。チェックはない）
  announcement,

  /// 共有ToDo（チェックできる）
  todo,
}

/// グループ内の共有アイテム1件（お知らせ or 共有ToDo）
class GroupItem {
  const GroupItem({
    required this.id,
    required this.type,
    required this.text,
    required this.authorUid,
    this.authorName,
    this.done = false,
    this.createdAt,
  });

  final String id;
  final GroupItemType type;
  final String text;
  final String authorUid;
  final String? authorName;
  final bool done;
  final DateTime? createdAt;

  GroupItem copyWith({bool? done}) => GroupItem(
    id: id,
    type: type,
    text: text,
    authorUid: authorUid,
    authorName: authorName,
    done: done ?? this.done,
    createdAt: createdAt,
  );
}

/// 招待コードをランダムに作る（まぎらわしい文字は除く・6文字）
String generateInviteCode() {
  const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
  final rand = DateTime.now().microsecondsSinceEpoch;
  var seed = rand;
  final buffer = StringBuffer();
  for (var i = 0; i < 6; i++) {
    seed = (seed * 1103515245 + 12345) & 0x7fffffff;
    buffer.write(chars[seed % chars.length]);
  }
  return buffer.toString();
}
