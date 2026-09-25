/// 毎週決まった授業で行うテスト（例：その週の最初の ECⅠ で LEAP 単語テスト）
library;

import 'dart:math' as math;

import '../timetable/day_timetable_resolver.dart';
import '../timetable/week_cycle.dart';

/// ルール
class WeeklyLessonTestRule {
  const WeeklyLessonTestRule({
    required this.id,
    required this.subject,
    required this.title,
    required this.baseWeekDate,
    required this.baseRangeStart,
    this.rangeStep = 100,
    this.skippedWeeks = const {},
    this.endNumber,
    this.startDate,
    this.weekday,
    this.extraWeeks = const {},
  });

  /// Firestore の ID
  final String id;

  /// どの科目の授業で行うか（例：ECⅠ）
  final String subject;

  /// テストの名前（例：LEAP単語テスト）
  final String title;

  /// 範囲の基準となる週（その週の中の日なら何日でもよい）
  final DateTime baseWeekDate;

  /// 基準の週の範囲の始まり（例：1201）
  final int baseRangeStart;

  /// 1回あたりに進む数（例：100）
  final int rangeStep;

  /// 「この週はなし」にした週（その週の月曜日の dateKey）
  final Set<String> skippedWeeks;

  /// 最後の番号（例：2300）。これを超えたらテストはおしまい。null なら終わりなし
  final int? endNumber;

  /// この日を含む週から始まる（それより前の週はテストなし）。null なら制限なし
  final DateTime? startDate;

  /// テストを行う曜日を固定する（1=月 〜 5=金）。
  /// null なら「その週で対象科目の授業が最初にある日」を自動で使う（従来どおり）。
  final int? weekday;

  /// 「時間が無くて同じ週にもう1回行った」週（その週の月曜日の dateKey）。
  /// この週から先の範囲の計算が、2回ぶん進んだものとして扱われる。
  /// （2回目のテスト自体は、通常の小テスト登録から手動で追加する）
  final Set<String> extraWeeks;
}

/// 計算結果：その週のテスト
class LessonTestOccurrence {
  const LessonTestOccurrence({
    required this.rule,
    required this.date,
    required this.lesson,
    required this.rangeStart,
  });

  final WeeklyLessonTestRule rule;

  /// テストの日
  final DateTime date;

  /// テストを行う授業
  final ResolvedLesson lesson;

  /// 範囲の始まり（例：1201）
  final int rangeStart;

  /// 範囲の終わり（例：1300）。最後の番号を超えないようにする
  int get rangeEnd {
    final end = rangeStart + rule.rangeStep - 1;
    final last = rule.endNumber;
    return last == null ? end : math.min(end, last);
  }

  /// 「1201〜1300」の形
  String get rangeLabel => '$rangeStart〜$rangeEnd';
}

/// ルールと時間割から、各週のテストを計算する
class WeeklyLessonTestCalculator {
  WeeklyLessonTestCalculator({required this.rule, required this.resolver});

  final WeeklyLessonTestRule rule;
  final DayTimetableResolver resolver;

  /// 同じ週を何度も計算しないための記録
  final Map<String, (DateTime, ResolvedLesson)?> _cache = {};

  /// その週（月〜金）で、最初の対象の授業を探す
  (DateTime, ResolvedLesson)? _firstLessonInWeek(DateTime monday) {
    final key = dateKey(monday);
    if (_cache.containsKey(key)) return _cache[key];

    (DateTime, ResolvedLesson)? found;

    // 曜日が固定されていれば、その日（1=月〜5=金）だけを見る。
    // 未指定なら従来どおり、週の中で対象科目が最初にある日を探す。
    final fixedWeekday = rule.weekday;
    final dayOffsets = fixedWeekday == null
        ? const [0, 1, 2, 3, 4]
        : [fixedWeekday - 1];

    for (final i in dayOffsets) {
      if (found != null) break;
      if (i < 0 || i > 4) continue;
      final day = monday.add(Duration(days: i));
      final timetable = resolver.resolve(day);

      // 休業日・祝日などは飛ばす
      if (timetable.status != DayStatus.school) continue;

      for (final lesson in timetable.lessons) {
        if (lesson.subject == rule.subject &&
            lesson.status != LessonStatus.cancelled) {
          found = (day, lesson);
          break;
        }
      }
    }

    _cache[key] = found;
    return found;
  }

  /// その週にテストがあるか（「なし」にした週や、対象の授業がない週は false）
  bool _hasTest(DateTime monday) =>
      !rule.skippedWeeks.contains(dateKey(monday)) &&
      _firstLessonInWeek(monday) != null;

  /// その週が、範囲の計算上「何回ぶん」進むか（通常は1、時間が無くて
  /// 同じ週にもう1回行った週は2、「なし」の週や授業のない週は0）
  int _weekWeight(DateTime monday) {
    if (!_hasTest(monday)) return 0;
    return rule.extraWeeks.contains(dateKey(monday)) ? 2 : 1;
  }

  /// その日を含む週のテスト（なければ null）
  LessonTestOccurrence? occurrenceInWeek(DateTime anyDateInWeek) {
    final monday = mondayOf(anyDateInWeek);
    if (rule.skippedWeeks.contains(dateKey(monday))) return null;

    // 始まる週より前はテストなし
    final start = rule.startDate;
    if (start != null && monday.isBefore(mondayOf(start))) return null;

    final first = _firstLessonInWeek(monday);
    if (first == null) return null;

    // 基準の週から、テストがあった週の数を数える
    final baseMonday = mondayOf(rule.baseWeekDate);
    var count = 0;
    int rangeStart;

    if (!monday.isBefore(baseMonday)) {
      for (
        var w = baseMonday;
        w.isBefore(monday);
        w = w.add(const Duration(days: 7))
      ) {
        count += _weekWeight(w);
      }
      rangeStart = rule.baseRangeStart + rule.rangeStep * count;
    } else {
      for (
        var w = monday;
        w.isBefore(baseMonday);
        w = w.add(const Duration(days: 7))
      ) {
        count += _weekWeight(w);
      }
      rangeStart = rule.baseRangeStart - rule.rangeStep * count;
    }

    // 最後の番号を超えたら、もうテストはない
    final last = rule.endNumber;
    if (last != null && rangeStart > last) return null;

    return LessonTestOccurrence(
      rule: rule,
      date: first.$1,
      lesson: first.$2,
      rangeStart: rangeStart,
    );
  }

  /// その日にテストがあれば返す
  LessonTestOccurrence? occurrenceOn(DateTime date) {
    final occurrence = occurrenceInWeek(date);
    if (occurrence == null) return null;
    final d = occurrence.date;
    final isSameDay =
        d.year == date.year && d.month == date.month && d.day == date.day;
    return isSameDay ? occurrence : null;
  }
}
