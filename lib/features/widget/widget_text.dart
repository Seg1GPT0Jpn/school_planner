/// ホーム画面ウィジェットに出す内容を作る（アプリの中で計算して、ウィジェットは表示するだけ）
library;

import '../events/calendar_event.dart';
import '../school_tests/school_test.dart';
import '../timetable/day_timetable_resolver.dart';
import '../timetable/week_cycle.dart';

const _wd = ['月', '火', '水', '木', '金', '土', '日'];

String _hmOf(DateTime d) => '${d.hour}:${d.minute.toString().padLeft(2, '0')}';

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
    subject.replaceAll('\t', ' '),
    test.replaceAll('\t', ' '),
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
