/// ホーム画面ウィジェットに出す内容を作る（アプリの中で計算して、ウィジェットは表示するだけ）
library;

import '../calendar/schedule_items.dart';
import '../events/calendar_event.dart';
import '../school_tests/school_test.dart';
import '../timetable/day_timetable_resolver.dart';
import '../timetable/week_cycle.dart';

const _wd = ['月', '火', '水', '木', '金', '土', '日'];

String _hmOf(DateTime d) => '${d.hour}:${d.minute.toString().padLeft(2, '0')}';

String _clean(String s) => s.replaceAll('\t', ' ').replaceAll('\n', ' ');

// ───────────────────── 今日の予定ウィジェット ─────────────────────

/// ウィジェットの時間割1行
class WidgetLesson {
  const WidgetLesson({
    required this.period,
    required this.subject,
    this.test = '',
    this.color = 0xFF9E9E9E,
    this.cancelled = false,
  });

  final int period;
  final String subject;
  final String test;

  /// 教科の色（0xAARRGGBB）
  final int color;
  final bool cancelled;

  /// ウィジェットに渡す形（タブ区切り）
  String encode() => [
    period,
    _clean(subject),
    _clean(test),
    color,
    cancelled ? 1 : 0,
  ].join('\t');
}

/// ウィジェットの1日分
class WidgetDay {
  const WidgetDay({
    required this.date,
    required this.title,
    this.message = '',
    this.lessons = const [],
    this.extra = '',
  });

  /// 2026-09-21 の形（ウィジェット側で「今日／明日」を選ぶのに使う）
  final String date;

  /// 例：9/21(月) Ⅰ週
  final String title;

  /// 学校がない日の説明（例：秋分の日）。学校がある日は空
  final String message;

  final List<WidgetLesson> lessons;

  /// 時間割の下に出すもの（模試・予定。改行区切り）
  final String extra;

  String get encodedLessons => lessons.map((l) => l.encode()).join('\n');
}

/// 1日分を作る
///
/// [subjectColors] は「科目名 → 色」。
WidgetDay buildWidgetDay({
  required DayTimetable day,
  List<CalendarEvent> events = const [],
  List<SchoolTest> tests = const [],
  Map<String, int> subjectColors = const {},
}) {
  final d = day.date;
  final week = day.weekType == null
      ? ''
      : (day.weekType == WeekType.one ? ' Ⅰ週' : ' Ⅱ週');
  final title = '${d.month}/${d.day}(${_wd[d.weekday - 1]})$week';

  // 時間割
  final lessons = <WidgetLesson>[];
  var message = '';
  if (day.status == DayStatus.school) {
    for (final l in day.lessons) {
      if (l.status == LessonStatus.empty) continue;
      final cancelled = l.status == LessonStatus.cancelled;
      lessons.add(
        WidgetLesson(
          period: l.period,
          subject: cancelled ? '休講' : (l.subject ?? ''),
          test: cancelled ? '' : (l.testLabel ?? ''),
          color: cancelled
              ? 0xFFBDBDBD
              : (subjectColors[l.subject] ?? 0xFF9E9E9E),
          cancelled: cancelled,
        ),
      );
    }
  } else {
    message = day.holidayName ?? day.closureTitle ?? '学校はお休み';
  }

  // 授業と関係ないテスト（模試など）と予定
  final lines = <String>[
    for (final t in tests)
      if (t.period == null && t.kind.isTest) '📝 ${t.displayTitle}',
  ];
  final todays =
      [
        for (final e in events)
          if (e.occursOn(d)) e,
      ]..sort((a, b) {
        if (a.isAllDay != b.isAllDay) return a.isAllDay ? -1 : 1;
        return a.start.compareTo(b.start);
      });
  for (final e in todays) {
    lines.add(e.isAllDay ? '・${e.title}' : '${_hmOf(e.start)}  ${e.title}');
  }

  return WidgetDay(
    date: dateKey(d),
    title: title,
    message: message,
    lessons: lessons,
    extra: lines.join('\n'),
  );
}

// ───────────────────────────── 色と名前 ─────────────────────────────

/// 一覧の印の色（予定に色がないときは種類ごとの色）
int scheduleItemColor(ScheduleItem item) =>
    item.color ??
    switch (item.kind) {
      ScheduleKind.holiday => 0xFFD32F2F,
      ScheduleKind.test => 0xFFE65100,
      ScheduleKind.lesson => 0xFF9E9E9E,
      ScheduleKind.event => 0xFF3F51B5,
    };

/// せまいマスに出すときは、頭の絵文字をとる
String chipTitle(String s) {
  for (final p in const ['📝 ', '📌 ']) {
    if (s.startsWith(p)) return s.substring(p.length);
  }
  return s;
}

// ──────────── カレンダースケジュールウィジェット（2×2〜） ────────────

/// スケジュールウィジェットの1行（日付の見出し、または予定1件）
class WidgetScheduleLine {
  const WidgetScheduleLine({
    required this.header,
    required this.left,
    this.title = '',
    this.color = 0,
    this.today = false,
  });

  /// true なら日付の見出し
  final bool header;

  /// 見出しなら「9/21(月)」、予定なら「9:00〜10:00」「終日」
  final String left;

  /// 予定の名前（見出しのときは空）
  final String title;

  /// 印の色（0xAARRGGBB。0 なら色なし）
  final int color;

  /// 今日の見出しか
  final bool today;

  String encode() => [
    header ? 'h' : 'i',
    _clean(left),
    _clean(title),
    color,
    today ? 1 : 0,
  ].join('\t');
}

/// 日付順の一覧を作る（予定が何もない日は飛ばす）
List<WidgetScheduleLine> buildWidgetSchedule({
  required List<ScheduleDay> days,
  required DateTime today,
  int maxLines = 200,
}) {
  final out = <WidgetScheduleLine>[];
  final t = DateTime(today.year, today.month, today.day);
  for (final day in days) {
    if (day.items.isEmpty) continue;
    if (out.length >= maxLines) break;
    final d = day.date;
    out.add(
      WidgetScheduleLine(
        header: true,
        left: '${d.month}/${d.day}(${_wd[d.weekday - 1]})',
        today: d.year == t.year && d.month == t.month && d.day == t.day,
      ),
    );
    for (final item in day.items) {
      if (out.length >= maxLines) break;
      out.add(
        WidgetScheduleLine(
          header: false,
          left: item.timeText,
          title: item.title,
          color: scheduleItemColor(item),
        ),
      );
    }
  }
  return out;
}

String encodeScheduleLines(List<WidgetScheduleLine> lines) =>
    lines.map((l) => l.encode()).join('\n');

// ──────────── ［月］ビュー・［週］ビューウィジェット ────────────

/// 月ビューのマスに入る予定の数
const int monthChips = 3;

/// 週ビューのマスに入る予定の数
const int weekChips = 6;

/// マスの中に出す小さな帯（予定1件）
class WidgetChip {
  const WidgetChip(this.color, this.title);

  /// 0xAARRGGBB。0 なら色なし（「他2件」のとき）
  final int color;
  final String title;
}

/// 入りきらないときは、最後を「他◯件」にする
List<WidgetChip> buildChips(List<ScheduleItem> items, int max) {
  if (items.length <= max) {
    return [
      for (final i in items)
        WidgetChip(scheduleItemColor(i), chipTitle(i.title)),
    ];
  }
  return [
    for (final i in items.take(max - 1))
      WidgetChip(scheduleItemColor(i), chipTitle(i.title)),
    WidgetChip(0, '他${items.length - max + 1}件'),
  ];
}

/// カレンダーのマス1つ
class WidgetDayCell {
  const WidgetDayCell({
    required this.day,
    this.inMonth = true,
    this.today = false,
    this.holiday = false,
    this.chips = const [],
  });

  /// 表示する日にち
  final int day;

  /// その月の日か（月ビューで、前後の月ならうすく出す）
  final bool inMonth;

  final bool today;

  /// 祝日・休業日
  final bool holiday;

  final List<WidgetChip> chips;

  String encode() => [
    day,
    inMonth ? 1 : 0,
    today ? 1 : 0,
    holiday ? 1 : 0,
    chips.length,
    for (final c in chips) ...[c.color, _clean(c.title)],
  ].join('\t');
}

/// カレンダーのウィジェット1つぶん
class WidgetGrid {
  const WidgetGrid({
    required this.title,
    required this.weekdays,
    required this.cells,
  });

  /// 例：2026年9月／9/21〜9/27
  final String title;

  /// 曜日の見出し（週の始まりから7つ）
  final List<String> weekdays;

  final List<WidgetDayCell> cells;

  String get encodedWeekdays => weekdays.join('\t');
  String get encodedCells => cells.map((c) => c.encode()).join('\n');
}

List<String> _weekdayLabels(int weekStart) => [
  for (var i = 0; i < 7; i++) _wd[(weekStart - 1 + i) % 7],
];

/// ［月］ビューを作る（6週ぶん＝42マス）
///
/// [weekStart] は週の始まり（DateTime.sunday なら日曜はじまり）。
WidgetGrid buildWidgetMonth({
  required DateTime month,
  required DateTime today,
  List<ScheduleDay> days = const [],
  int weekStart = DateTime.sunday,
}) {
  final first = DateTime(month.year, month.month, 1);
  // 1日が、その週の何番目か
  final offset = (first.weekday - weekStart + 7) % 7;
  final start = DateTime(first.year, first.month, 1 - offset);
  final byDate = {for (final d in days) dateKey(d.date): d};
  final t = DateTime(today.year, today.month, today.day);

  final cells = <WidgetDayCell>[];
  for (var i = 0; i < 42; i++) {
    final d = DateTime(start.year, start.month, start.day + i);
    final inMonth = d.year == first.year && d.month == first.month;
    final items = byDate[dateKey(d)]?.items ?? const <ScheduleItem>[];
    cells.add(
      WidgetDayCell(
        day: d.day,
        inMonth: inMonth,
        today: d.year == t.year && d.month == t.month && d.day == t.day,
        holiday: items.any((x) => x.kind == ScheduleKind.holiday),
        chips: inMonth ? buildChips(items, monthChips) : const [],
      ),
    );
  }

  return WidgetGrid(
    title: '${first.year}年${first.month}月',
    weekdays: _weekdayLabels(weekStart),
    cells: cells,
  );
}

/// ［週］ビューを作る（7マス）
WidgetGrid buildWidgetWeek({
  required DateTime day,
  required DateTime today,
  List<ScheduleDay> days = const [],
  int weekStart = DateTime.sunday,
}) {
  final base = DateTime(day.year, day.month, day.day);
  final offset = (base.weekday - weekStart + 7) % 7;
  final start = DateTime(base.year, base.month, base.day - offset);
  final end = DateTime(start.year, start.month, start.day + 6);
  final byDate = {for (final d in days) dateKey(d.date): d};
  final t = DateTime(today.year, today.month, today.day);

  final cells = <WidgetDayCell>[];
  for (var i = 0; i < 7; i++) {
    final d = DateTime(start.year, start.month, start.day + i);
    final items = byDate[dateKey(d)]?.items ?? const <ScheduleItem>[];
    cells.add(
      WidgetDayCell(
        day: d.day,
        today: d.year == t.year && d.month == t.month && d.day == t.day,
        holiday: items.any((x) => x.kind == ScheduleKind.holiday),
        chips: buildChips(items, weekChips),
      ),
    );
  }

  return WidgetGrid(
    title: '${start.month}/${start.day}〜${end.month}/${end.day}',
    weekdays: _weekdayLabels(weekStart),
    cells: cells,
  );
}
