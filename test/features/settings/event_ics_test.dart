import 'package:flutter_test/flutter_test.dart';
import 'package:school_planner/features/events/calendar_event.dart';
import 'package:school_planner/features/settings/event_ics.dart';
import 'package:school_planner/features/settings/ics.dart';

void main() {
  final dentist = CalendarEvent(
    id: 'abc',
    title: '歯医者',
    start: DateTime(2026, 9, 21, 9),
    end: DateTime(2026, 9, 21, 10),
    location: '田中歯科',
    memo: '保険証',
  );

  test('つづりの予定 → .ics → つづりの予定', () {
    final back = parseIcs(buildIcs([icsFromEvent(dentist)])).single;
    final e = eventFromIcs(back);
    expect(e.id, isNull); // 新しい予定として入る
    expect(e.title, '歯医者');
    expect(e.start, dentist.start);
    expect(e.end, dentist.end);
    expect(e.location, '田中歯科');
    expect(e.memo, '保険証');
  });

  test('終日の予定もそのまま', () {
    final fes = CalendarEvent(
      title: '文化祭',
      start: DateTime(2026, 10, 3),
      end: DateTime(2026, 10, 4),
      isAllDay: true,
    );
    final e = eventFromIcs(parseIcs(buildIcs([icsFromEvent(fes)])).single);
    expect(e.isAllDay, isTrue);
    expect(e.start, DateTime(2026, 10, 3));
    expect(e.end, DateTime(2026, 10, 4));
  });

  test('すでにある予定と、ファイルの中の重なりは入れない', () {
    final incoming = [
      icsFromEvent(dentist), // もうある
      IcsEvent(
        title: '模試',
        start: DateTime(2026, 11, 1, 9),
        end: DateTime(2026, 11, 1, 15),
      ),
      IcsEvent(
        title: '模試',
        start: DateTime(2026, 11, 1, 9),
        end: DateTime(2026, 11, 1, 15),
      ), // ファイルの中で2回
    ];
    final added = newEventsOnly(incoming, [dentist]);
    expect(added.map((e) => e.title).toList(), ['模試']);
  });
}
