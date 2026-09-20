import 'package:flutter_test/flutter_test.dart';
import 'package:school_planner/features/events/calendar_event.dart';
import 'package:school_planner/features/school_tests/school_test.dart';
import 'package:school_planner/features/timetable/day_timetable_resolver.dart';
import 'package:school_planner/features/timetable/school_periods.dart';
import 'package:school_planner/features/timetable/week_cycle.dart';
import 'package:school_planner/features/widget/widget_text.dart';

ResolvedLesson _l(
  int p,
  String? subject, {
  LessonStatus status = LessonStatus.normal,
  String? test,
}) => ResolvedLesson(
  period: p,
  start: ClockTime(9, 0),
  end: ClockTime(10, 10),
  status: status,
  subject: subject,
  testLabel: test,
);

void main() {
  test('授業・テスト・予定をまとめる', () {
    final day = DayTimetable(
      date: DateTime(2026, 9, 21),
      status: DayStatus.school,
      weekType: WeekType.one,
      lessons: [
        _l(1, '数学Ⅰ'),
        _l(2, 'ECⅠ', test: 'LEAP単語テスト 1301〜1400'),
        _l(3, '化学基礎', status: LessonStatus.cancelled),
      ],
    );
    final w = buildWidgetDay(
      day: day,
      events: [
        CalendarEvent(
          title: '塾 数学',
          start: DateTime(2026, 9, 21, 19, 40),
          end: DateTime(2026, 9, 21, 21, 40),
        ),
        CalendarEvent(
          title: '体育祭の準備',
          start: DateTime(2026, 9, 21),
          end: DateTime(2026, 9, 21),
          isAllDay: true,
        ),
      ],
      tests: [
        SchoolTest(
          kind: SchoolTestKind.mockExam,
          title: '進研模試',
          date: DateTime(2026, 9, 21),
        ),
      ],
    );
    expect(w.date, '2026-09-21');
    expect(w.title, '9/21(月) Ⅰ週');
    expect(
      w.body,
      '1限 数学Ⅰ\n'
      '2限 ECⅠ  📝LEAP単語テスト 1301〜1400\n'
      '3限 （休講）\n'
      '📝進研模試\n'
      '・体育祭の準備\n'
      '19:40 塾 数学',
    );
  });

  test('祝日は名前を出す', () {
    final w = buildWidgetDay(
      day: DayTimetable(
        date: DateTime(2026, 9, 22),
        status: DayStatus.holiday,
        lessons: const [],
        holidayName: '秋分の日',
      ),
    );
    expect(w.title, '9/22(火)');
    expect(w.body, '秋分の日');
  });
}
