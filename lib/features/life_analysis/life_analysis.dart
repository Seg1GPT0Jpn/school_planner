/// 生活分析 ― 今月のデータをふり返る（すべて端末内で計算、外部AIは使わない）
///
/// 文章のまとめ部分だけ、設定でONのときに生成AI（Gemini）を使う
/// （life_analysis_page.dart 側で ai_advisor/gemini_advisor.dart を呼ぶ）。
library;

import '../events/calendar_event.dart';
import '../study/study.dart';
import '../todo/todo.dart';

DateTime _day(DateTime d) => DateTime(d.year, d.month, d.day);

/// 予定1件の、指定した日にかかる分数（日をまたぐ予定は、その日の分だけ）
int _minutesOnDay(CalendarEvent e, DateTime day) {
  final dayStart = DateTime(day.year, day.month, day.day);
  final dayEnd = dayStart.add(const Duration(days: 1));
  final s = e.start.isBefore(dayStart) ? dayStart : e.start;
  final en = e.end.isAfter(dayEnd) ? dayEnd : e.end;
  final diff = en.difference(s).inMinutes;
  return diff > 0 ? diff : 0;
}

/// 月の最初の日から、d が何週目か（日曜始まり・0始まり）
int _weekIndex(DateTime d, DateTime first) =>
    ((first.weekday % 7) + (d.day - 1)) ~/ 7;

class MonthlyStats {
  const MonthlyStats({
    required this.month,
    required this.studyMinutes,
    required this.clubMinutes,
    required this.todoTotal,
    required this.todoDone,
    required this.eventCount,
    required this.avgEventsPerDay,
    required this.noPlanDays,
    required this.weekdayCounts,
    required this.weekTotalsMinutes,
  });

  /// その月の1日（時刻なし）
  final DateTime month;

  final int studyMinutes;
  final int clubMinutes;

  /// 期限がその月にあるToDoの件数・完了数
  final int todoTotal;
  final int todoDone;

  /// 終日でない・移動予定でない予定の、のべ件数（1日に複数あれば複数カウント）
  final int eventCount;
  final double avgEventsPerDay;

  /// 予定が1件もなかった日の数
  final int noPlanDays;

  /// 曜日ごとの予定件数（index 0=月 … 6=日）
  final List<int> weekdayCounts;

  /// 週ごと（日曜始まり）の合計分数
  final List<int> weekTotalsMinutes;

  /// 一番予定が多い曜日（DateTime.weekday の値、1=月…7=日）。データなしなら null
  int? get busiestWeekday {
    var best = -1;
    for (var i = 0; i < weekdayCounts.length; i++) {
      if (weekdayCounts[i] > 0 && (best == -1 || weekdayCounts[i] > weekdayCounts[best])) {
        best = i;
      }
    }
    return best == -1 ? null : best + 1;
  }

  /// 一番忙しかった週（0始まりの週番号）。データなしなら null
  int? get busiestWeekIndex {
    var best = -1;
    for (var i = 0; i < weekTotalsMinutes.length; i++) {
      if (weekTotalsMinutes[i] > 0 &&
          (best == -1 || weekTotalsMinutes[i] > weekTotalsMinutes[best])) {
        best = i;
      }
    }
    return best == -1 ? null : best;
  }
}

/// 指定した月（today を含まない未来の日は数えない）のデータを集計する
MonthlyStats computeMonthlyStats({
  required DateTime month,
  required List<CalendarEvent> events,
  required List<StudySession> sessions,
  required List<Todo> todos,
  DateTime? now,
}) {
  final first = DateTime(month.year, month.month, 1);
  final nextMonth = DateTime(month.year, month.month + 1, 1);
  final today = _day(now ?? DateTime.now());
  final tomorrow = today.add(const Duration(days: 1));
  var effectiveEnd = nextMonth.isBefore(tomorrow) ? nextMonth : tomorrow;
  if (effectiveEnd.isBefore(first)) effectiveEnd = first;

  final studyMinutes = totalMinutes(sessions, first, nextMonth);

  final regularEvents = events
      .where((e) => !e.isAllDay && !e.isTravelEvent)
      .toList();

  var clubMinutes = 0;
  var eventCount = 0;
  var noPlanDays = 0;
  final weekdayCounts = List<int>.filled(7, 0);
  final weekTotals = <int>[];

  for (var d = first; d.isBefore(effectiveEnd); d = d.add(const Duration(days: 1))) {
    var dayMinutes = 0;
    var dayEvents = 0;
    for (final e in regularEvents) {
      final m = _minutesOnDay(e, d);
      if (m <= 0) continue;
      dayMinutes += m;
      dayEvents++;
      if (e.categoryId == 'club') clubMinutes += m;
    }
    eventCount += dayEvents;
    if (dayEvents == 0) noPlanDays++;
    weekdayCounts[d.weekday - 1] += dayEvents;

    final wi = _weekIndex(d, first);
    while (weekTotals.length <= wi) {
      weekTotals.add(0);
    }
    weekTotals[wi] += dayMinutes;
  }

  final daysCounted = effectiveEnd.difference(first).inDays;
  final avgEventsPerDay = daysCounted > 0 ? eventCount / daysCounted : 0.0;

  bool inMonth(DateTime? d) =>
      d != null && !d.isBefore(first) && d.isBefore(nextMonth);

  final todoTotal = todos.where((t) => inMonth(t.dueDate)).length;
  final todoDone = todos.where((t) => t.done && inMonth(t.dueDate)).length;

  return MonthlyStats(
    month: first,
    studyMinutes: studyMinutes,
    clubMinutes: clubMinutes,
    todoTotal: todoTotal,
    todoDone: todoDone,
    eventCount: eventCount,
    avgEventsPerDay: avgEventsPerDay,
    noPlanDays: noPlanDays,
    weekdayCounts: weekdayCounts,
    weekTotalsMinutes: weekTotals,
  );
}

/// 前の月に対して何%変わったか（前が0のときは null）
int? percentDiff(int current, int previous) {
  if (previous == 0) return null;
  return (((current - previous) / previous) * 100).round();
}

const _weekdayNamesJa = ['月', '火', '水', '木', '金', '土', '日'];

/// 外部AIを使わない、ルールベースの「今月のまとめ」（Geminiが使えないときのフォールバック）
String buildFallbackSummary(MonthlyStats stats, MonthlyStats? previous) {
  final buf = StringBuffer();
  buf.write('${stats.month.month}月は勉強${formatMinutes(stats.studyMinutes)}');
  if (stats.clubMinutes > 0) {
    buf.write('・部活${formatMinutes(stats.clubMinutes)}');
  }
  buf.write('でした。');

  final wd = stats.busiestWeekday;
  if (wd != null) {
    buf.write('予定が多いのは${_weekdayNamesJa[wd - 1]}曜日です。');
  }

  if (previous != null) {
    final diff = percentDiff(stats.studyMinutes, previous.studyMinutes);
    if (diff != null && diff != 0) {
      buf.write(
        diff > 0
            ? '勉強時間は先月より$diff%増えています。'
            : '勉強時間は先月より${-diff}%減っています。',
      );
    }
  }

  if (stats.noPlanDays > 0) {
    buf.write('予定のない日が${stats.noPlanDays}日ありました。');
  }

  return buf.toString();
}
