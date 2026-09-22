/// 「今日のおすすめ」AI
///
/// 緊急度（締切までの日数）× 所要時間の目安 × 今日の忙しさ から、
/// 「今日やるとよいこと」を順番つきで組み立てる。外部APIは使わない。
library;

import '../todo/todo.dart';
import '../workload/workload.dart';

/// 優先度（🔴🟡🟢 の色分けに使う）
enum PlanPriority { high, medium, low }

DateTime _day(DateTime d) => DateTime(d.year, d.month, d.day);

/// 所要時間の目安（分）
///
/// 記録がないので、チェック項目の数や種類から見積もる。
/// これ自体は「学習」ではなく、あくまで最初のたたき台。
int estimateMinutes(Todo t) {
  if (t.subtasks.isNotEmpty) return (t.subtasks.length * 15).clamp(15, 120);
  if (t.isLinked) return 30; // テスト勉強・提出物
  return 20;
}

class PlanItem {
  const PlanItem({
    required this.todo,
    required this.minutes,
    required this.priority,
  });

  final Todo todo;
  final int minutes;
  final PlanPriority priority;
}

class TodayPlan {
  const TodayPlan({required this.items, required this.totalMinutes, this.note});

  final List<PlanItem> items;
  final int totalMinutes;

  /// 今日の忙しさなどをふまえた、ひとことアドバイス（なければ null）
  final String? note;
}

/// 今日やるとよい ToDo を選んで、優先度つきで並べる
///
/// 対象：未完了で、期限が「今日まで（期限切れふくむ）」〜「3日後まで」の ToDo。
/// [todayLoad] は今日の忙しさ（[computeWeekLoad] の1日目）。渡せば、
/// 忙しい日には絞り込みのアドバイスを添える。
TodayPlan buildTodayPlan({
  required DateTime now,
  required List<Todo> todos,
  DayLoad? todayLoad,
  int maxItems = 5,
  /// 見積もり分数の出し方を差し替える（学習した倍率を使うときなど）。
  /// 省略時は [estimateMinutes] をそのまま使う。
  int Function(Todo)? minutesOf,
}) {
  final estimate = minutesOf ?? estimateMinutes;
  final today = _day(now);
  final limit = today.add(const Duration(days: 3));

  PlanPriority priorityOf(Todo t) {
    final due = _day(t.dueDate!);
    if (!due.isAfter(today)) return PlanPriority.high; // 今日まで（期限切れふくむ）
    if (due == today.add(const Duration(days: 1))) return PlanPriority.medium;
    return PlanPriority.low;
  }

  final candidates =
      todos.where((t) => !t.done && t.dueDate != null).where((t) {
        final due = _day(t.dueDate!);
        return !due.isAfter(limit);
      }).toList()
        ..sort((a, b) {
          final pa = priorityOf(a).index, pb = priorityOf(b).index;
          if (pa != pb) return pa.compareTo(pb);
          return a.dueDate!.compareTo(b.dueDate!);
        });

  final chosen = candidates.take(maxItems).toList();
  final items = [
    for (final t in chosen)
      PlanItem(todo: t, minutes: estimate(t), priority: priorityOf(t)),
  ];
  final total = items.fold(0, (sum, i) => sum + i.minutes);

  String? note;
  if (items.isEmpty) {
    note = null;
  } else if (todayLoad != null && todayLoad.isHeavy) {
    note = '今日は予定が多い日です。まずは🔴の優先度が高いものだけに絞りましょう。';
  } else if (total >= 120) {
    note = '今日は少しボリュームがあります。休憩をはさみながら進めましょう。';
  }

  return TodayPlan(items: items, totalMinutes: total, note: note);
}
