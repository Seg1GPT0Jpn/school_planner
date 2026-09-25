/// メモ・ノートのデータと、画面に依存しない小さな処理
library;

class NoteFolder {
  const NoteFolder({required this.id, required this.name});
  final String id;
  final String name;
}

class Note {
  const Note({
    required this.id,
    required this.title,
    required this.body,
    this.folderId,
    this.tags = const [],
    this.favorite = false,
    required this.updatedAt,
  });

  final String id;
  final String title;

  /// Markdown（見出し・太字・箇条書き・チェックリストに対応）
  final String body;
  final String? folderId;
  final List<String> tags;
  final bool favorite;
  final DateTime updatedAt;

  Note copyWith({
    String? title,
    String? body,
    Object? folderId = _unset,
    List<String>? tags,
    bool? favorite,
  }) => Note(
    id: id,
    title: title ?? this.title,
    body: body ?? this.body,
    folderId: identical(folderId, _unset) ? this.folderId : folderId as String?,
    tags: tags ?? this.tags,
    favorite: favorite ?? this.favorite,
    updatedAt: updatedAt,
  );

  /// 一覧に出す、本文の最初の1行（プレビュー用）
  String get preview {
    for (final line in body.split('\n')) {
      final t = line.trim();
      if (t.isEmpty) continue;
      return t
          .replaceFirst(RegExp(r'^#+\s*'), '')
          .replaceFirst(RegExp(r'^[-*]\s(\[[ xX]\]\s?)?'), '')
          .replaceAll('**', '')
          .replaceAll('*', '');
    }
    return '';
  }
}

const _unset = Object();

/// タイトル・本文・タグのどこかに検索語が含まれるか
bool noteMatches(Note n, String query) {
  final q = query.trim().toLowerCase();
  if (q.isEmpty) return true;
  return n.title.toLowerCase().contains(q) ||
      n.body.toLowerCase().contains(q) ||
      n.tags.any((t) => t.toLowerCase().contains(q));
}

/// [lineIndex] 行目のチェックリストのチェックを切りかえた本文を返す
String toggleChecklistLine(String body, int lineIndex, bool checked) {
  final lines = body.split('\n');
  if (lineIndex < 0 || lineIndex >= lines.length) return body;
  lines[lineIndex] = lines[lineIndex].replaceFirst(
    RegExp(r'\[[ xX]\]'),
    checked ? '[x]' : '[ ]',
  );
  return lines.join('\n');
}

/// 新規メモのタイトル未入力時に、本文の1行目から仮タイトルを作る
String titleFromBody(String body) {
  for (final line in body.split('\n')) {
    final t = line.trim().replaceFirst(RegExp(r'^#+\s*'), '');
    if (t.isNotEmpty) return t.length > 30 ? '${t.substring(0, 30)}…' : t;
  }
  return '無題のメモ';
}
