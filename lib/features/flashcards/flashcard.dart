/// 暗記カード（単語帳・一問一答）のデータ
library;

/// 箱（Leitnerシステム）ごとの、次に復習するまでの日数
const List<int> flashcardBoxIntervalDays = [1, 2, 4, 7, 14];

/// カードの束（単語帳・科目など）
class FlashcardDeck {
  const FlashcardDeck({this.id, required this.name});

  final String? id;
  final String name;

  FlashcardDeck copyWith({String? name}) =>
      FlashcardDeck(id: id, name: name ?? this.name);
}

/// カード1枚（表と裏）
class Flashcard {
  const Flashcard({
    this.id,
    required this.front,
    required this.back,
    this.box = 1,
    this.nextReview,
  });

  final String? id;
  final String front;
  final String back;

  /// Leitnerの箱（1〜5。大きいほど覚えている）
  final int box;

  /// 次に復習する日（null なら「今すぐ」扱い＝新しいカード）
  final DateTime? nextReview;

  /// 今日、復習すべきか
  bool isDueOn(DateTime day) {
    if (nextReview == null) return true;
    final d = DateTime(day.year, day.month, day.day);
    final nr = DateTime(nextReview!.year, nextReview!.month, nextReview!.day);
    return !nr.isAfter(d);
  }

  /// 「できた」ときの次の状態
  Flashcard graded(bool correct, {DateTime? now}) {
    final today = now ?? DateTime.now();
    final newBox = correct ? (box + 1).clamp(1, flashcardBoxIntervalDays.length) : 1;
    final interval = flashcardBoxIntervalDays[newBox - 1];
    return Flashcard(
      id: id,
      front: front,
      back: back,
      box: newBox,
      nextReview: DateTime(today.year, today.month, today.day + interval),
    );
  }

  String? validate() {
    if (front.trim().isEmpty) return '表（問題）を入力してください';
    if (back.trim().isEmpty) return '裏（答え）を入力してください';
    return null;
  }
}
