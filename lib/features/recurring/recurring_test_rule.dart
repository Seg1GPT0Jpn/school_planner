/// 定期の予定で毎回行うテスト（例：塾の英語で EEVI 単語テスト）
library;

import '../events/calendar_event.dart';
import '../school_tests/school_test.dart';
import '../school_tests/upcoming_tests.dart';
import 'recurring_schedule.dart';

class RecurringTestRule {
  const RecurringTestRule({
    required this.titleKeyword,
    required this.testTitle,
    required this.baseDate,
    required this.baseStart,
    this.step = 50,
  });

  /// 定期の予定の名前にこの文字が入っていたら対象（例：英語）
  final String titleKeyword;
  final String testTitle;

  /// この日の範囲が baseStart から
  final DateTime baseDate;
  final int baseStart;
  final int step;
}

/// EEVI：9/18 が 1〜50、50語ずつ
final eeviRule = RecurringTestRule(
  titleKeyword: '英語',
  testTitle: 'EEVI',
  baseDate: DateTime(2026, 9, 18),
  baseStart: 1,
);

DateTime _day(DateTime d) => DateTime(d.year, d.month, d.day);
DateTime _next(DateTime d) => DateTime(d.year, d.month, d.day + 1);

class RecurringTestOccurrence {
  const RecurringTestOccurrence(this.rule, this.start);

  final RecurringTestRule rule;

  /// 記述（新しい範囲）の始まり
  final int start;

  int get end => start + rule.step - 1;

  /// 選択（前回の範囲）。初回はなし
  bool get hasReview => start > rule.baseStart;

  String get rangeText => hasReview
      ? '記述 $start〜$end・選択 ${start - rule.step}〜${start - 1}'
      : '記述 $start〜$end';

  String get label => '${rule.testTitle} $rangeText';
}

/// その日のその定期の予定で行うテスト（なければ null）
RecurringTestOccurrence? recurringTestOn(
  RecurringSchedule s,
  DateTime date,
  RecurringTestRule rule,
) {
  final d = _day(date);
  if (!s.title.contains(rule.titleKeyword) || !s.occursOn(d)) return null;

  final base = _day(rule.baseDate);
  var count = 0;
  int start;
  if (!d.isBefore(base)) {
    for (var x = base; x.isBefore(d); x = _next(x)) {
      if (s.occursOn(x)) count++;
    }
    start = rule.baseStart + rule.step * count;
  } else {
    for (var x = d; x.isBefore(base); x = _next(x)) {
      if (s.occursOn(x)) count++;
    }
    start = rule.baseStart - rule.step * count;
  }
  return start < 1 ? null : RecurringTestOccurrence(rule, start);
}

/// 定期の予定をカレンダー用に展開し、テストがある回は名前に付け足す
List<CalendarEvent> expandRecurringWithTests(
  List<RecurringSchedule> schedules,
  DateTime from,
  DateTime to, {
  List<RecurringTestRule>? rules,
}) {
  final result = <CalendarEvent>[];
  for (var d = _day(from); d.isBefore(to); d = _next(d)) {
    for (final s in schedules) {
      if (!s.occursOn(d)) continue;
      final e = s.toEvent(d);
      final labels = [
        for (final r in rules ?? [eeviRule])
          if (recurringTestOn(s, d, r) case final o?) o.label,
      ];
      result.add(
        labels.isEmpty
            ? e
            : CalendarEvent(
                id: e.id,
                title: '${e.title}｜${labels.join(' / ')}',
                start: e.start,
                end: e.end,
                location: e.location,
                categoryId: e.categoryId,
              ),
      );
    }
  }
  return result;
}

/// ホームの「これからのテスト」用
List<UpcomingItem> upcomingRecurringTests(
  List<RecurringSchedule> schedules,
  DateTime from,
  int days, {
  List<RecurringTestRule>? rules,
}) {
  final items = <UpcomingItem>[];
  for (var i = 0; i < days; i++) {
    final d = DateTime(from.year, from.month, from.day + i);
    for (final s in schedules) {
      for (final r in rules ?? [eeviRule]) {
        final o = recurringTestOn(s, d, r);
        if (o == null) continue;
        items.add(
          UpcomingItem(
            date: d,
            title: '${s.title} ${r.testTitle}',
            kindLabel: SchoolTestKind.quiz.label,
            isTest: true,
            detail: o.rangeText,
          ),
        );
      }
    }
  }
  return items;
}
