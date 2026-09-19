import 'package:flutter_test/flutter_test.dart';
import 'package:school_planner/core/japanese_holidays.dart';
import 'package:school_planner/features/timetable/day_timetable_resolver.dart';
import 'package:school_planner/features/timetable/initial_data.dart';
import 'package:school_planner/features/timetable/timetable_models.dart';
import 'package:school_planner/features/timetable/timetable_version.dart';
import 'package:school_planner/features/timetable/week_cycle.dart';

void main() {
  final v1001 = TimetableVersion(
    validFrom: DateTime(2026, 10, 1),
    slots: const [
      TimetableSlot(
        weekType: WeekType.one,
        weekday: DateTime.monday,
        period: 1,
        subject: '数学A',
      ),
    ],
  );

  test('切り替え日より前は最初の時間割、その日からは新しい時間割', () {
    expect(slotsOn(DateTime(2026, 9, 30), initialSlots, [v1001]), initialSlots);
    expect(slotsOn(DateTime(2026, 10, 1), initialSlots, [v1001]), v1001.slots);
  });

  test('時間割の計算にも反映される', () {
    final resolver = DayTimetableResolver(
      weekCalculator: WeekCycleCalculator(
        anchors: initialAnchors,
        weekOverrides: initialWeekOverrides,
      ),
      slots: initialSlots,
      dayOverrides: initialDayOverrides,
      closures: initialClosures.values.toList(),
      holidays: japaneseHolidays,
      slotsForDate: (d) => slotsOn(d, initialSlots, [v1001]),
    );
    // 9/7（Ⅰ週・月）は最初の時間割：1限 体育
    expect(resolver.resolve(DateTime(2026, 9, 7)).lessons[0].subject, '体育');
    // 10/5（Ⅰ週・月）は新しい時間割：1限 数学A、2限は空き
    final day = resolver.resolve(DateTime(2026, 10, 5));
    expect(day.lessons[0].subject, '数学A');
    expect(day.lessons[1].subject, isNull);
  });
}
