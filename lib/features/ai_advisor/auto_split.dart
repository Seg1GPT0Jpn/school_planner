/// 「自動分割」AI
///
/// 締切のある大きめの ToDo を、今日から締切前日までの日に、
/// 忙しい日をさけながら分数で振り分ける。表示するだけで、
/// ToDo やカレンダーには書き込まない（プレビュー専用・安全設計）。
library;

import '../todo/todo.dart';
import '../workload/workload.dart';
import 'today_plan.dart';

DateTime _day(DateTime d) => DateTime(d.year, d.month, d.day);

/// 「分割したほうがよさそう」とみなす目安（分）
const autoSplitThresholdMinutes = 90;

class SplitDay {
  const SplitDay({required this.date, required this.minutes});
  final DateTime date;
  final int minutes;
}

/// 見積もりが大きく、締切が2日以上先にある ToDo を「分割候補」として拾う
List<Todo> findSplitCandidates(List<Todo> todos, DateTime now) {
  final today = _day(now);
  return todos.where((t) {
    if (t.done || t.dueDate == null) return false;
    final due = _day(t.dueDate!);
    if (due.difference(today).inDays < 2) return false;
    return estimateMinutes(t) >= autoSplitThresholdMinutes;
  }).toList();
}

/// [totalMinutes] を、[from]（今日）から [dueDate] の前日までの日に振り分ける。
/// [heavyDays] に入っている日は、忙しいとみなして少なめにする。
List<SplitDay> splitWorkload({
  required DateTime from,
  required DateTime dueDate,
  required int totalMinutes,
  Set<DateTime> heavyDays = const {},
}) {
  final start = _day(from);
  final due = _day(dueDate);

  final days = <DateTime>[];
  for (var d = start; d.isBefore(due); d = d.add(const Duration(days: 1))) {
    days.add(d);
  }
  if (days.isEmpty) return [SplitDay(date: start, minutes: totalMinutes)];

  final weights = [for (final d in days) heavyDays.contains(d) ? 0.5 : 1.0];
  final weightSum = weights.fold(0.0, (s, w) => s + w);

  final result = <SplitDay>[];
  var assigned = 0;
  for (var i = 0; i < days.length; i++) {
    final isLast = i == days.length - 1;
    final minutes = isLast
        ? (totalMinutes - assigned).clamp(0, totalMinutes)
        : (totalMinutes * weights[i] / weightSum).round();
    result.add(SplitDay(date: days[i], minutes: minutes));
    assigned += minutes;
  }
  return result;
}

/// [weekLoad] から「忙しい日」の集合を作る（分割の重みづけに使う）
Set<DateTime> heavyDaysFrom(List<DayLoad> weekLoad) => {
  for (final d in weekLoad)
    if (d.isHeavy) _day(d.day),
};
