/// 定期の予定で毎回行うミニテストの計算
library;

import 'dart:math' as math;

import '../events/calendar_event.dart';
import '../school_tests/school_test.dart';
import '../school_tests/upcoming_tests.dart';
import 'recurring_schedule.dart';

DateTime _day(DateTime d) => DateTime(d.year, d.month, d.day);
DateTime _next(DateTime d) => DateTime(d.year, d.month, d.day + 1);

class RecurringTestOccurrence {
  const RecurringTestOccurrence(this.config, this.start);

  final RecurringTestConfig config;

  /// 範囲の始まり（範囲なしのテストは null）
  final int? start;

  String get rangeText {
    final s = start;
    if (s == null) return '';
    final last = config.end;
    final e = s + config.step - 1;
    final text = '$s〜${last == null ? e : math.min(e, last)}';
    if (!config.withReview || s <= config.baseStart!) return text;
    return '$text・前回 ${s - config.step}〜${s - 1}';
  }

  String get label =>
      rangeText.isEmpty ? config.title : '${config.title} $rangeText';
}

/// その日のミニテスト（なければ null）
RecurringTestOccurrence? recurringTestOn(RecurringSchedule s, DateTime date) {
  final config = s.test;
  final d = _day(date);
  if (config == null || !s.occursOn(d)) return null;
  if (!config.hasRange) return RecurringTestOccurrence(config, null);

  final base = _day(config.baseDate!);
  var count = 0;
  int start;
  if (!d.isBefore(base)) {
    for (var x = base; x.isBefore(d); x = _next(x)) {
      if (s.occursOn(x)) count++;
    }
    start = config.baseStart! + config.step * count;
  } else {
    for (var x = d; x.isBefore(base); x = _next(x)) {
      if (s.occursOn(x)) count++;
    }
    start = config.baseStart! - config.step * count;
  }
  if (start < 1) return null;
  // 最後の番号を超えたら、もうテストはない
  final last = config.end;
  if (last != null && start > last) return null;
  return RecurringTestOccurrence(config, start);
}

/// カレンダー用に展開し、ミニテストがある回は名前に付け足す
List<CalendarEvent> expandRecurringWithTests(
  List<RecurringSchedule> schedules,
  DateTime from,
  DateTime to,
) {
  final result = <CalendarEvent>[];
  for (var d = _day(from); d.isBefore(to); d = _next(d)) {
    for (final s in schedules) {
      if (!s.occursOn(d)) continue;
      final e = s.toEvent(d);
      final o = recurringTestOn(s, d);
      result.add(
        o == null
            ? e
            : CalendarEvent(
                id: e.id,
                title: '${e.title}｜${o.label}',
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
  int days,
) {
  final items = <UpcomingItem>[];
  for (var i = 0; i < days; i++) {
    final d = DateTime(from.year, from.month, from.day + i);
    for (final s in schedules) {
      final o = recurringTestOn(s, d);
      if (o == null) continue;
      items.add(
        UpcomingItem(
          date: d,
          title: '${s.title} ${o.config.title}',
          kindLabel: SchoolTestKind.quiz.label,
          isTest: true,
          detail: o.rangeText.isEmpty ? null : o.rangeText,
        ),
      );
    }
  }
  return items;
}
