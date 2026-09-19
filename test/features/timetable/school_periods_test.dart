import 'package:flutter_test/flutter_test.dart';
import 'package:school_planner/features/timetable/school_periods.dart';

void main() {
  group('テスト8：授業の標準時刻', () {
    test('1限〜5限の時刻が正しい', () {
      expect(SchoolPeriods.byNumber(1).start.toString(), '08:50');
      expect(SchoolPeriods.byNumber(1).end.toString(), '10:00');
      expect(SchoolPeriods.byNumber(2).start.toString(), '10:10');
      expect(SchoolPeriods.byNumber(2).end.toString(), '11:20');
      expect(SchoolPeriods.byNumber(3).start.toString(), '11:30');
      expect(SchoolPeriods.byNumber(3).end.toString(), '12:40');
      expect(SchoolPeriods.byNumber(4).start.toString(), '13:30');
      expect(SchoolPeriods.byNumber(4).end.toString(), '14:40');
      expect(SchoolPeriods.byNumber(5).start.toString(), '14:50');
      expect(SchoolPeriods.byNumber(5).end.toString(), '16:00');
    });

    test('昼休みは 12:40〜13:25', () {
      expect(SchoolPeriods.lunchStart.toString(), '12:40');
      expect(SchoolPeriods.lunchEnd.toString(), '13:25');
    });

    test('すべての授業が70分', () {
      for (final period in SchoolPeriods.all) {
        expect(period.durationMinutes, 70, reason: '${period.label} が70分ではない');
      }
    });

    test('存在しない時限（6限）はエラーになる', () {
      expect(() => SchoolPeriods.byNumber(6), throwsArgumentError);
    });
  });

  group('テスト6・7：曜日ごとの授業数', () {
    test('月・火・木は5限まである', () {
      expect(SchoolPeriods.periodCountFor(DateTime.monday), 5);
      expect(SchoolPeriods.periodCountFor(DateTime.tuesday), 5);
      expect(SchoolPeriods.periodCountFor(DateTime.thursday), 5);
    });

    test('水・金は4限まで', () {
      expect(SchoolPeriods.periodCountFor(DateTime.wednesday), 4);
      expect(SchoolPeriods.periodCountFor(DateTime.friday), 4);
    });

    test('水曜の5限は通常の授業として存在しない', () {
      expect(SchoolPeriods.isRegularPeriod(DateTime.wednesday, 5), isFalse);
      expect(SchoolPeriods.isRegularPeriod(DateTime.wednesday, 4), isTrue);
    });

    test('金曜の5限も存在しない', () {
      expect(SchoolPeriods.isRegularPeriod(DateTime.friday, 5), isFalse);
    });

    test('土日は授業なし', () {
      expect(SchoolPeriods.periodCountFor(DateTime.saturday), 0);
      expect(SchoolPeriods.periodCountFor(DateTime.sunday), 0);
      expect(SchoolPeriods.periodsFor(DateTime.sunday), isEmpty);
    });
  });
}
