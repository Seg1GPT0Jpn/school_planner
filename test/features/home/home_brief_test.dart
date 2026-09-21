import 'package:flutter_test/flutter_test.dart';
import 'package:school_planner/features/events/calendar_event.dart';
import 'package:school_planner/features/home/home_brief.dart';
import 'package:school_planner/features/school_tests/upcoming_tests.dart';
import 'package:school_planner/features/timetable/day_timetable_resolver.dart';
import 'package:school_planner/features/timetable/school_periods.dart';
import 'package:school_planner/features/todo/todo.dart';

ResolvedLesson _l(
  int p,
  int sh,
  int sm,
  int eh,
  int em,
  String? subject, {
  LessonStatus status = LessonStatus.normal,
}) => ResolvedLesson(
  period: p,
  start: ClockTime(sh, sm),
  end: ClockTime(eh, em),
  status: status,
  subject: subject,
);

void main() {
  final monday = DateTime(2026, 9, 28);
  final day = DayTimetable(
    date: monday,
    status: DayStatus.school,
    lessons: [
      _l(1, 8, 50, 10, 0, '数学Ⅱ'),
      _l(2, 10, 10, 11, 20, '英語'),
      _l(3, 12, 10, 13, 20, '物理', status: LessonStatus.cancelled),
      _l(4, 13, 30, 14, 40, '体育'),
    ],
  );
  DateTime at(int h, int m) => DateTime(2026, 9, 28, h, m);

  group('いまの授業', () {
    test('1限の前', () {
      final n = lessonNow(day, at(8, 0));
      expect(n.phase, LessonPhase.beforeSchool);
      expect(n.next!.subject, '数学Ⅱ');
      expect(n.minutesLeft, 50);
      expect(n.lastPeriod, 4);
    });

    test('授業中は、終わるまでの分と次の授業', () {
      final n = lessonNow(day, at(9, 30));
      expect(n.phase, LessonPhase.inLesson);
      expect(n.current!.subject, '数学Ⅱ');
      expect(n.minutesLeft, 30);
      expect(n.next!.subject, '英語');
    });

    test('休講はとばす（昼休みのあとは4限）', () {
      final n = lessonNow(day, at(12, 30));
      expect(n.phase, LessonPhase.between);
      expect(n.next!.subject, '体育');
      expect(n.minutesLeft, 60);
    });

    test('最後の授業のあとは、おわり', () {
      expect(lessonNow(day, at(15, 0)).phase, LessonPhase.afterSchool);
    });

    test('学校がない日', () {
      final sunday = DayTimetable(
        date: DateTime(2026, 9, 27),
        status: DayStatus.noSchool,
        lessons: const [],
      );
      expect(lessonNow(sunday, at(10, 0)).phase, LessonPhase.noSchool);
    });
  });

  group('急ぎ', () {
    final now = at(7, 0);
    final todos = [
      Todo(title: '数学ワーク', dueDate: DateTime(2026, 9, 29)),
      Todo(title: '読書感想文', dueDate: DateTime(2026, 9, 25)), // 期限切れ
      Todo(title: '理科レポート', dueDate: DateTime(2026, 9, 28)),
      Todo(title: '終わったもの', dueDate: DateTime(2026, 9, 28), done: true),
      const Todo(title: '期限なし'),
      Todo(title: 'ずっと先', dueDate: DateTime(2026, 10, 30)),
    ];
    final upcoming = [
      UpcomingItem(
        date: DateTime(2026, 9, 29),
        title: '英語 LEAP',
        kindLabel: '小テスト',
        isTest: true,
        period: 2,
        detail: '1201〜1300',
      ),
      UpcomingItem(
        date: DateTime(2026, 10, 2),
        title: '数学 小テスト',
        kindLabel: '小テスト',
        isTest: true,
      ),
      UpcomingItem(
        date: DateTime(2026, 9, 29),
        title: '提出物',
        kindLabel: '提出物',
        isTest: false,
      ),
    ];

    test('急ぎ順：期限切れ → 今日 → 明日（テストが先）→ 近日', () {
      final list = buildUrgent(now: now, todos: todos, upcoming: upcoming);
      expect(list.map((x) => x.title).toList(), [
        '読書感想文',
        '理科レポート',
        '英語 LEAP',
        '数学ワーク',
        '数学 小テスト',
      ]);
      expect(list.map((x) => x.urgency).toList(), [
        Urgency.overdue,
        Urgency.today,
        Urgency.tomorrow,
        Urgency.tomorrow,
        Urgency.soon,
      ]);
    });

    test('テストの詳しい情報（時限・範囲）', () {
      final list = buildUrgent(now: now, todos: const [], upcoming: upcoming);
      expect(list.first.detail, '2限・1201〜1300');
    });

    test('近日の範囲を変えられる', () {
      final list = buildUrgent(
        now: now,
        todos: const [],
        upcoming: upcoming,
        soonDays: 2,
      );
      expect(list.map((x) => x.title), ['英語 LEAP']);
    });
  });

  test('1日のまとめ', () {
    final events = [
      CalendarEvent(
        title: '塾',
        start: DateTime(2026, 9, 28, 19, 40),
        end: DateTime(2026, 9, 28, 21, 40),
      ),
      CalendarEvent(
        title: '体育祭',
        start: DateTime(2026, 9, 28),
        end: DateTime(2026, 9, 28),
        isAllDay: true,
      ),
      CalendarEvent(
        title: '別の日',
        start: DateTime(2026, 9, 29, 10),
        end: DateTime(2026, 9, 29, 11),
      ),
    ];
    final b = buildDayBrief(
      day: day,
      events: events,
      upcoming: [
        UpcomingItem(
          date: monday,
          title: '数学 小テスト',
          kindLabel: '小テスト',
          isTest: true,
        ),
      ],
      todos: [
        Todo(title: '今日まで', dueDate: monday),
        Todo(title: '明日まで', dueDate: DateTime(2026, 9, 29)),
      ],
    );
    expect(b.events.map((e) => e.title).toList(), ['体育祭', '塾']);
    expect(b.tests.single.title, '数学 小テスト');
    expect(b.dueTodos.single.title, '今日まで');
    expect(b.isEmpty, isFalse);
  });
}
