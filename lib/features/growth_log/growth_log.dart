/// 成長ログ（部活・趣味などの練習記録）のデータ
library;

/// 1回ぶんの記録
class GrowthLogEntry {
  const GrowthLogEntry({
    this.id,
    required this.categoryId,
    this.eventId,
    required this.title,
    required this.date,
    this.minutes = 0,
    this.rating,
    this.note = '',
    this.nextGoal = '',
  });

  /// Firestore の ID（まだ保存していないときは null）
  final String? id;

  /// カテゴリ（部活・趣味など）の ID
  final String categoryId;

  /// もとになった予定の ID（予定からではなく、直接追加したときは null）
  final String? eventId;

  final String title;
  final DateTime date;

  /// かけた時間（分）
  final int minutes;

  /// 自己評価（1〜5。つけないときは null）
  final int? rating;

  final String note;

  /// 次に向けての目標・ひとこと
  final String nextGoal;

  GrowthLogEntry copyWith({
    String? title,
    DateTime? date,
    int? minutes,
    int? rating,
    bool clearRating = false,
    String? note,
    String? nextGoal,
  }) => GrowthLogEntry(
    id: id,
    categoryId: categoryId,
    eventId: eventId,
    title: title ?? this.title,
    date: date ?? this.date,
    minutes: minutes ?? this.minutes,
    rating: clearRating ? null : (rating ?? this.rating),
    note: note ?? this.note,
    nextGoal: nextGoal ?? this.nextGoal,
  );
}
