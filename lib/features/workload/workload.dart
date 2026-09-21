/// 「予定の詰めすぎ」を見つける（負荷予測）
library;

import '../events/calendar_event.dart';
import '../school_tests/upcoming_tests.dart';

DateTime _day(DateTime d) => DateTime(d.year, d.month, d.day);

/// 1日ぶんの「忙しさ」
class DayLoad {
  const DayLoad({
    required this.day,
    required this.busyMinutes,
    required this.eventCount,
    required this.testCount,
  });

  final DateTime day;

  /// 終日以外の予定の合計時間（分）
  final int busyMinutes;

  /// 終日以外の予定の数
  final int eventCount;

  /// その日が締切・実施日のテストの数
  final int testCount;

  /// 「予定が多い日」とみなすか
  bool get isHeavy =>
      busyMinutes >= 180 || eventCount >= 4 || (testCount >= 1 && eventCount >= 2);
}

/// 何日か分の「忙しさ」をまとめて計算する
List<DayLoad> computeWeekLoad({
  required DateTime from,
  required List<CalendarEvent> events,
  List<UpcomingItem> upcoming = const [],
  int days = 7,
}) {
  return [
    for (var i = 0; i < days; i++)
      () {
        final day = _day(from).add(Duration(days: i));
        var minutes = 0;
        var count = 0;
        for (final e in events) {
          if (e.isAllDay || e.isTravelEvent) continue;
          if (!e.occursOn(day)) continue;
          final dayStart = day;
          final dayEnd = day.add(const Duration(days: 1));
          final s = e.start.isBefore(dayStart) ? dayStart : e.start;
          final en = e.end.isAfter(dayEnd) ? dayEnd : e.end;
          if (en.isAfter(s)) {
            minutes += en.difference(s).inMinutes;
            count++;
          }
        }
        final tests = upcoming
            .where((u) => u.isTest && _day(u.date) == day)
            .length;
        return DayLoad(
          day: day,
          busyMinutes: minutes,
          eventCount: count,
          testCount: tests,
        );
      }(),
  ];
}

/// 週ぜんたいへの、ひとことアドバイス（問題なければ null）
String? weekLoadWarning(List<DayLoad> week) {
  final heavyDays = week.where((d) => d.isHeavy).length;
  final hasTestPeriod = week.where((d) => d.testCount > 0).length >= 2;
  if (heavyDays >= 3) {
    return hasTestPeriod
        ? 'テストが近く、予定も多い週です。休める日をつくりましょう。'
        : 'この週は予定が多い日が続きます。休息日を入れましょう。';
  }
  if (hasTestPeriod && heavyDays >= 1) {
    return 'テスト前は予定を詰めすぎないようにしましょう。';
  }
  return null;
}
