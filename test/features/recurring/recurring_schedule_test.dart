import 'package:flutter_test/flutter_test.dart';
import 'package:school_planner/features/recurring/recurring_schedule.dart';
import 'package:school_planner/features/timetable/school_periods.dart';

final math = RecurringSchedule(
  id: 'm',
  title: '塾 数学',
  weekday: DateTime.monday,
  start: ClockTime(19, 40),
  end: ClockTime(21, 40),
);

void main() {
  test('月曜だけ（祝日の月曜も）', () {
    expect(math.occursOn(DateTime(2026, 9, 21)), isTrue);
    expect(math.occursOn(DateTime(2026, 9, 22)), isFalse);
  });

  test('有効期間と休みにした日', () {
    final s = RecurringSchedule(
      id: 'm',
      title: '塾 数学',
      weekday: DateTime.monday,
      start: ClockTime(19, 40),
      end: ClockTime(21, 40),
      validFrom: DateTime(2026, 10, 1),
      validUntil: DateTime(2026, 12, 31),
      skippedDates: const {'2026-10-12'},
    );
    expect(s.occursOn(DateTime(2026, 9, 28)), isFalse);
    expect(s.occursOn(DateTime(2026, 10, 5)), isTrue);
    expect(s.occursOn(DateTime(2026, 10, 12)), isFalse);
    expect(s.occursOn(DateTime(2027, 1, 4)), isFalse);
  });

  test('カレンダー用に展開し、元のIDと日付に戻せる', () {
    final events = expandRecurring(
      [math],
      DateTime(2026, 9, 20),
      DateTime(2026, 9, 27),
    );
    expect(events.length, 1);
    expect(events.single.start, DateTime(2026, 9, 21, 19, 40));
    expect(events.single.end, DateTime(2026, 9, 21, 21, 40));
    final (id, date) = parseRecurringInstance(events.single)!;
    expect(id, 'm');
    expect(date, DateTime(2026, 9, 21));
  });

  test('終了時刻が開始より前ならエラー', () {
    final s = RecurringSchedule(
      title: 'x',
      weekday: 1,
      start: ClockTime(21, 0),
      end: ClockTime(20, 0),
    );
    expect(s.validate(), isNotNull);
  });
}
