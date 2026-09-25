/// 予定のカテゴリ（自分で追加・編集できる）
library;

/// カテゴリごとの「負荷（忙しさ）」のレベル
///
/// 予定の数だけで「詰め込みすぎ」を判定すると、軽い予定（例：買い物）が
/// 何件あっても、重い予定（例：定期テスト）が1件あるのと同じように
/// 扱われてしまう。カテゴリごとにこのレベルを選んでおくことで、
/// 負荷の計算（[weekLoadWarning] など）が実際の重さを反映できる。
enum CategoryLoadLevel {
  minimal(1, '最小'),
  low(2, '小'),
  medium(3, '中'),
  high(4, '高'),
  highest(5, '最高');

  const CategoryLoadLevel(this.weight, this.label);

  /// 負荷計算に使う重み（大きいほど重い）
  final int weight;

  /// 画面表示用の名前
  final String label;
}

class EventCategory {
  const EventCategory({
    required this.id,
    required this.name,
    required this.colorValue,
    this.order = 0,
    this.growthLogEnabled = false,
    this.loadLevel = CategoryLoadLevel.medium,
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

  /// このカテゴリの予定1件あたりの「負荷（忙しさ）」レベル
  final CategoryLoadLevel loadLevel;

  /// 「その他」の ID（削除できない）
  static const String otherId = 'other';

  /// 削除してよいカテゴリか
  bool get isDeletable => id != otherId;

  EventCategory copyWith({
    String? name,
    int? colorValue,
    int? order,
    bool? growthLogEnabled,
    CategoryLoadLevel? loadLevel,
  }) {
    return EventCategory(
      id: id,
      name: name ?? this.name,
      colorValue: colorValue ?? this.colorValue,
      order: order ?? this.order,
      growthLogEnabled: growthLogEnabled ?? this.growthLogEnabled,
      loadLevel: loadLevel ?? this.loadLevel,
    );
  }
}

/// 最初に用意するカテゴリ
const List<EventCategory> defaultEventCategories = [
  EventCategory(
    id: 'school',
    name: '学校',
    colorValue: 0xFF5C6BC0,
    order: 0,
  ),
  EventCategory(
    id: 'club',
    name: '部活',
    colorValue: 0xFFFB8C00,
    order: 1,
    loadLevel: CategoryLoadLevel.high,
  ),
  EventCategory(
    id: 'study',
    name: '勉強',
    colorValue: 0xFF43A047,
    order: 2,
  ),
  EventCategory(
    id: 'personal',
    name: '個人',
    colorValue: 0xFFF06292,
    order: 3,
    loadLevel: CategoryLoadLevel.low,
  ),
  EventCategory(
    id: 'important',
    name: '重要',
    colorValue: 0xFFE53935,
    order: 4,
    loadLevel: CategoryLoadLevel.highest,
  ),
  EventCategory(
    id: 'test',
    name: 'テスト',
    colorValue: 0xFF8E24AA,
    order: 5,
    loadLevel: CategoryLoadLevel.highest,
  ),
  EventCategory(
    id: 'other',
    name: 'その他',
    colorValue: 0xFF78909C,
    order: 6,
    loadLevel: CategoryLoadLevel.low,
  ),
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
