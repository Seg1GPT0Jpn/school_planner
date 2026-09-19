import 'package:flutter_test/flutter_test.dart';
import 'package:school_planner/features/timetable/day_timetable_resolver.dart';
import 'package:school_planner/features/timetable/initial_data.dart';
import 'package:school_planner/features/timetable/school_periods.dart';
import 'package:school_planner/features/timetable/week_cycle.dart';

DayTimetableResolver _resolver() => DayTimetableResolver(
  weekCalculator: WeekCycleCalculator(
    anchors: initialAnchors,
    weekOverrides: initialWeekOverrides,
  ),
  slots: initialSlots,
  dayOverrides: initialDayOverrides,
);

List<String?> _subjects(DateTime date) =>
    _resolver().resolve(date).lessons.map((l) => l.subject).toList();

WeekType? _weekType(DateTime date) => _resolver().resolve(date).weekType;

void main() {
  group('初期データそのもののチェック', () {
    test('各曜日のコマ数が、標準時間枠のルールと一致している', () {
      for (final weekType in WeekType.values) {
        for (final weekday in SchoolPeriods.schoolWeekdays) {
          final count = initialSlots
              .where((s) => s.weekType == weekType && s.weekday == weekday)
              .length;
          expect(
            count,
            SchoolPeriods.periodCountFor(weekday),
            reason: '${weekType.label} の曜日$weekday のコマ数が違う',
          );
        }
      }
    });

    test('時間割の科目が、すべて科目一覧に登録されている', () {
      final names = initialSubjects.map((s) => s.name).toSet();
      for (final slot in initialSlots) {
        expect(names, contains(slot.subject), reason: '${slot.subject} が一覧にない');
      }
    });
  });

  group('9月の通常サイクル', () {
    test('9/7 の週はⅠ週、9/14 の週はⅡ週', () {
      expect(_weekType(DateTime(2026, 9, 7)), WeekType.one);
      expect(_weekType(DateTime(2026, 9, 14)), WeekType.two);
    });

    test('Ⅰ週・月曜（9/7）の時間割', () {
      expect(_subjects(DateTime(2026, 9, 7)), [
        '体育',
        '現代の国語',
        '数学Ⅰ',
        'ECⅠ',
        '総合',
      ]);
    });

    test('Ⅱ週・水曜（9/16）は4限まで', () {
      expect(_subjects(DateTime(2026, 9, 16)), ['生物基礎', '現代の国語', 'ECⅠ', '数学Ⅰ']);
    });
  });

  group('10月の例外', () {
    test('10/5〜9 はⅠ週（自動判定どおり）', () {
      expect(_weekType(DateTime(2026, 10, 5)), WeekType.one);
      expect(_weekType(DateTime(2026, 10, 9)), WeekType.one);
    });

    test('10/13〜16 は、その週だけⅠ週（本来はⅡ週）', () {
      final day = _resolver().resolve(DateTime(2026, 10, 13));
      expect(day.weekType, WeekType.one);
      expect(day.isWeekOverridden, isTrue);
      expect(_subjects(DateTime(2026, 10, 13)), [
        '現代の国語',
        '地理総合',
        'ECⅠ',
        '化学基礎',
        '芸術',
      ]);
      expect(_weekType(DateTime(2026, 10, 16)), WeekType.one);
    });

    test('10/19（月）だけⅡ週の時間割', () {
      final day = _resolver().resolve(DateTime(2026, 10, 19));
      expect(day.weekType, WeekType.two);
      expect(day.isDayWeekTypeOverridden, isTrue);
      expect(day.hasChanges, isTrue);
      expect(_subjects(DateTime(2026, 10, 19)), [
        '公共',
        'ECⅠ',
        '論表Ⅰ',
        '数学Ⅰ',
        '総合',
      ]);
    });

    test('10/20（火）〜23 は、週のとおりⅠ週', () {
      final day = _resolver().resolve(DateTime(2026, 10, 20));
      expect(day.weekType, WeekType.one);
      expect(day.hasChanges, isFalse);
      expect(_subjects(DateTime(2026, 10, 20)), [
        '現代の国語',
        '地理総合',
        'ECⅠ',
        '化学基礎',
        '芸術',
      ]);
    });

    test('10/26〜30 はⅡ週、11/2〜 はⅠ週（サイクルはずれていない）', () {
      expect(_weekType(DateTime(2026, 10, 26)), WeekType.two);
      expect(_weekType(DateTime(2026, 11, 2)), WeekType.one);
      expect(_weekType(DateTime(2026, 11, 9)), WeekType.two);
    });
  });
}
