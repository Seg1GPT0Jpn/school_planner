/// 「スケジュール」表示（日付順の一覧）に並べるものを作る
library;

import '../events/calendar_event.dart';
import '../school_tests/school_test.dart';
import '../timetable/day_timetable_resolver.dart';

/// 一覧の1行の種類
enum ScheduleKind { holiday, event, test, lesson }

/// 一覧の1行
class ScheduleItem {
  const ScheduleItem({
    required this.kind,
    required this.title,
    this.timeText = '終日',
    this.sortMinutes = -1,
    this.event,
    this.color,
  });

  final ScheduleKind kind;
  final String title;

  /// 「終日」「19:40〜21:40」など
  final String timeText;

  /// 並べる順（終日は -1）
  final int sortMinutes;

  /// 予定のとき、その予定（タップで開く）
  final CalendarEvent? event;

  /// 予定のときの色（0xAARRGGBB）。null なら種類ごとの色
  final int? color;
}

/// 1日分
class ScheduleDay {
  const ScheduleDay(this.date, this.items);
  final DateTime date;
  final List<ScheduleItem> items;
}

String _hm(int m) => '${m ~/ 60}:${(m % 60).toString().padLeft(2, '0')}';

String _hmOf(DateTime d) => _hm(d.hour * 60 + d.minute);

/// 予定の時刻の文字（何日かにまたがる予定にも対応）
String eventTimeText(CalendarEvent e, DateTime day) {
  if (e.isAllDay) return '終日';
  final d = DateTime(day.year, day.month, day.day);
  final startsToday = !e.start.isBefore(d);
  final endsToday = e.end.isBefore(DateTime(d.year, d.month, d.day + 1));
  if (startsToday && endsToday) return '${_hmOf(e.start)}〜${_hmOf(e.end)}';
  if (startsToday) return '${_hmOf(e.start)}〜';
  if (endsToday) return '〜${_hmOf(e.end)}';
  return '終日';
}

/// その日の一覧を作る
ScheduleDay buildScheduleDay({
  required DayTimetable day,
  List<CalendarEvent> events = const [],
  List<SchoolTest> tests = const [],
  bool showLessons = false,
  int? Function(CalendarEvent e)? colorOf,
}) {
  final d = day.date;
  final items = <ScheduleItem>[];

  // 祝日・休業日
  final off = day.holidayName ?? day.closureTitle;
  if (off != null)
    items.add(ScheduleItem(kind: ScheduleKind.holiday, title: off));

  // 授業のテスト（LEAP・時限つきの小テスト）と授業
  for (final l in day.lessons) {
    final time = '${_hm(l.start.totalMinutes)}〜${_hm(l.end.totalMinutes)}';
    if (l.testLabel != null) {
      items.add(
        ScheduleItem(
          kind: ScheduleKind.test,
          title: '📝 ${l.subject ?? ''} ${l.testLabel}',
          timeText: time,
          sortMinutes: l.start.totalMinutes,
        ),
      );
    }
    if (showLessons &&
        l.status != LessonStatus.empty &&
        l.status != LessonStatus.cancelled &&
        l.subject != null) {
      items.add(
        ScheduleItem(
          kind: ScheduleKind.lesson,
          title: '${l.period}限 ${l.subject}',
          timeText: time,
          sortMinutes: l.start.totalMinutes,
        ),
      );
    }
  }

  // 時限のない小テスト・定期テスト・提出物・行事など
  for (final t in tests) {
    if (t.period != null) continue;
    final m = t.startTime?.totalMinutes;
    items.add(
      ScheduleItem(
        kind: ScheduleKind.test,
        title: '${t.kind.isTest ? '📝' : '📌'} ${t.displayTitle}',
        timeText: m == null ? '終日' : '${_hm(m)}〜',
        sortMinutes: m ?? -1,
      ),
    );
  }

  // 予定
  for (final e in events) {
    if (!e.occursOn(d)) continue;
    final text = eventTimeText(e, d);
    items.add(
      ScheduleItem(
        kind: ScheduleKind.event,
        title: e.title,
        timeText: text,
        sortMinutes: text == '終日' || text.startsWith('〜')
            ? -1
            : e.start.hour * 60 + e.start.minute,
        event: e,
        color: colorOf?.call(e),
      ),
    );
  }

  items.sort((a, b) {
    final c = a.sortMinutes.compareTo(b.sortMinutes);
    if (c != 0) return c;
    return a.kind.index.compareTo(b.kind.index);
  });
  return ScheduleDay(d, items);
}
