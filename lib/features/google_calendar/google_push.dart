/// つづりの予定・テスト・塾などを、Google の「つづり」カレンダーに書き込む
///
/// つづりが「正」。Google の「つづり」カレンダー側で直した内容は、次の同期で上書きされる。
library;

import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';

import '../events/calendar_event.dart';
import '../events/event_repository.dart';
import '../recurring/recurring_repository.dart';
import '../recurring/recurring_test_rule.dart';
import '../school_tests/school_test.dart';
import '../school_tests/weekly_lesson_test.dart';
import '../timetable/day_timetable_resolver.dart';
import '../timetable/timetable_repository.dart';
import '../timetable/week_cycle.dart';
import 'google_calendar_service.dart';
import 'google_sync.dart';

DateTime _at(DateTime day, int minutes) =>
    DateTime(day.year, day.month, day.day).add(Duration(minutes: minutes));

/// Google に送る予定の形
Map<String, dynamic> googleEventBody({
  required String title,
  required DateTime start,
  required DateTime end,
  bool allDay = false,
  String? location,
  String? memo,
}) => {
  'summary': title,
  if (allDay) ...{
    'start': {'date': dateKey(start)},
    // Google の終日の終わりは「最終日の翌日」
    'end': {'date': dateKey(DateTime(end.year, end.month, end.day + 1))},
  } else ...{
    'start': {
      'dateTime': start.toUtc().toIso8601String(),
      'timeZone': 'Asia/Tokyo',
    },
    'end': {
      'dateTime': end.toUtc().toIso8601String(),
      'timeZone': 'Asia/Tokyo',
    },
  },
  'location': location ?? '',
  'description': [
    if (memo != null && memo.trim().isNotEmpty) memo.trim(),
    '（つづりから自動で書き込み）',
  ].join('\n'),
};

/// 書き込むものを全部集める（キー → Google に送る形）
///
/// キーの頭：e_ 自分の予定、r_ 定期の予定、t_ 小テスト・行事など、w_ 毎週の単語テスト
Map<String, Map<String, dynamic>> buildPushItems({
  required DateTime from,
  required DateTime to,
  List<CalendarEvent> ownEvents = const [],
  List<CalendarEvent> recurringEvents = const [],
  List<SchoolTest> tests = const [],
  List<LessonTestOccurrence> weeklyTests = const [],
  DayTimetable Function(DateTime day)? resolve,
}) {
  bool inRange(DateTime start, DateTime end) =>
      !end.isBefore(from) && start.isBefore(to);

  final items = <String, Map<String, dynamic>>{};

  for (final e in ownEvents) {
    if (e.id == null || isGoogleEvent(e) || !inRange(e.start, e.end)) continue;
    items['e_${e.id}'] = googleEventBody(
      title: e.title,
      start: e.start,
      end: e.end,
      allDay: e.isAllDay,
      location: e.location,
      memo: e.memo,
    );
  }

  for (final e in recurringEvents) {
    if (e.id == null || !inRange(e.start, e.end)) continue;
    items['r_${e.id!.replaceAll(':', '_')}'] = googleEventBody(
      title: e.title,
      start: e.start,
      end: e.end,
      location: e.location,
    );
  }

  for (final t in tests) {
    if (t.id == null || !inRange(t.date, t.date)) continue;
    final title = [
      '【${t.kind.label}】${t.displayTitle}',
      if (t.scope != null && t.scope!.trim().isNotEmpty) t.scope!.trim(),
    ].join(' ');
    // 時限が分かれば、その授業の時刻に置く
    final lesson = (t.period == null || resolve == null)
        ? null
        : resolve(t.date).lessons
              .where((l) => l.period == t.period)
              .firstOrNull;
    final body = lesson != null
        ? googleEventBody(
            title: title,
            start: _at(t.date, lesson.start.totalMinutes),
            end: _at(t.date, lesson.end.totalMinutes),
            memo: t.memo,
          )
        : t.startTime != null
        ? googleEventBody(
            title: title,
            start: _at(t.date, t.startTime!.totalMinutes),
            end: _at(t.date, t.startTime!.totalMinutes + 60),
            memo: t.memo,
          )
        : googleEventBody(
            title: title,
            start: t.date,
            end: t.date,
            allDay: true,
            memo: t.memo,
          );
    items['t_${t.id}'] = body;
  }

  for (final o in weeklyTests) {
    if (!inRange(o.date, o.date)) continue;
    items['w_${o.rule.id}_${dateKey(mondayOf(o.date))}'] = googleEventBody(
      title: '【小テスト】${o.rule.title} ${o.rangeLabel}',
      start: _at(o.date, o.lesson.start.totalMinutes),
      end: _at(o.date, o.lesson.end.totalMinutes),
    );
  }

  return items;
}

/// 書き込みの結果
class PushResult {
  const PushResult(this.added, this.updated, this.deleted);
  final int added, updated, deleted;
  int get total => added + updated + deleted;
}

/// Google の「つづり」カレンダーに書き込む（前回との違いだけ送る）
Future<PushResult> pushToGoogle(String uid, String calendarId) async {
  final db = FirebaseFirestore.instance;
  final user = db.collection('users').doc(uid);
  final pushed = user.collection('google_push');
  final service = GoogleCalendarService.instance;

  // 期間：先月の頭〜半年後
  final now = DateTime.now();
  final from = DateTime(now.year, now.month - 1, 1);
  final to = DateTime(now.year, now.month + 6, 1);

  // いまのつづりのデータ
  final data = await TimetableRepository(uid: uid).watch().first;
  final own = await EventRepository(uid: uid).watchAll().first;
  final schedules = await RecurringRepository(uid: uid).watch().first;
  final weekly = <LessonTestOccurrence>[];
  for (final rule in data.activeRules) {
    final calc = WeeklyLessonTestCalculator(
      rule: rule,
      resolver: data.baseResolver,
    );
    for (
      var w = mondayOf(from);
      w.isBefore(to);
      w = DateTime(w.year, w.month, w.day + 7)
    ) {
      final o = calc.occurrenceInWeek(w);
      if (o != null) weekly.add(o);
    }
  }
  final resolver = data.resolver;
  final wanted = buildPushItems(
    from: from,
    to: to,
    ownEvents: own,
    recurringEvents: expandRecurringWithTests(schedules, from, to),
    tests: data.schoolTests,
    weeklyTests: weekly,
    resolve: resolver.resolve,
  );

  // 前回書き込んだもの（キー → Google の ID と中身）
  final before = {for (final d in (await pushed.get()).docs) d.id: d.data()};

  var added = 0, updated = 0, deleted = 0;
  final jobs = <Future<void> Function()>[];

  wanted.forEach((key, body) {
    final hash = jsonEncode(body);
    final old = before[key];
    if (old == null) {
      jobs.add(() async {
        final id = await service.insertEvent(calendarId, body);
        await pushed.doc(key).set({
          'eventId': id,
          'hash': hash,
          'end': bodyEnd(body)?.toIso8601String(),
        });
        added++;
      });
    } else if (old['hash'] != hash) {
      jobs.add(() async {
        final eventId = old['eventId'] as String;
        try {
          await service.updateEvent(calendarId, eventId, body);
          await pushed.doc(key).set({
            'eventId': eventId,
            'hash': hash,
            'end': bodyEnd(body)?.toIso8601String(),
          });
        } on GoogleApiException catch (e) {
          // Google 側で消されていたら、作り直す
          if (!e.isGone) rethrow;
          final id = await service.insertEvent(calendarId, body);
          await pushed.doc(key).set({
            'eventId': id,
            'hash': hash,
            'end': bodyEnd(body)?.toIso8601String(),
          });
        }
        updated++;
      });
    }
  });

  for (final entry in before.entries) {
    if (wanted.containsKey(entry.key)) continue;
    // 期間より前に終わったもの（過去の予定）は、Google に残したままにする
    final end = DateTime.tryParse(entry.value['end'] as String? ?? '');
    if (end != null && end.isBefore(from)) {
      jobs.add(() => pushed.doc(entry.key).delete());
      continue;
    }
    jobs.add(() async {
      await service.deleteEvent(calendarId, entry.value['eventId'] as String);
      await pushed.doc(entry.key).delete();
      deleted++;
    });
  }

  // 1件ずつ順番に送る（一度に送りすぎないように）
  for (final job in jobs) {
    await job();
  }
  return PushResult(added, updated, deleted);
}

/// Google に送る形から、終わりの日を取り出す
DateTime? bodyEnd(Map<String, dynamic> body) {
  final end = body['end'];
  if (end is! Map) return null;
  final v = end['date'] ?? end['dateTime'];
  return v is String ? DateTime.tryParse(v)?.toLocal() : null;
}
