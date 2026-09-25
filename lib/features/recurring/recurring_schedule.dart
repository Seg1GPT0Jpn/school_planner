/// 定期の予定（塾・部活など、毎週決まった曜日と時刻の予定）
library;

import '../events/calendar_event.dart';
import '../events/event_category.dart';
import '../timetable/school_periods.dart';
import '../timetable/week_cycle.dart';

const String recurringIdPrefix = 'recurring:';

DateTime _day(DateTime d) => DateTime(d.year, d.month, d.day);

/// 毎回のミニテストの設定
class RecurringTestConfig {
  const RecurringTestConfig({
    required this.title,
    this.baseDate,
    this.baseStart,
    this.step = 50,
    this.withReview = false,
    this.end,
  });

  final String title;
  final DateTime? baseDate;
  final int? baseStart;
  final int step;
  final bool withReview;

  /// 最後の番号（例：2700）。これを超えたらテストはおしまい。null なら終わりなし
  final int? end;

  bool get hasRange => baseDate != null && baseStart != null;
}

class RecurringSchedule {
  /// 曜日は weekdays（複数）か weekday（1つ）のどちらかで指定する
  RecurringSchedule({
    this.id,
    required this.title,
    Set<int>? weekdays,
    int? weekday,
    required this.start,
    required this.end,
    this.afterSchoolMinutes,
    this.validFrom,
    this.validUntil,
    this.categoryId = EventCategory.otherId,
    this.subject,
    this.location,
    this.skippedDates = const {},
    this.test,
  }) : weekdays = weekdays ?? {weekday ?? DateTime.monday};

  final String? id;
  final String title;

  /// 曜日（1=月 〜 7=日）。複数可
  final Set<int> weekdays;

  final ClockTime start;
  final ClockTime end;

  /// null なら [start] の固定時刻で始まる。数を入れると、その日の放課後
  /// （授業の終わる時刻）の何分後に始めるかを表す（長さは end − start のまま）。
  /// 授業のない日（土日・祝日など）は「放課後」が決まらないので、その日はお休みになる。
  final int? afterSchoolMinutes;
  final DateTime? validFrom;
  final DateTime? validUntil;
  final String categoryId;

  /// 教科（塾の科目など）。未設定なら null
  final String? subject;
  final String? location;
  final Set<String> skippedDates;
  final RecurringTestConfig? test;

  /// 曜日を「月・火」のような文字にする
  String get weekdayText {
    final list = weekdays.toList()..sort();
    return list.map(weekdayLabelOf).join('・');
  }

  bool occursOn(DateTime date) {
    final d = _day(date);
    if (!weekdays.contains(d.weekday)) return false;
    if (validFrom != null && d.isBefore(_day(validFrom!))) return false;
    if (validUntil != null && d.isAfter(_day(validUntil!))) return false;
    if (skippedDates.contains(dateKey(d))) return false;
    // 「放課後の◯分後」指定で、授業のない日（土日・祝日など）は
    // 基準になる「放課後」自体がないので、その日はお休みにする。
    if (afterSchoolMinutes != null && schoolEndMinutesOn(d) == null) {
      return false;
    }
    return true;
  }

  CalendarEvent toEvent(DateTime date) {
    final d = _day(date);
    final durationMinutes = end.totalMinutes - start.totalMinutes;
    final startMinutes = afterSchoolMinutes != null
        ? (schoolEndMinutesOn(d) ?? start.totalMinutes) + afterSchoolMinutes!
        : start.totalMinutes;
    return CalendarEvent(
      id: '$recurringIdPrefix$id:${dateKey(d)}',
      title: title,
      start: d.add(Duration(minutes: startMinutes)),
      end: d.add(Duration(minutes: startMinutes + durationMinutes)),
      location: location,
      categoryId: categoryId,
    );
  }

  String? validate() {
    if (title.trim().isEmpty) return '名前を入力してください';
    if (weekdays.isEmpty) return '曜日を1つ以上選んでください';
    if (end.totalMinutes <= start.totalMinutes) {
      return '終了時刻は開始時刻より後にしてください';
    }
    if (validFrom != null &&
        validUntil != null &&
        _day(validUntil!).isBefore(_day(validFrom!))) {
      return '終了日は開始日より後にしてください';
    }
    if (test != null && test!.title.trim().isEmpty) {
      return 'ミニテストの名前を入力してください';
    }
    return null;
  }
}

/// 曜日の1文字（1=月 〜 7=日）
String weekdayLabelOf(int weekday) =>
    const ['月', '火', '水', '木', '金', '土', '日'][weekday - 1];

List<CalendarEvent> expandRecurring(
  List<RecurringSchedule> schedules,
  DateTime from,
  DateTime to,
) {
  final result = <CalendarEvent>[];
  for (
    var d = _day(from);
    d.isBefore(to);
    d = DateTime(d.year, d.month, d.day + 1)
  ) {
    for (final s in schedules) {
      if (s.occursOn(d)) result.add(s.toEvent(d));
    }
  }
  return result;
}

bool isRecurringInstance(CalendarEvent e) =>
    e.id?.startsWith(recurringIdPrefix) ?? false;

(String, DateTime)? parseRecurringInstance(CalendarEvent e) {
  if (!isRecurringInstance(e)) return null;
  final rest = e.id!.substring(recurringIdPrefix.length);
  final i = rest.lastIndexOf(':');
  final p = rest.substring(i + 1).split('-').map(int.parse).toList();
  return (rest.substring(0, i), DateTime(p[0], p[1], p[2]));
}
