/// 「がんばり」を数字で見える化する（ポイント・バッジ・連続記録）
///
/// 新しいデータは持たず、既存の ToDo（doneAt）から計算するだけ。
library;

import '../todo/todo.dart';

DateTime _day(DateTime d) => DateTime(d.year, d.month, d.day);

class Badge {
  const Badge(this.icon, this.label, this.description);
  final String icon;
  final String label;
  final String description;
}

class GamificationStats {
  const GamificationStats({
    required this.points,
    required this.completedCount,
    required this.onTimeCount,
    required this.currentStreak,
    required this.bestStreak,
    required this.badges,
    required this.nextBadge,
  });

  /// 合計ポイント
  final int points;

  /// 完了した ToDo の数
  final int completedCount;

  /// 期限内に完了した数
  final int onTimeCount;

  /// 今の連続達成日数（今日 or 昨日までに何か完了していれば継続中）
  final int currentStreak;

  /// これまでの最長連続記録
  final int bestStreak;

  /// 獲得したバッジ（新しい順）
  final List<Badge> badges;

  /// 次にもらえるバッジ（あと何回・何日で届くか）
  final String? nextBadge;
}

const _completionBadges = [
  (5, '🌱', 'はじめの一歩', '5個の ToDo を達成'),
  (20, '🔥', 'がんばり屋', '20個の ToDo を達成'),
  (50, '⭐', 'エキスパート', '50個の ToDo を達成'),
  (100, '👑', 'マスター', '100個の ToDo を達成'),
];

const _streakBadges = [
  (3, '☀️', '3日坊主卒業', '3日連続で達成'),
  (7, '📅', '1週間継続', '7日連続で達成'),
  (14, '💪', '2週間継続', '14日連続で達成'),
  (30, '🏆', '1か月継続', '30日連続で達成'),
];

/// ToDo の一覧から、ポイント・バッジ・連続記録を計算する
GamificationStats computeGamification(List<Todo> todos, {DateTime? now}) {
  final today = _day(now ?? DateTime.now());

  final done = [
    for (final t in todos)
      if (t.done && t.doneAt != null) t,
  ];

  final completedCount = done.length;
  final onTimeCount = done.where((t) => t.completedOnTime).length;
  final points = completedCount * 10 + onTimeCount * 5;

  // 完了した日の集合（連続記録の計算に使う）
  final doneDays = {for (final t in done) _day(t.doneAt!)};

  int streakFrom(DateTime start) {
    var streak = 0;
    var cursor = start;
    while (doneDays.contains(cursor)) {
      streak++;
      cursor = cursor.subtract(const Duration(days: 1));
    }
    return streak;
  }

  // 今日、まだ何も完了していなくても、昨日までの継続は切らさない
  final currentStreak = doneDays.contains(today)
      ? streakFrom(today)
      : streakFrom(today.subtract(const Duration(days: 1)));

  var bestStreak = 0;
  final sortedDays = doneDays.toList()..sort();
  DateTime? prev;
  var run = 0;
  for (final d in sortedDays) {
    if (prev != null && d.difference(prev).inDays == 1) {
      run++;
    } else {
      run = 1;
    }
    if (run > bestStreak) bestStreak = run;
    prev = d;
  }
  if (currentStreak > bestStreak) bestStreak = currentStreak;

  final badges = <Badge>[
    for (final b in _completionBadges)
      if (completedCount >= b.$1) Badge(b.$2, b.$3, b.$4),
    for (final b in _streakBadges)
      if (bestStreak >= b.$1) Badge(b.$2, b.$3, b.$4),
  ].reversed.toList();

  String? next;
  for (final b in _completionBadges) {
    if (completedCount < b.$1) {
      next = 'あと${b.$1 - completedCount}個で「${b.$3}」';
      break;
    }
  }
  if (next == null) {
    for (final b in _streakBadges) {
      if (bestStreak < b.$1) {
        next = 'あと${b.$1 - currentStreak}日連続で「${b.$3}」';
        break;
      }
    }
  }

  return GamificationStats(
    points: points,
    completedCount: completedCount,
    onTimeCount: onTimeCount,
    currentStreak: currentStreak,
    bestStreak: bestStreak,
    badges: badges,
    nextBadge: next,
  );
}
