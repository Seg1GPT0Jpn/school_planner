/// カレンダーの標準形式（.ics）の読み書き
///
/// 画面のことは知らない、ただの文字の変換なのでテストしやすい。
library;

import 'dart:convert';

/// .ics の中の予定1件
class IcsEvent {
  const IcsEvent({
    required this.title,
    required this.start,
    required this.end,
    this.allDay = false,
    this.location,
    this.description,
    this.uid,
  });

  final String title;
  final DateTime start;

  /// 終わり（終日のときは「最後の日」。次の日ではない）
  final DateTime end;

  final bool allDay;
  final String? location;
  final String? description;
  final String? uid;
}

// ───────────────────────── 書き出し ─────────────────────────

String _two(int n) => n.toString().padLeft(2, '0');

String _date(DateTime d) => '${d.year}${_two(d.month)}${_two(d.day)}';

String _dateTime(DateTime d) =>
    '${_date(d)}T${_two(d.hour)}${_two(d.minute)}${_two(d.second)}';

String _utc(DateTime d) {
  final u = d.toUtc();
  return '${_dateTime(u)}Z';
}

/// .ics で意味のある記号を逃がす
String escapeIcsText(String s) => s
    .replaceAll('\\', '\\\\')
    .replaceAll(';', '\\;')
    .replaceAll(',', '\\,')
    .replaceAll('\r\n', '\\n')
    .replaceAll('\n', '\\n');

String unescapeIcsText(String s) {
  final out = StringBuffer();
  for (var i = 0; i < s.length; i++) {
    if (s[i] != '\\' || i + 1 >= s.length) {
      out.write(s[i]);
      continue;
    }
    i++;
    switch (s[i]) {
      case 'n':
      case 'N':
        out.write('\n');
      default:
        out.write(s[i]);
    }
  }
  return out.toString();
}

/// 長い行を折り返す（.ics は1行75バイトまで）
String foldIcsLine(String line) {
  final buf = StringBuffer();
  var bytes = 0;
  for (final rune in line.runes) {
    final ch = String.fromCharCode(rune);
    final n = utf8.encode(ch).length;
    if (bytes + n > 72) {
      buf.write('\r\n ');
      bytes = 1;
    }
    buf.write(ch);
    bytes += n;
  }
  return buf.toString();
}

/// 折り返された行をもとにもどす
String unfoldIcs(String text) => text.replaceAll(RegExp(r'\r?\n[ \t]'), '');

/// 予定の一覧を .ics の文字にする
String buildIcs(
  List<IcsEvent> events, {
  String timeZone = 'Asia/Tokyo',
  DateTime? stamp,
  String calendarName = 'つづり',
}) {
  final now = stamp ?? DateTime.now();
  final lines = <String>[
    'BEGIN:VCALENDAR',
    'VERSION:2.0',
    'PRODID:-//tsuzuri//JP',
    'CALSCALE:GREGORIAN',
    'METHOD:PUBLISH',
    'X-WR-CALNAME:${escapeIcsText(calendarName)}',
    'X-WR-TIMEZONE:$timeZone',
  ];

  var n = 0;
  for (final e in events) {
    n++;
    final uid = e.uid ?? 'tsuzuri-$n-${_dateTime(e.start)}@tsuzuri';
    lines.addAll([
      'BEGIN:VEVENT',
      'UID:$uid',
      'DTSTAMP:${_utc(now)}',
      if (e.allDay) ...[
        'DTSTART;VALUE=DATE:${_date(e.start)}',
        // 終日の終わりは「次の日」を書く決まり
        'DTEND;VALUE=DATE:'
            '${_date(DateTime(e.end.year, e.end.month, e.end.day + 1))}',
      ] else ...[
        'DTSTART;TZID=$timeZone:${_dateTime(e.start)}',
        'DTEND;TZID=$timeZone:${_dateTime(e.end)}',
      ],
      'SUMMARY:${escapeIcsText(e.title)}',
      if (e.location != null && e.location!.isNotEmpty)
        'LOCATION:${escapeIcsText(e.location!)}',
      if (e.description != null && e.description!.isNotEmpty)
        'DESCRIPTION:${escapeIcsText(e.description!)}',
      'END:VEVENT',
    ]);
  }

  lines.add('END:VCALENDAR');
  return '${lines.map(foldIcsLine).join('\r\n')}\r\n';
}

// ───────────────────────── 読み込み ─────────────────────────

/// 20260921 / 20260921T090000 / 20260921T000000Z を読む
DateTime? parseIcsDate(String value) {
  final v = value.trim();
  final m = RegExp(r'^(\d{4})(\d{2})(\d{2})(?:T(\d{2})(\d{2})(\d{2})(Z?))?$')
      .firstMatch(v);
  if (m == null) return null;
  final year = int.parse(m.group(1)!);
  final month = int.parse(m.group(2)!);
  final day = int.parse(m.group(3)!);
  if (m.group(4) == null) return DateTime(year, month, day);
  final hour = int.parse(m.group(4)!);
  final minute = int.parse(m.group(5)!);
  final second = int.parse(m.group(6)!);
  if (m.group(7) == 'Z') {
    return DateTime.utc(year, month, day, hour, minute, second).toLocal();
  }
  return DateTime(year, month, day, hour, minute, second);
}

class _Prop {
  const _Prop(this.value, this.params);
  final String value;
  final Map<String, String> params;
}

IcsEvent? _toEvent(Map<String, _Prop> p) {
  final dtStart = p['DTSTART'];
  if (dtStart == null) return null;
  final start = parseIcsDate(dtStart.value);
  if (start == null) return null;

  final allDay =
      dtStart.params['VALUE'] == 'DATE' || !dtStart.value.contains('T');

  final dtEnd = p['DTEND'];
  var end = dtEnd == null ? null : parseIcsDate(dtEnd.value);
  if (end == null) {
    end = allDay ? start : start.add(const Duration(hours: 1));
  } else if (allDay) {
    // .ics の終日の終わりは「次の日」なので、1日もどす
    end = DateTime(end.year, end.month, end.day - 1);
    if (end.isBefore(start)) end = start;
  }

  return IcsEvent(
    title: unescapeIcsText(p['SUMMARY']?.value ?? '').trim().isEmpty
        ? '(名前なし)'
        : unescapeIcsText(p['SUMMARY']!.value).trim(),
    start: start,
    end: end,
    allDay: allDay,
    location: p['LOCATION'] == null
        ? null
        : unescapeIcsText(p['LOCATION']!.value),
    description: p['DESCRIPTION'] == null
        ? null
        : unescapeIcsText(p['DESCRIPTION']!.value),
    uid: p['UID']?.value,
  );
}

/// .ics の文字から予定を読む（読めない行は飛ばす）
List<IcsEvent> parseIcs(String text) {
  final events = <IcsEvent>[];
  Map<String, _Prop>? current;

  for (final raw in unfoldIcs(text).split(RegExp(r'\r?\n'))) {
    final line = raw.trimRight();
    if (line.isEmpty) continue;
    final upper = line.toUpperCase();
    if (upper == 'BEGIN:VEVENT') {
      current = {};
      continue;
    }
    if (upper == 'END:VEVENT') {
      if (current != null) {
        final e = _toEvent(current);
        if (e != null) events.add(e);
      }
      current = null;
      continue;
    }
    if (current == null) continue;

    final colon = line.indexOf(':');
    if (colon < 0) continue;
    final head = line.substring(0, colon).split(';');
    final name = head.first.toUpperCase().trim();
    final params = <String, String>{};
    for (final part in head.skip(1)) {
      final eq = part.indexOf('=');
      if (eq > 0) {
        params[part.substring(0, eq).toUpperCase().trim()] = part
            .substring(eq + 1)
            .trim();
      }
    }
    current[name] = _Prop(line.substring(colon + 1), params);
  }

  return events;
}
