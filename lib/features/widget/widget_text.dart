/// ホーム画面ウィジェットに出す文字を作る（アプリの中で計算して、ウィジェットは表示するだけ）
library;

import '../events/calendar_event.dart';
import '../school_tests/school_test.dart';
import '../timetable/day_timetable_resolver.dart';
import '../timetable/week_cycle.dart';

const _wd = ['月', '火', '水', '木', '金', '土', '日'];

String _hm(int minutes) =>
    '${minutes ~/ 60}:${(minutes % 60).toString().padLeft(2, '0')}';

String _hmOf(DateTime d) => _hm(d.hour * 60 + d.minute);

/// ウィジェットの1日分
class WidgetDay {
  const WidgetDay({
    required this.date,
    required this.title,
    required this.body,
  });

  /// 2026-09-21 の形（ウィジェット側で「今日／明日」を選ぶのに使う）
  final String date;

  /// 例：9/21(月) Ⅰ週
  final String title;

  /// 時間割・テスト・予定（改行区切り）
  final String body;
}

/// 1日分の文字を作る
WidgetDay buildWidgetDay({
  required DayTimetable day,
  List<CalendarEvent> events = const [],
  List<SchoolTest> tests = const [],
}) {
  final d = day.date;
  final week = day.weekType == null
      ? ''
      : (day.weekType == WeekType.one ? ' Ⅰ週' : ' Ⅱ週');
  final title = '${d.month}/${d.day}(${_wd[d.weekday - 1]})$week';

  final lines = <String>[];

  // 時間割
  if (day.status == DayStatus.school) {
    for (final l in day.lessons) {
      if (l.status == LessonStatus.empty) continue;
      if (l.status == LessonStatus.cancelled) {
        lines.add('${l.period}限 （休講）');
        continue;
      }
      final test = l.testLabel == null ? '' : '  📝${l.testLabel}';
      lines.add('${l.period}限 ${l.subject ?? ''}$test');
    }
  } else {
    lines.add(day.holidayName ?? day.closureTitle ?? '学校はお休み');
  }

  // 授業と関係ないテスト（模試など）
  for (final t in tests) {
    if (t.period == null && t.kind.isTest) lines.add('📝${t.displayTitle}');
  }

  // 予定（終日 → 時刻順）
  final todays =
      [
        for (final e in events)
          if (e.occursOn(d)) e,
      ]..sort((a, b) {
        if (a.isAllDay != b.isAllDay) return a.isAllDay ? -1 : 1;
        return a.start.compareTo(b.start);
      });
  for (final e in todays) {
    lines.add(e.isAllDay ? '・${e.title}' : '${_hmOf(e.start)} ${e.title}');
  }

  return WidgetDay(date: dateKey(d), title: title, body: lines.join('\n'));
}
