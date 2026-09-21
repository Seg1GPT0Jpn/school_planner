/// つづりの予定 ⇔ .ics の予定 の変換
library;

import '../events/calendar_event.dart';
import '../events/event_category.dart';
import 'ics.dart';

/// つづりの予定を .ics 用にする
IcsEvent icsFromEvent(CalendarEvent e) => IcsEvent(
  title: e.title,
  start: e.start,
  end: e.end,
  allDay: e.isAllDay,
  location: e.location,
  description: e.memo,
  uid: e.id == null ? null : '${e.id}@tsuzuri',
);

/// .ics の予定を、つづりの新しい予定にする（カテゴリは「その他」）
CalendarEvent eventFromIcs(IcsEvent e) => CalendarEvent(
  title: e.title,
  start: e.start,
  end: e.end,
  isAllDay: e.allDay,
  location: e.location,
  memo: e.description,
  categoryId: EventCategory.otherId,
);

/// 同じ予定か（名前と開始が同じなら同じとみなす）
String _key(String title, DateTime start, bool allDay) =>
    '${title.trim()}|${allDay ? 'D' : 'T'}|${start.toIso8601String()}';

/// 読み込む予定のうち、まだ無いものだけを返す
List<CalendarEvent> newEventsOnly(
  List<IcsEvent> incoming,
  List<CalendarEvent> existing,
) {
  final seen = {for (final e in existing) _key(e.title, e.start, e.isAllDay)};
  final out = <CalendarEvent>[];
  for (final i in incoming) {
    final k = _key(i.title, i.start, i.allDay);
    if (seen.add(k)) out.add(eventFromIcs(i));
  }
  return out;
}
