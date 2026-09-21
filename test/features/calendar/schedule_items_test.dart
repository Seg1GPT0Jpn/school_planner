import 'package:flutter_test/flutter_test.dart';
import 'package:school_planner/features/calendar/schedule_items.dart';
import 'package:school_planner/features/events/calendar_event.dart';
import 'package:school_planner/features/school_tests/school_test.dart';
import 'package:school_planner/features/timetable/day_timetable_resolver.dart';
import 'package:school_planner/features/timetable/school_periods.dart';

ResolvedLesson _l(int p, String subject, int h, int m, {String? test}) =>
    ResolvedLesson(
      period: p,
      start: ClockTime(h, m),
      end: ClockTime(h + 1, m + 10),
      status: LessonStatus.normal,
      subject: subject,
      testLabel: test,
    );

void main() {
  final day = DayTimetable(
    date: DateTime(2026, 9, 24),
    status: DayStatus.school,
    lessons: [
      _l(1, '数学Ⅰ', 8, 50),
      _l(2, 'ECⅠ', 10, 10, test: 'LEAP単語テスト 1201〜1300'),
    ],
  );
  final events = [
    CalendarEvent(
      title: '塾 数学',
      start: DateTime(2026, 9, 24, 19, 40),
      end: DateTime(2026, 9, 24, 21, 40),
    ),
    CalendarEvent(
      title: '体育祭の準備',
      start: DateTime(2026, 9, 24),
      end: DateTime(2026, 9, 24),
      isAllDay: true,
    ),
    CalendarEvent(
      title: '別の日',
      start: DateTime(2026, 9, 25, 10),
      end: DateTime(2026, 9, 25, 11),
    ),
  ];

  test('終日 → 時刻順、テストも入る、別の日の予定は入らない', () {
    final d = buildScheduleDay(
      day: day,
      events: events,
      tests: [
        SchoolTest(
          kind: SchoolTestKind.assignment,
          title: 'レポート提出',
          date: DateTime(2026, 9, 24),
        ),
      ],
    );
    expect(d.items.map((i) => i.title).toList(), [
      '体育祭の準備',
      '📌 レポート提出',
      '📝 ECⅠ LEAP単語テスト 1201〜1300',
      '塾 数学',
    ]);
    expect(d.items.last.timeText, '19:40〜21:40');
  });

  test('「授業も表示」で授業が入る', () {
    final d = buildScheduleDay(day: day, showLessons: true);
    expect(d.items.map((i) => i.title).toList(), [
      '1限 数学Ⅰ',
      '📝 ECⅠ LEAP単語テスト 1201〜1300',
      '2限 ECⅠ',
    ]);
  });

  test('祝日は名前が出る', () {
    final d = buildScheduleDay(
      day: DayTimetable(
        date: DateTime(2026, 9, 23),
        status: DayStatus.holiday,
        lessons: const [],
        holidayName: '秋分の日',
      ),
    );
    expect(d.items.single.title, '秋分の日');
    expect(d.items.single.kind, ScheduleKind.holiday);
  });

  test('何日かにまたがる予定の時刻', () {
    final e = CalendarEvent(
      title: '合宿',
      start: DateTime(2026, 9, 24, 15),
      end: DateTime(2026, 9, 26, 12),
    );
    expect(eventTimeText(e, DateTime(2026, 9, 24)), '15:00〜');
    expect(eventTimeText(e, DateTime(2026, 9, 25)), '終日');
    expect(eventTimeText(e, DateTime(2026, 9, 26)), '〜12:00');
  });
}
