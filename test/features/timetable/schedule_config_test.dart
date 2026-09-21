import 'package:flutter_test/flutter_test.dart';
import 'package:school_planner/features/timetable/day_timetable_resolver.dart';
import 'package:school_planner/features/timetable/schedule_config_page.dart';
import 'package:school_planner/features/timetable/school_periods.dart';
import 'package:school_planner/features/timetable/timetable_models.dart';
import 'package:school_planner/features/timetable/week_cycle.dart';

void main() {
  // ほかのテストに影響しないように、毎回はじめの時程にもどす
  tearDown(() => SchoolPeriods.config = ScheduleConfig.standard);

  group('時程の設定', () {
    test('何も設定していなければ、今の学校の時程', () {
      final c = ScheduleConfig.fromMap(null);
      expect(c.periods.length, 5);
      expect(c.periods.first.start.toString(), '08:50');
      expect(c.periodCountFor(DateTime.monday), 5);
      expect(c.periodCountFor(DateTime.wednesday), 4);
      expect(c.lunchAfterPeriod, 3);
      expect(c.useWeekCycle, isTrue);
      expect(c.problems(), isEmpty);
    });

    test('保存して読み直しても同じ', () {
      final c = ScheduleConfig.standard.copyWith(
        periods: generatePeriods(
          firstStart: const ClockTime(8, 40),
          count: 6,
          lessonMinutes: 50,
          breakMinutes: 10,
          lunchAfter: 4,
          lunchMinutes: 45,
        ),
        periodCounts: {1: 6, 2: 6, 3: 5, 4: 6, 5: 6, 6: 4, 7: 0},
        lunchAfterPeriod: 4,
        useWeekCycle: false,
      );
      final back = ScheduleConfig.fromMap(c.toMap());
      expect(back.periods, c.periods);
      expect(back.periodCounts, c.periodCounts);
      expect(back.lunchAfterPeriod, 4);
      expect(back.useWeekCycle, isFalse);
      expect(back.shortenedFor(5), c.shortenedFor(5));
      expect(back.examPeriods, c.examPeriods);
    });

    test('こわれた値は、はじめの時程にもどす', () {
      final c = ScheduleConfig.fromMap({
        'periods': 'こわれている',
        'periodCounts': {'9': 3, 'x': 1},
        'lunchStart': '25:99',
      });
      expect(c.periods, ScheduleConfig.standard.periods);
      expect(c.periodCounts, ScheduleConfig.standard.periodCounts);
      expect(c.lunchStart, ScheduleConfig.standard.lunchStart);
    });

    test('まとめて作る：50分授業・10分休み・4限のあとに昼休み', () {
      final list = generatePeriods(
        firstStart: const ClockTime(8, 40),
        count: 6,
        lessonMinutes: 50,
        breakMinutes: 10,
        lunchAfter: 4,
        lunchMinutes: 45,
      );
      expect(list.map((p) => '${p.start}-${p.end}').toList(), [
        '08:40-09:30',
        '09:40-10:30',
        '10:40-11:30',
        '11:40-12:30',
        '13:15-14:05',
        '14:15-15:05',
      ]);
    });

    test('時刻がおかしいと教えてくれる', () {
      final c = ScheduleConfig.standard.copyWith(
        periods: const [
          SchoolPeriod(
            number: 1,
            start: ClockTime(9, 0),
            end: ClockTime(10, 0),
          ),
          SchoolPeriod(
            number: 2,
            start: ClockTime(9, 30),
            end: ClockTime(9, 20),
          ),
        ],
      );
      final p = c.problems();
      expect(p.any((m) => m.contains('2限の終わり')), isTrue);
      expect(p.any((m) => m.contains('重なって')), isTrue);
    });

    test('設定した時程が、アプリ全体で使われる', () {
      SchoolPeriods.config = ScheduleConfig.standard.copyWith(
        periods: generatePeriods(
          firstStart: const ClockTime(8, 30),
          count: 6,
          lessonMinutes: 50,
          breakMinutes: 10,
        ),
        periodCounts: {1: 6, 2: 6, 3: 6, 4: 6, 5: 6, 6: 3, 7: 0},
        lunchAfterPeriod: 0,
      );
      expect(SchoolPeriods.periodCountFor(DateTime.saturday), 3);
      expect(SchoolPeriods.schoolWeekdays, contains(DateTime.saturday));
      expect(SchoolPeriods.byNumber(6).start.toString(), '13:30');
      expect(SchoolPeriods.lunchAfterPeriod, 0);
    });
  });

  group('Ⅰ・Ⅱ週を使わない', () {
    DayTimetableResolver resolver({required bool cycle}) =>
        DayTimetableResolver(
          weekCalculator: WeekCycleCalculator(
            anchors: [
              WeekAnchor(date: DateTime(2026, 9, 7), weekType: WeekType.one),
            ],
            enabled: cycle,
          ),
          slots: const [
            TimetableSlot(
              weekType: WeekType.one,
              weekday: DateTime.monday,
              period: 1,
              subject: '英語',
            ),
            TimetableSlot(
              weekType: WeekType.two,
              weekday: DateTime.monday,
              period: 1,
              subject: '国語',
            ),
          ],
        );

    test('Ⅱ週の月曜でも、Ⅰ週の時間割を使う', () {
      // 9/14 は本来Ⅱ週
      final on = resolver(cycle: true).resolve(DateTime(2026, 9, 14));
      expect(on.weekType, WeekType.two);
      expect(on.lessons.first.subject, '国語');

      final off = resolver(cycle: false).resolve(DateTime(2026, 9, 14));
      expect(off.weekType, isNull);
      expect(off.lessons.first.subject, '英語');
    });

    test('基準日がなくても「週がわからない」にならない', () {
      final r = DayTimetableResolver(
        weekCalculator: WeekCycleCalculator(anchors: const [], enabled: false),
        slots: const [
          TimetableSlot(
            weekType: WeekType.one,
            weekday: DateTime.monday,
            period: 1,
            subject: '英語',
          ),
        ],
      );
      final day = r.resolve(DateTime(2026, 9, 14));
      expect(day.lessons.first.subject, '英語');
    });
  });
}
