import 'package:flutter_test/flutter_test.dart';
import 'package:school_planner/core/japanese_holidays.dart';
import 'package:school_planner/features/timetable/day_timetable_resolver.dart';
import 'package:school_planner/features/timetable/initial_data.dart';
import 'package:school_planner/features/timetable/school_periods.dart';
import 'package:school_planner/features/timetable/week_cycle.dart';

DayTimetable _resolve(DateTime date) => DayTimetableResolver(
  weekCalculator: WeekCycleCalculator(
    anchors: initialAnchors,
    weekOverrides: initialWeekOverrides,
  ),
  slots: initialSlots,
  dayOverrides: initialDayOverrides,
  closures: initialClosures.values.toList(),
  holidays: japaneseHolidays,
).resolve(date);

void main() {
  group('後期中間試験まわり', () {
    test('11/23 は勤労感謝の日', () {
      expect(_resolve(DateTime(2026, 11, 23)).holidayName, '勤労感謝の日');
    });

    test('11/24 は短縮日課（40分×5）', () {
      final day = _resolve(DateTime(2026, 11, 24));
      expect(day.schedule, DaySchedule.shortened);
      expect(day.lessons.length, 5);
      expect(day.lessons.last.end.toString(), '12:50');
    });

    test('11/25〜27、11/30 は試験日課', () {
      for (final d in [25, 26, 27, 30]) {
        final day = _resolve(DateTime(2026, 11, d));
        expect(day.schedule, DaySchedule.exam, reason: '11/$d');
        expect(day.note, '後期中間試験', reason: '11/$d');
      }
    });

    test('12/1 は通常日課に戻る', () {
      expect(_resolve(DateTime(2026, 12, 1)).schedule, DaySchedule.regular);
    });
  });

  group('学校休業日', () {
    test('冬休み：12/24〜1/7 は休み、1/8 から授業', () {
      expect(_resolve(DateTime(2026, 12, 23)).status, DayStatus.school);
      expect(_resolve(DateTime(2026, 12, 24)).closureTitle, '冬休み');
      expect(_resolve(DateTime(2027, 1, 7)).status, DayStatus.closed);
      expect(_resolve(DateTime(2027, 1, 8)).status, DayStatus.school);
    });

    test('入試：2/16・2/17・2/22 は休み、2/26（合格者発表）は授業', () {
      expect(_resolve(DateTime(2027, 2, 16)).status, DayStatus.closed);
      expect(_resolve(DateTime(2027, 2, 17)).status, DayStatus.closed);
      expect(_resolve(DateTime(2027, 2, 22)).status, DayStatus.closed);
      expect(_resolve(DateTime(2027, 2, 26)).status, DayStatus.school);
    });

    test('春休み：3/25〜4/2 は休み', () {
      expect(_resolve(DateTime(2027, 3, 24)).status, DayStatus.school);
      expect(_resolve(DateTime(2027, 3, 25)).closureTitle, '春休み');
      expect(_resolve(DateTime(2027, 4, 2)).status, DayStatus.closed);
    });
  });
}
