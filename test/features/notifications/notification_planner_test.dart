import 'package:flutter_test/flutter_test.dart';
import 'package:school_planner/core/japanese_holidays.dart';
import 'package:school_planner/features/events/calendar_event.dart';
import 'package:school_planner/features/notifications/notification_planner.dart';
import 'package:school_planner/features/school_tests/upcoming_tests.dart';
import 'package:school_planner/features/timetable/day_timetable_resolver.dart';
import 'package:school_planner/features/timetable/initial_data.dart';
import 'package:school_planner/features/timetable/week_cycle.dart';
import 'package:school_planner/features/todo/todo.dart';

void main() {
  final resolver = DayTimetableResolver(
    weekCalculator: WeekCycleCalculator(
      anchors: initialAnchors,
      weekOverrides: initialWeekOverrides,
    ),
    slots: initialSlots,
    dayOverrides: initialDayOverrides,
    closures: initialClosures.values.toList(),
    holidays: japaneseHolidays,
  );

  final plan = planNotifications(
    now: DateTime(2026, 9, 27, 12, 0),
    days: 2,
    resolver: resolver,
    upcoming: [
      UpcomingItem(
        date: DateTime(2026, 9, 28),
        title: 'ECⅠ LEAP単語テスト',
        kindLabel: '小テスト',
        isTest: true,
        detail: '1201〜1300',
      ),
    ],
    events: [
      CalendarEvent(
        title: '部活',
        start: DateTime(2026, 9, 28, 16, 0),
        end: DateTime(2026, 9, 28, 18, 0),
      ),
    ],
    todos: [Todo(title: '古いプリント', dueDate: DateTime(2026, 9, 25))],
  );

  PlannedNotification at(int m, int d, int h, int min) =>
      plan.firstWhere((n) => n.time == DateTime(2026, m, d, h, min));

  test('前日 21:30 に明日のまとめ（テストと予定）', () {
    final n = at(9, 27, 21, 30);
    expect(n.title, '明日（9/28）');
    expect(n.body, contains('Ⅱ週'));
    expect(n.body, contains('LEAP'));
    expect(n.body, contains('16:00 部活'));
  });

  test('当日 7:00 に今日のまとめ（期限切れの ToDo も）', () {
    final n = at(9, 28, 7, 0);
    expect(n.body, contains('LEAP'));
    expect(n.body, contains('期限切れの ToDo：1件'));
  });

  test('予定の30分前', () {
    final n = at(9, 28, 15, 30);
    expect(n.title, '16:00 部活');
  });

  test('過去の時刻（今日の7:00）は予約しない', () {
    expect(plan.where((n) => n.time == DateTime(2026, 9, 27, 7, 0)), isEmpty);
  });
}
