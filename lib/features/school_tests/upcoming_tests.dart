/// これからのテスト・提出物を集める
library;

import '../timetable/day_timetable_resolver.dart';
import '../timetable/school_periods.dart';
import 'school_test.dart';
import 'weekly_lesson_test.dart';

/// 1件分
class UpcomingItem {
  const UpcomingItem({
    required this.date,
    required this.title,
    required this.kindLabel,
    required this.isTest,
    this.detail,
    this.period,
    this.source,
  });

  final DateTime date;

  /// 例：ECⅠ LEAP単語テスト
  final String title;

  /// 例：小テスト・定期テスト・提出物
  final String kindLabel;

  /// テストの仲間か（提出物・行事は false）
  final bool isTest;

  /// 範囲など（例：1201〜1300、p.20〜35）
  final String? detail;

  /// 時限（わからなければ null）
  final int? period;

  /// 手で登録したものなら、その元データ（編集画面を開くのに使う）
  final SchoolTest? source;

  /// 今日から何日後か（今日なら 0）
  int daysFrom(DateTime today) {
    final a = DateTime.utc(date.year, date.month, date.day);
    final b = DateTime.utc(today.year, today.month, today.day);
    return a.difference(b).inDays;
  }
}

/// from の日から days 日分の、テスト・提出物などを集める
///
/// resolver には、小テストの印を付けない「時間割だけの計算係」を渡す。
List<UpcomingItem> collectUpcoming({
  required DateTime from,
  required int days,
  required DayTimetableResolver resolver,
  required List<WeeklyLessonTestRule> rules,
  required List<SchoolTest> schoolTests,
}) {
  final start = DateTime(from.year, from.month, from.day);
  final end = DateTime(start.year, start.month, start.day + days);
  final calculators = [
    for (final rule in rules)
      WeeklyLessonTestCalculator(rule: rule, resolver: resolver),
  ];

  final items = <UpcomingItem>[];

  for (var i = 0; i < days; i++) {
    final date = DateTime(start.year, start.month, start.day + i);

    // 毎週のテスト（LEAP など）
    for (final calculator in calculators) {
      final o = calculator.occurrenceOn(date);
      if (o == null) continue;
      items.add(
        UpcomingItem(
          date: date,
          title: '${o.lesson.subject ?? o.rule.subject} ${o.rule.title}',
          kindLabel: SchoolTestKind.quiz.label,
          isTest: true,
          detail: o.rangeLabel,
          period: o.lesson.period,
        ),
      );
    }

    // 試験日課の日の試験科目
    final day = resolver.resolve(date);
    if (day.status == DayStatus.school && day.schedule == DaySchedule.exam) {
      for (final lesson in day.lessons) {
        if (lesson.subject == null) continue;
        items.add(
          UpcomingItem(
            date: date,
            title: '${day.note ?? '試験'} ${lesson.subject}',
            kindLabel: SchoolTestKind.regularExam.label,
            isTest: true,
            period: lesson.period,
          ),
        );
      }
    }
  }

  // 手で登録したもの
  for (final t in schoolTests) {
    final d = DateTime(t.date.year, t.date.month, t.date.day);
    if (d.isBefore(start) || !d.isBefore(end)) continue;
    items.add(
      UpcomingItem(
        date: d,
        title: t.displayTitle,
        kindLabel: t.kind.label,
        isTest: t.kind.isTest,
        detail: t.scope,
        period: t.period,
        source: t,
      ),
    );
  }

  // 日付順、同じ日は時限順（時限なしは先頭）
  items.sort((a, b) {
    final byDate = a.date.compareTo(b.date);
    if (byDate != 0) return byDate;
    return (a.period ?? 0).compareTo(b.period ?? 0);
  });
  return items;
}
