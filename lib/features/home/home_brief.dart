/// ホームの「いま」「急ぎ」をまとめる（画面に依存しない計算だけ）
///
/// 週間レビューやテストカルテ、将来の「つづりAI」からも使える形にしておく。
library;

import '../events/calendar_event.dart';
import '../school_tests/upcoming_tests.dart';
import '../timetable/day_timetable_resolver.dart';
import '../todo/todo.dart';

DateTime _day(DateTime d) => DateTime(d.year, d.month, d.day);

/// a から b まで何日か（同じ日なら 0）
int daysBetween(DateTime a, DateTime b) => DateTime.utc(
  b.year,
  b.month,
  b.day,
).difference(DateTime.utc(a.year, a.month, a.day)).inDays;

// ─────────────────────────── いまの授業 ───────────────────────────

enum LessonPhase {
  /// 学校がない日
  noSchool,

  /// 1限より前
  beforeSchool,

  /// 授業中
  inLesson,

  /// 休み時間・昼休み
  between,

  /// 今日の授業はおわり
  afterSchool,
}

class LessonNow {
  const LessonNow({
    required this.phase,
    this.current,
    this.next,
    this.minutesLeft,
    this.lastPeriod,
  });

  final LessonPhase phase;

  /// いまの授業（授業中のとき）
  final ResolvedLesson? current;

  /// 次の授業
  final ResolvedLesson? next;

  /// 授業中なら「終わるまで」、それ以外なら「次が始まるまで」の分
  final int? minutesLeft;

  /// 今日は何限まであるか
  final int? lastPeriod;
}

/// 休講・空きを除いた、実際にある授業（時刻順）
List<ResolvedLesson> realLessons(DayTimetable day) => [
  for (final l in day.lessons)
    if (l.subject != null &&
        l.status != LessonStatus.empty &&
        l.status != LessonStatus.cancelled)
      l,
]..sort((a, b) => a.start.compareTo(b.start));

LessonNow lessonNow(DayTimetable day, DateTime now) {
  final lessons = day.status == DayStatus.school
      ? realLessons(day)
      : const <ResolvedLesson>[];
  if (lessons.isEmpty) return const LessonNow(phase: LessonPhase.noSchool);

  final m = now.hour * 60 + now.minute;
  final last = lessons.last.period;
  for (var i = 0; i < lessons.length; i++) {
    final l = lessons[i];
    final s = l.start.totalMinutes, e = l.end.totalMinutes;
    if (m < s) {
      return LessonNow(
        phase: i == 0 ? LessonPhase.beforeSchool : LessonPhase.between,
        next: l,
        minutesLeft: s - m,
        lastPeriod: last,
      );
    }
    if (m < e) {
      return LessonNow(
        phase: LessonPhase.inLesson,
        current: l,
        next: i + 1 < lessons.length ? lessons[i + 1] : null,
        minutesLeft: e - m,
        lastPeriod: last,
      );
    }
  }
  return LessonNow(phase: LessonPhase.afterSchool, lastPeriod: last);
}

// ─────────────────────────── 急ぎ ───────────────────────────

/// 急ぎの度合い（上ほど急ぎ）
enum Urgency {
  overdue('期限切れ'),
  today('今日'),
  tomorrow('明日'),
  soon('近日');

  const Urgency(this.label);
  final String label;
}

enum UrgentKind { test, todo }

class UrgentItem {
  const UrgentItem({
    required this.urgency,
    required this.kind,
    required this.title,
    required this.date,
    this.detail,
    this.todo,
    this.upcoming,
  });

  final Urgency urgency;
  final UrgentKind kind;
  final String title;
  final DateTime date;

  /// 範囲・時限・「あと2日」など
  final String? detail;

  final Todo? todo;
  final UpcomingItem? upcoming;
}

Urgency? urgencyOf(DateTime date, DateTime now, {int soonDays = 7}) {
  final d = daysBetween(now, date);
  if (d < 0) return Urgency.overdue;
  if (d == 0) return Urgency.today;
  if (d == 1) return Urgency.tomorrow;
  if (d <= soonDays) return Urgency.soon;
  return null;
}

/// 急ぎのものを、急ぎ順に並べる
///
/// - ToDo：期限切れ・今日・明日・近日（期限のないものは入れない）
/// - テスト：今日・明日・近日（提出物は ToDo のほうに出るので入れない）
List<UrgentItem> buildUrgent({
  required DateTime now,
  required List<Todo> todos,
  required List<UpcomingItem> upcoming,
  int soonDays = 7,
}) {
  final items = <UrgentItem>[];

  for (final t in todos) {
    if (t.done || t.dueDate == null) continue;
    final u = urgencyOf(t.dueDate!, now, soonDays: soonDays);
    if (u == null) continue;
    items.add(
      UrgentItem(
        urgency: u,
        kind: UrgentKind.todo,
        title: t.title,
        date: _day(t.dueDate!),
        detail: t.progressText == null ? null : '✓ ${t.progressText}',
        todo: t,
      ),
    );
  }

  for (final x in upcoming) {
    if (!x.isTest) continue;
    // 「テスト勉強を ToDo に出す」にしたテストも、テストとしては出す
    final u = urgencyOf(x.date, now, soonDays: soonDays);
    if (u == null || u == Urgency.overdue) continue;
    items.add(
      UrgentItem(
        urgency: u,
        kind: UrgentKind.test,
        title: x.title,
        date: _day(x.date),
        detail: [
          if (x.period != null) '${x.period}限',
          if (x.detail != null && x.detail!.isNotEmpty) x.detail!,
        ].join('・'),
        upcoming: x,
      ),
    );
  }

  items.sort((a, b) {
    final u = a.urgency.index.compareTo(b.urgency.index);
    if (u != 0) return u;
    final d = a.date.compareTo(b.date);
    if (d != 0) return d;
    final k = a.kind.index.compareTo(b.kind.index); // 同じ日ならテストが先
    if (k != 0) return k;
    return a.title.compareTo(b.title);
  });
  return items;
}

// ─────────────────────────── 1日のまとめ ───────────────────────────

/// ある日について、ホームに出すものをまとめたもの
class DayBrief {
  const DayBrief({
    required this.date,
    required this.day,
    required this.events,
    required this.tests,
    required this.dueTodos,
  });

  final DateTime date;
  final DayTimetable day;

  /// その日の予定（終日→時刻順）
  final List<CalendarEvent> events;

  /// その日のテスト（提出物は含まない）
  final List<UpcomingItem> tests;

  /// その日が締切の、終わっていない ToDo
  final List<Todo> dueTodos;

  bool get isEmpty =>
      events.isEmpty &&
      tests.isEmpty &&
      dueTodos.isEmpty &&
      realLessons(day).isEmpty;
}

DayBrief buildDayBrief({
  required DayTimetable day,
  required List<CalendarEvent> events,
  required List<UpcomingItem> upcoming,
  required List<Todo> todos,
}) {
  final d = _day(day.date);
  return DayBrief(
    date: d,
    day: day,
    events:
        [
          for (final e in events)
            if (e.occursOn(d)) e,
        ]..sort((a, b) {
          if (a.isAllDay != b.isAllDay) return a.isAllDay ? -1 : 1;
          return a.start.compareTo(b.start);
        }),
    tests: [
      for (final x in upcoming)
        if (x.isTest && _day(x.date) == d) x,
    ],
    dueTodos: [
      for (final t in todos)
        if (!t.done && t.dueDate != null && _day(t.dueDate!) == d) t,
    ],
  );
}
