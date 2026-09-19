import 'package:flutter_test/flutter_test.dart';
import 'package:school_planner/core/japanese_holidays.dart';
import 'package:school_planner/features/timetable/day_timetable_resolver.dart';
import 'package:school_planner/features/timetable/initial_data.dart';
import 'package:school_planner/features/timetable/school_periods.dart';
import 'package:school_planner/features/timetable/timetable_models.dart';
import 'package:school_planner/features/timetable/week_cycle.dart';

DayTimetable _resolve(DateTime date, {List<DayOverride> overrides = const []}) {
  return DayTimetableResolver(
    weekCalculator: WeekCycleCalculator(
      anchors: initialAnchors,
      weekOverrides: initialWeekOverrides,
    ),
    slots: initialSlots,
    dayOverrides: [...initialDayOverrides, ...overrides],
    holidays: japaneseHolidays,
  ).resolve(date);
}

List<String> _times(DayTimetable day) =>
    day.lessons.map((l) => '${l.start}-${l.end}').toList();

void main() {
  group('短縮日課の時程', () {
    test('通常5コマの曜日（月）は 40分×5、12:50 に終わる', () {
      final periods = SchoolPeriods.periodsForSchedule(
        DaySchedule.shortened,
        DateTime.monday,
      );
      expect(periods.length, 5);
      expect(periods.every((p) => p.durationMinutes == 40), isTrue);
      expect(periods.last.end.toString(), '12:50');
    });

    test('通常4コマの曜日（水）は 50分×4、12:40 に終わる', () {
      final periods = SchoolPeriods.periodsForSchedule(
        DaySchedule.shortened,
        DateTime.wednesday,
      );
      expect(periods.length, 4);
      expect(periods.every((p) => p.durationMinutes == 50), isTrue);
      expect(periods.last.end.toString(), '12:40');
    });

    test('短縮日課・試験日課には昼休みがない', () {
      expect(DaySchedule.regular.hasLunch, isTrue);
      expect(DaySchedule.shortened.hasLunch, isFalse);
      expect(DaySchedule.exam.hasLunch, isFalse);
    });
  });

  group('試験日課の時程', () {
    test('3コマ：9:00〜10:00、10:15〜11:15、11:30〜12:30', () {
      final periods = SchoolPeriods.periodsForSchedule(
        DaySchedule.exam,
        DateTime.wednesday,
      );
      expect(periods.map((p) => '${p.start}-${p.end}').toList(), [
        '09:00-10:00',
        '10:15-11:15',
        '11:30-12:30',
      ]);
    });
  });

  group('日課を指定した日の時間割', () {
    test('11/24（火・Ⅱ週）を短縮日課にすると、Ⅱ週・火曜の授業を40分で行う', () {
      final day = _resolve(
        DateTime(2026, 11, 24),
        overrides: [
          DayOverride(
            date: DateTime(2026, 11, 24),
            schedule: DaySchedule.shortened,
          ),
        ],
      );
      expect(day.schedule, DaySchedule.shortened);
      expect(day.weekType, WeekType.two);
      expect(day.lessons.map((l) => l.subject).toList(), [
        'ECⅠ',
        '情報Ⅰ',
        '生物基礎',
        '体育',
        '言語文化',
      ]);
      expect(_times(day).first, '08:50-09:30');
      expect(_times(day).last, '12:10-12:50');
      expect(day.hasChanges, isTrue);
    });

    test('水曜を短縮日課にすると、4コマ・50分', () {
      // 9/9（水・Ⅰ週）で確認
      final day = _resolve(
        DateTime(2026, 9, 9),
        overrides: [
          DayOverride(
            date: DateTime(2026, 9, 9),
            schedule: DaySchedule.shortened,
          ),
        ],
      );
      expect(day.lessons.length, 4);
      expect(day.lessons.map((l) => l.subject).toList(), [
        '公共',
        '生物基礎',
        '地理総合',
        '数学Ⅰ',
      ]);
      expect(_times(day).last, '11:50-12:40');
    });

    test('試験日課の日は、通常時間割を使わず空欄の3コマになる', () {
      final day = _resolve(
        DateTime(2026, 11, 25),
        overrides: [
          DayOverride(date: DateTime(2026, 11, 25), schedule: DaySchedule.exam),
        ],
      );
      expect(day.status, DayStatus.school);
      expect(day.lessons.length, 3);
      expect(day.lessons.every((l) => l.status == LessonStatus.empty), isTrue);
      expect(_times(day), ['09:00-10:00', '10:15-11:15', '11:30-12:30']);
    });

    test('試験日課の日に、試験科目を入れると試験の時刻で表示される', () {
      final day = _resolve(
        DateTime(2026, 11, 25),
        overrides: [
          DayOverride(
            date: DateTime(2026, 11, 25),
            schedule: DaySchedule.exam,
            changes: const [PeriodChange.replace(period: 1, subject: '数学Ⅰ')],
          ),
        ],
      );
      expect(day.lessons.first.subject, '数学Ⅰ');
      expect(day.lessons.first.start.toString(), '09:00');
    });

    test('日課を指定していない日は、これまでどおり通常日課', () {
      final day = _resolve(DateTime(2026, 9, 24));
      expect(day.schedule, DaySchedule.regular);
      expect(_times(day).first, '08:50-10:00');
    });
  });
}
