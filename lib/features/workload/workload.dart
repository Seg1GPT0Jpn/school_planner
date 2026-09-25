/// 「予定の詰めすぎ」を見つける（負荷予測）
library;

import '../events/calendar_event.dart';
import '../events/event_category.dart';
import '../school_tests/upcoming_tests.dart';
import '../todo/todo.dart';

DateTime _day(DateTime d) => DateTime(d.year, d.month, d.day);

/// テスト1件ぶんの負荷の重み（カテゴリの「最高」と同じ重さとして扱う）
const int _testLoadWeight = 5; // CategoryLoadLevel.highest.weight

/// 1日ぶんの「忙しさ」
class DayLoad {
  const DayLoad({
    required this.day,
    required this.busyMinutes,
    required this.eventCount,
    required this.testCount,
    this.loadScore = 0,
  });

  final DateTime day;

  /// 終日以外の予定の合計時間（分）
  final int busyMinutes;

  /// 終日以外の予定の数
  final int eventCount;

  /// その日が締切・実施日のテストの数
  final int testCount;

  /// カテゴリごとの負荷レベルを反映した、その日の「重さ」の合計。
  /// 単純な予定の数ではなく、軽い予定・重い予定を区別して計算する。
  final int loadScore;

  /// 「予定が多い日」とみなすか
  ///
  /// 予定の数だけで判定すると、軽い予定（買い物など）が何件あっても
  /// 「詰め込みすぎ」扱いになってしまうため、カテゴリの負荷レベルで
  /// 重み付けした [loadScore] を主な基準にする（時間が長い日も別途拾う）。
  bool get isHeavy => loadScore >= 10 || busyMinutes >= 180;
}

/// 何日か分の「忙しさ」をまとめて計算する
///
/// [categories] を渡すと、カテゴリごとの負荷レベル（[EventCategory.loadLevel]）
/// で重み付けした [DayLoad.loadScore] を計算する。渡さない場合はすべて
/// 「中」の重みとして扱う。
List<DayLoad> computeWeekLoad({
  required DateTime from,
  required List<CalendarEvent> events,
  List<UpcomingItem> upcoming = const [],
  List<EventCategory> categories = const [],
  List<Todo> todos = const [],
  int days = 7,
}) {
  int weightFor(String categoryId) {
    if (categories.isEmpty) return CategoryLoadLevel.medium.weight;
    return findCategory(categories, categoryId).loadLevel.weight;
  }

  return [
    for (var i = 0; i < days; i++)
      () {
        final day = _day(from).add(Duration(days: i));
        var minutes = 0;
        var count = 0;
        var score = 0;
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
            score += weightFor(e.categoryId);
          }
        }
        final tests = upcoming
            .where((u) => u.isTest && _day(u.date) == day)
            .length;
        score += tests * _testLoadWeight;
        for (final t in todos) {
          if (t.done || t.dueDate == null) continue;
          if (_day(t.dueDate!) != day) continue;
          score += t.loadLevel.weight;
        }
        return DayLoad(
          day: day,
          busyMinutes: minutes,
          eventCount: count,
          testCount: tests,
          loadScore: score,
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
