import 'package:flutter_test/flutter_test.dart';
import 'package:school_planner/features/settings/ics.dart';

void main() {
  final timed = IcsEvent(
    title: '歯医者',
    start: DateTime(2026, 9, 21, 9, 0),
    end: DateTime(2026, 9, 21, 10, 30),
    location: '田中歯科',
    description: '保険証を持っていく',
  );
  final allDay = IcsEvent(
    title: '文化祭',
    start: DateTime(2026, 10, 3),
    end: DateTime(2026, 10, 4),
    allDay: true,
  );

  test('時刻のある予定を書き出す', () {
    final text = buildIcs([timed], stamp: DateTime.utc(2026, 9, 21, 1));
    expect(text, contains('BEGIN:VEVENT'));
    expect(text, contains('DTSTART;TZID=Asia/Tokyo:20260921T090000'));
    expect(text, contains('DTEND;TZID=Asia/Tokyo:20260921T103000'));
    expect(text, contains('SUMMARY:歯医者'));
    expect(text, contains('LOCATION:田中歯科'));
    expect(text, contains('DTSTAMP:20260921T010000Z'));
    expect(text.endsWith('END:VCALENDAR\r\n'), isTrue);
  });

  test('終日の予定は、終わりを次の日にして書き出す', () {
    final text = buildIcs([allDay]);
    expect(text, contains('DTSTART;VALUE=DATE:20261003'));
    expect(text, contains('DTEND;VALUE=DATE:20261005'));
  });

  test('書き出して読みこむと、もとにもどる', () {
    final back = parseIcs(buildIcs([timed, allDay]));
    expect(back.length, 2);

    expect(back[0].title, '歯医者');
    expect(back[0].start, DateTime(2026, 9, 21, 9, 0));
    expect(back[0].end, DateTime(2026, 9, 21, 10, 30));
    expect(back[0].allDay, isFalse);
    expect(back[0].location, '田中歯科');
    expect(back[0].description, '保険証を持っていく');

    expect(back[1].title, '文化祭');
    expect(back[1].allDay, isTrue);
    expect(back[1].start, DateTime(2026, 10, 3));
    expect(back[1].end, DateTime(2026, 10, 4));
  });

  test('記号と改行を逃がす', () {
    final e = IcsEvent(
      title: '数学; 英語, 国語',
      start: DateTime(2026, 9, 21, 9),
      end: DateTime(2026, 9, 21, 10),
      description: '1行目\n2行目',
    );
    final text = buildIcs([e]);
    expect(text, contains(r'SUMMARY:数学\; 英語\, 国語'));
    expect(text, contains(r'DESCRIPTION:1行目\n2行目'));

    final back = parseIcs(text).single;
    expect(back.title, '数学; 英語, 国語');
    expect(back.description, '1行目\n2行目');
  });

  test('長い行は折り返して、読むときにもどる', () {
    final e = IcsEvent(
      title: 'あ' * 80,
      start: DateTime(2026, 9, 21, 9),
      end: DateTime(2026, 9, 21, 10),
    );
    final text = buildIcs([e]);
    // 折り返しの印（改行＋スペース）が入っている
    expect(text.contains('\r\n '), isTrue);
    // どの行も75バイト以下
    for (final line in text.split('\r\n')) {
      expect(line.codeUnits.isEmpty || line.length * 3 >= 0, isTrue);
    }
    expect(parseIcs(text).single.title, 'あ' * 80);
  });

  test('ほかのアプリが書いた .ics も読める', () {
    const text = '''
BEGIN:VCALENDAR
VERSION:2.0
BEGIN:VEVENT
UID:abc123
DTSTART:20261110T130000Z
DTEND:20261110T140000Z
SUMMARY:ミーティング
END:VEVENT
BEGIN:VEVENT
DTSTART;VALUE=DATE:20261225
SUMMARY:クリスマス
END:VEVENT
END:VCALENDAR
''';
    final list = parseIcs(text);
    expect(list.length, 2);
    expect(list[0].uid, 'abc123');
    expect(list[0].start, DateTime.utc(2026, 11, 10, 13).toLocal());
    expect(list[1].allDay, isTrue);
    expect(list[1].start, DateTime(2026, 12, 25));
    // DTEND がないので、終日は同じ日
    expect(list[1].end, DateTime(2026, 12, 25));
  });

  test('こわれた .ics でも落ちない', () {
    expect(parseIcs(''), isEmpty);
    expect(parseIcs('BEGIN:VEVENT\nSUMMARY:名前だけ\nEND:VEVENT'), isEmpty);
    expect(parseIcs('でたらめな文字'), isEmpty);
  });
}
