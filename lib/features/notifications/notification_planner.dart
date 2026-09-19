/// どの通知を、いつ、どんな内容で出すかを決める
library;

import '../events/calendar_event.dart';
import '../school_tests/upcoming_tests.dart';
import '../timetable/day_timetable_resolver.dart';
import '../timetable/school_periods.dart';
import '../todo/todo.dart';

class PlannedNotification {
  const PlannedNotification(this.id, this.time, this.title, this.body);
  final int id;
  final DateTime time;
  final String title;
  final String body;
}

/// 通知の時刻の設定
const int eveningHour = 21, eveningMinute = 30;
const int morningHour = 7, morningMinute = 0;
const Duration eventReminder = Duration(minutes: 30);

DateTime _day(DateTime d) => DateTime(d.year, d.month, d.day);
bool _same(DateTime a, DateTime b) => _day(a) == _day(b);
String _hm(DateTime d) => '${d.hour}:${d.minute.toString().padLeft(2, '0')}';

/// その日の内容（学校・テスト・予定・ToDo）を行の一覧にする
List<String> _dayLines(
  DateTime d,
  DayTimetableResolver resolver,
  List<UpcomingItem> upcoming,
  List<CalendarEvent> events,
  List<Todo> todos,
) {
  final lines = <String>[];
  final day = resolver.resolve(d);
  switch (day.status) {
    case DayStatus.school:
      final special = day.schedule == DaySchedule.regular
          ? ''
          : '・${day.schedule.label}';
      lines.add('🏫 ${day.weekType?.label ?? ''}$special');
    case DayStatus.holiday:
      lines.add('🎌 ${day.holidayName}');
    case DayStatus.closed:
      lines.add('🏠 ${day.closureTitle}');
    default:
      break;
  }
  for (final u in upcoming) {
    if (_same(u.date, d)) {
      lines.add('📝 ${u.title}${u.detail == null ? '' : ' ${u.detail}'}');
    }
  }
  final dayEvents = [
    for (final e in events)
      if (e.occursOn(d)) e,
  ]..sort((a, b) => a.start.compareTo(b.start));
  for (final e in dayEvents) {
    lines.add(e.isAllDay ? '🗓 ${e.title}' : '🕒 ${_hm(e.start)} ${e.title}');
  }
  for (final t in todos) {
    if (!t.done && t.dueDate != null && _same(t.dueDate!, d)) {
      lines.add('✅ 期限：${t.title}');
    }
  }
  return lines;
}

/// now から days 日分の通知を決める
List<PlannedNotification> planNotifications({
  required DateTime now,
  int days = 14,
  required DayTimetableResolver resolver,
  required List<UpcomingItem> upcoming,
  required List<CalendarEvent> events,
  required List<Todo> todos,
  List<String> Function(DateTime date)? belongingsOn,
}) {
  final result = <PlannedNotification>[];
  var id = 1;

  for (var i = 0; i <= days; i++) {
    final d = DateTime(now.year, now.month, now.day + i);
    final lines = _dayLines(d, resolver, upcoming, events, todos);
    final hasItems = lines.any(
      (l) => !l.startsWith('🏫') && !l.startsWith('🎌') && !l.startsWith('🏠'),
    );
    final isSchool = lines.any((l) => l.startsWith('🏫'));

    // 当日の朝（期限切れの ToDo も入れる）
    final overdue = todos.where((t) => t.isOverdue(d)).length;
    final morning = [...lines, if (overdue > 0) '⚠ 期限切れの ToDo：$overdue件'];
    final morningTime = DateTime(
      d.year,
      d.month,
      d.day,
      morningHour,
      morningMinute,
    );
    if (morningTime.isAfter(now) && (isSchool || hasItems || overdue > 0)) {
      result.add(
        PlannedNotification(
          id++,
          morningTime,
          '今日（${d.month}/${d.day}）',
          morning.join('\n'),
        ),
      );
    }

    // 前日の夜
    final eveningTime = DateTime(
      d.year,
      d.month,
      d.day - 1,
      eveningHour,
      eveningMinute,
    );
    if (eveningTime.isAfter(now) && (isSchool || hasItems)) {
      result.add(
        PlannedNotification(
          id++,
          eveningTime,
          '明日（${d.month}/${d.day}）',
          [
            ...lines,
            if (belongingsOn != null && belongingsOn(d).isNotEmpty)
              '🎒 ${belongingsOn(d).join('・')}',
          ].join('\n'),
        ),
      );
    }
  }

  // 予定の30分前
  final limit = DateTime(now.year, now.month, now.day + days + 1);
  for (final e in events) {
    if (e.isAllDay) continue;
    final t = e.start.subtract(eventReminder);
    if (t.isAfter(now) && t.isBefore(limit)) {
      result.add(
        PlannedNotification(
          id++,
          t,
          '${_hm(e.start)} ${e.title}',
          '${eventReminder.inMinutes}分後に始まります${e.location == null ? '' : '（${e.location}）'}',
        ),
      );
    }
  }

  return result;
}
