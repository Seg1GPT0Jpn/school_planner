import 'package:flutter_test/flutter_test.dart';
import 'package:school_planner/features/recurring/recurring_schedule.dart';
import 'package:school_planner/features/recurring/recurring_test_rule.dart';
import 'package:school_planner/features/timetable/school_periods.dart';

final _eevi = RecurringTestConfig(
  title: 'EEVI',
  baseDate: DateTime(2026, 9, 18),
  baseStart: 1,
  step: 50,
  withReview: true,
);

RecurringSchedule _english({
  Set<String> skipped = const {},
  RecurringTestConfig? test,
}) => RecurringSchedule(
  id: 'e',
  title: '塾 英語',
  weekday: DateTime.friday,
  start: ClockTime(19, 40),
  end: ClockTime(21, 40),
  skippedDates: skipped,
  test: test ?? _eevi,
);

void main() {
  test('9/18 は 1〜50 だけ（初回は前回なし）', () {
    expect(
      recurringTestOn(_english(), DateTime(2026, 9, 18))!.label,
      'EEVI 1〜50',
    );
  });

  test('9/25 は 51〜100・前回 1〜50', () {
    expect(
      recurringTestOn(_english(), DateTime(2026, 9, 25))!.label,
      'EEVI 51〜100・前回 1〜50',
    );
  });

  test('休みにした週は数えない', () {
    final s = _english(skipped: {'2026-10-02'});
    expect(recurringTestOn(s, DateTime(2026, 10, 2)), isNull);
    expect(
      recurringTestOn(s, DateTime(2026, 10, 9))!.rangeText,
      '101〜150・前回 51〜100',
    );
  });

  test('範囲なしのテストは名前だけ', () {
    final s = _english(test: const RecurringTestConfig(title: '計算テスト'));
    expect(recurringTestOn(s, DateTime(2026, 9, 25))!.label, '計算テスト');
  });

  test('カレンダーの名前に付け足される', () {
    final events = expandRecurringWithTests(
      [_english()],
      DateTime(2026, 9, 25),
      DateTime(2026, 9, 26),
    );
    expect(events.single.title, '塾 英語｜EEVI 51〜100・前回 1〜50');
  });
}
