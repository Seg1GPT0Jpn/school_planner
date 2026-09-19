/// 初期データ（最初の1回だけ Firestore に登録する）
///
/// 登録したあとは、アプリの画面から修正する。
/// このファイルを書き換えても、登録済みのデータは変わらない。
library;

import 'timetable_models.dart';
import 'week_cycle.dart';

/// 教科・科目の一覧（1年生）
const List<Subject> initialSubjects = [
  Subject(name: '現代の国語', category: '国語'),
  Subject(name: '言語文化', category: '国語'),
  Subject(name: '数学Ⅰ', category: '数学'),
  Subject(name: '数学A', category: '数学'),
  Subject(name: 'ECⅠ', category: '英語'),
  Subject(name: '論表Ⅰ', category: '英語'),
  Subject(name: '化学基礎', category: '理科'),
  Subject(name: '生物基礎', category: '理科'),
  Subject(name: '公共', category: '社会'),
  Subject(name: '地理総合', category: '社会'),
  Subject(name: '情報Ⅰ', category: '情報'),
  Subject(name: '体育', category: '副教科'),
  Subject(name: '保健', category: '副教科'),
  Subject(name: '芸術', category: '副教科'),
  Subject(name: '家庭総合', category: '副教科'),
  Subject(name: '総合', category: '副教科'),
];

/// 1週間分の時間割を TimetableSlot の一覧に変換する
List<TimetableSlot> _week(WeekType weekType, Map<int, List<String>> days) {
  return [
    for (final day in days.entries)
      for (var i = 0; i < day.value.length; i++)
        TimetableSlot(
          weekType: weekType,
          weekday: day.key,
          period: i + 1,
          subject: day.value[i],
        ),
  ];
}

/// 1年間の基本時間割
final List<TimetableSlot> initialSlots = [
  ..._week(WeekType.one, {
    DateTime.monday: ['体育', '現代の国語', '数学Ⅰ', 'ECⅠ', '総合'],
    DateTime.tuesday: ['現代の国語', '地理総合', 'ECⅠ', '化学基礎', '芸術'],
    DateTime.wednesday: ['公共', '生物基礎', '地理総合', '数学Ⅰ'],
    DateTime.thursday: ['情報Ⅰ', '化学基礎', '体育', '論表Ⅰ', '言語文化'],
    DateTime.friday: ['家庭総合', '数学A', '公共', '言語文化'],
  }),
  ..._week(WeekType.two, {
    DateTime.monday: ['公共', 'ECⅠ', '論表Ⅰ', '数学Ⅰ', '総合'],
    DateTime.tuesday: ['ECⅠ', '情報Ⅰ', '生物基礎', '体育', '言語文化'],
    DateTime.wednesday: ['生物基礎', '現代の国語', 'ECⅠ', '数学Ⅰ'],
    DateTime.thursday: ['数学Ⅰ', '体育', '化学基礎', '数学A', '保健'],
    DateTime.friday: ['地理総合', '数学A', '家庭総合', '芸術'],
  }),
];

/// 基準日：2026年9月7日（月）の週はⅠ週
final List<WeekAnchor> initialAnchors = [
  WeekAnchor(date: DateTime(2026, 9, 7), weekType: WeekType.one),
];

/// 週単位の例外：10/12〜の週（10/13〜16）は、その週だけⅠ週
const Map<String, WeekType> initialWeekOverrides = {'2026-10-12': WeekType.one};

/// 特定日の例外：10/19（月）だけⅡ週の時間割
final List<DayOverride> initialDayOverrides = [
  DayOverride(
    date: DateTime(2026, 10, 19),
    weekType: WeekType.two,
    note: 'この日だけⅡ週の時間割',
  ),
];
