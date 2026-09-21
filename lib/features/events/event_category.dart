/// 予定のカテゴリ（自分で追加・編集できる）
library;

class EventCategory {
  const EventCategory({
    required this.id,
    required this.name,
    required this.colorValue,
    this.order = 0,
    this.growthLogEnabled = false,
  });

  /// Firestore の ID
  final String id;

  /// 表示する名前（例：部活）
  final String name;

  /// 色（0xFFRRGGBB の形の数値）
  final int colorValue;

  /// 並び順（小さいほど前）
  final int order;

  /// このカテゴリの予定で「成長ログ」（練習記録など）を使うか
  final bool growthLogEnabled;

  /// 「その他」の ID（削除できない）
  static const String otherId = 'other';

  /// 削除してよいカテゴリか
  bool get isDeletable => id != otherId;

  EventCategory copyWith({
    String? name,
    int? colorValue,
    int? order,
    bool? growthLogEnabled,
  }) {
    return EventCategory(
      id: id,
      name: name ?? this.name,
      colorValue: colorValue ?? this.colorValue,
      order: order ?? this.order,
      growthLogEnabled: growthLogEnabled ?? this.growthLogEnabled,
    );
  }
}

/// 最初に用意するカテゴリ
const List<EventCategory> defaultEventCategories = [
  EventCategory(id: 'school', name: '学校', colorValue: 0xFF5C6BC0, order: 0),
  EventCategory(id: 'club', name: '部活', colorValue: 0xFFFB8C00, order: 1),
  EventCategory(id: 'study', name: '勉強', colorValue: 0xFF43A047, order: 2),
  EventCategory(id: 'personal', name: '個人', colorValue: 0xFFF06292, order: 3),
  EventCategory(id: 'important', name: '重要', colorValue: 0xFFE53935, order: 4),
  EventCategory(id: 'other', name: 'その他', colorValue: 0xFF78909C, order: 5),
];

/// ID からカテゴリを探す（見つからなければ「その他」）
EventCategory findCategory(List<EventCategory> categories, String id) {
  for (final c in categories) {
    if (c.id == id) return c;
  }
  for (final c in categories) {
    if (c.id == EventCategory.otherId) return c;
  }
  return defaultEventCategories.last;
}
