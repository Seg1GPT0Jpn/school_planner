import 'package:flutter_test/flutter_test.dart';
import 'package:school_planner/core/japanese_holidays.dart';
import 'package:school_planner/features/timetable/day_timetable_resolver.dart';
import 'package:school_planner/features/timetable/initial_data.dart';
import 'package:school_planner/features/timetable/week_cycle.dart';

DayTimetable _resolve(DateTime date) => DayTimetableResolver(
  weekCalculator: WeekCycleCalculator(
    anchors: initialAnchors,
    weekOverrides: initialWeekOverrides,
  ),
  slots: initialSlots,
  dayOverrides: initialDayOverrides,
  holidays: japaneseHolidays,
).resolve(date);

void main() {
  group('祝日データ', () {
    test('内閣府の一覧どおりの件数（2026年18日、2027年17日）', () {
      final y2026 = japaneseHolidays.keys.where((k) => k.startsWith('2026-'));
      final y2027 = japaneseHolidays.keys.where((k) => k.startsWith('2027-'));
      expect(y2026.length, 18);
      expect(y2027.length, 17);
    });

    test('祝日名を取り出せる', () {
      expect(holidayNameOf(DateTime(2026, 9, 21)), '敬老の日');
      expect(holidayNameOf(DateTime(2026, 9, 22)), '休日');
      expect(holidayNameOf(DateTime(2026, 9, 23)), '秋分の日');
      expect(holidayNameOf(DateTime(2026, 9, 24)), isNull);
    });
  });

  group('祝日は授業なし', () {
    test('9/21〜23 の連休は、すべて祝日扱い', () {
      expect(_resolve(DateTime(2026, 9, 21)).status, DayStatus.holiday);
      expect(_resolve(DateTime(2026, 9, 21)).holidayName, '敬老の日');
      expect(_resolve(DateTime(2026, 9, 22)).status, DayStatus.holiday);
      expect(_resolve(DateTime(2026, 9, 23)).status, DayStatus.holiday);
      expect(_resolve(DateTime(2026, 9, 21)).lessons, isEmpty);
    });

    test('9/24（木）は通常どおりⅠ週の時間割', () {
      final day = _resolve(DateTime(2026, 9, 24));
      expect(day.status, DayStatus.school);
      expect(day.weekType, WeekType.one);
      expect(day.lessons.map((l) => l.subject).toList(), [
        '情報Ⅰ',
        '化学基礎',
        '体育',
        '論表Ⅰ',
        '言語文化',
      ]);
    });

    test('スポーツの日（10/12）は祝日、翌日からは例外のⅠ週', () {
      expect(_resolve(DateTime(2026, 10, 12)).status, DayStatus.holiday);
      expect(_resolve(DateTime(2026, 10, 13)).weekType, WeekType.one);
    });

    test('文化の日（11/3・火）は祝日', () {
      expect(_resolve(DateTime(2026, 11, 3)).holidayName, '文化の日');
    });
  });
}
