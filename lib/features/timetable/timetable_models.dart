/// 時間割に関するデータの形
library;

import 'school_periods.dart';
import 'week_cycle.dart';

/// 科目（例：現代の国語）と、それが属する教科（例：国語）
class Subject {
  const Subject({required this.name, required this.category});

  /// 科目名（時間割に表示する名前）
  final String name;

  /// 教科名（色分けなどに使う）
  final String category;
}

/// 通常時間割の1コマ（Ⅰ週/Ⅱ週 × 曜日 × 時限）
class TimetableSlot {
  const TimetableSlot({
    required this.weekType,
    required this.weekday,
    required this.period,
    required this.subject,
    this.room,
    this.teacher,
    this.memo,
  });

  final WeekType weekType;

  /// 曜日（DateTime.monday など）
  final int weekday;

  /// 何時間目か
  final int period;

  final String subject;
  final String? room;
  final String? teacher;
  final String? memo;
}

/// 学校休業日（夏休み・臨時休校など）。開始日と終了日を含む
class SchoolClosure {
  const SchoolClosure({
    required this.start,
    required this.end,
    required this.title,
  });

  final DateTime start;
  final DateTime end;
  final String title;

  /// その日がこの休業期間に含まれるか
  bool contains(DateTime date) {
    final day = dateOnly(date);
    return !day.isBefore(dateOnly(start)) && !day.isAfter(dateOnly(end));
  }
}

/// 特定日の変更の種類
enum PeriodChangeType {
  /// 差し替え・追加・教室変更・時間変更
  replace,

  /// 休講
  cancel,

  /// 2つの時限の入れ替え
  swap,
}

/// 特定日の、1つの時限に対する変更
class PeriodChange {
  /// 差し替え（書かなかった項目は元の授業のまま）
  const PeriodChange.replace({
    required this.period,
    this.subject,
    this.room,
    this.teacher,
    this.memo,
    this.start,
    this.end,
  }) : type = PeriodChangeType.replace,
       otherPeriod = null;

  /// 休講
  const PeriodChange.cancel({required this.period, this.memo})
    : type = PeriodChangeType.cancel,
      subject = null,
      room = null,
      teacher = null,
      start = null,
      end = null,
      otherPeriod = null;

  /// 入れ替え（時刻はそのまま、授業の中身だけを交換）
  const PeriodChange.swap({required this.period, required int this.otherPeriod})
    : type = PeriodChangeType.swap,
      subject = null,
      room = null,
      teacher = null,
      memo = null,
      start = null,
      end = null;

  final PeriodChangeType type;
  final int period;
  final int? otherPeriod;
  final String? subject;
  final String? room;
  final String? teacher;
  final String? memo;
  final ClockTime? start;
  final ClockTime? end;
}

/// 特定日の時間割変更（1日分）
class DayOverride {
  const DayOverride({
    required this.date,
    this.weekType,
    this.changes = const [],
    this.note,
  });

  final DateTime date;

  /// その日だけ使う時間割の週（例：Ⅰ週の中の1日だけⅡ週の時間割）
  ///
  /// null のときは、週単位override・自動判定の結果をそのまま使う。
  final WeekType? weekType;

  /// 時限ごとの変更の一覧（上から順に適用する）
  final List<PeriodChange> changes;

  /// その日全体のメモ（例：「文化祭準備のため」）
  final String? note;
}
