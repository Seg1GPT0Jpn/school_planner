import 'package:flutter_test/flutter_test.dart';
import 'package:school_planner/features/events/calendar_event.dart';
import 'package:school_planner/features/google_calendar/google_push.dart';
import 'package:school_planner/features/school_tests/school_test.dart';

void main() {
  final from = DateTime(2026, 9, 1);
  final to = DateTime(2027, 3, 1);

  test('時刻のある予定', () {
    final b = googleEventBody(
      title: '塾 数学',
      start: DateTime(2026, 9, 21, 19, 40),
      end: DateTime(2026, 9, 21, 21, 40),
      location: '駅前',
    );
    expect(b['summary'], '塾 数学');
    expect(
      (b['start'] as Map)['dateTime'],
      DateTime(2026, 9, 21, 19, 40).toUtc().toIso8601String(),
    );
    expect((b['start'] as Map)['timeZone'], 'Asia/Tokyo');
    expect(b['location'], '駅前');
    expect(bodyEnd(b), DateTime(2026, 9, 21, 21, 40));
  });

  test('終日の予定は、終わりが翌日になる', () {
    final b = googleEventBody(
      title: '文化祭',
      start: DateTime(2026, 9, 26),
      end: DateTime(2026, 9, 27),
      allDay: true,
    );
    expect(b['start'], {'date': '2026-09-26'});
    expect(b['end'], {'date': '2026-09-28'});
  });

  test('書き込むものを集める（Google の予定・期間外は入れない）', () {
    final items = buildPushItems(
      from: from,
      to: to,
      ownEvents: [
        CalendarEvent(
          id: 'a',
          title: '文化祭',
          start: DateTime(2026, 9, 26),
          end: DateTime(2026, 9, 26),
          isAllDay: true,
        ),
        CalendarEvent(
          id: 'google:x',
          title: 'G',
          start: DateTime(2026, 9, 26),
          end: DateTime(2026, 9, 26),
        ),
        CalendarEvent(
          id: 'old',
          title: '昔',
          start: DateTime(2025, 1, 1),
          end: DateTime(2025, 1, 1),
        ),
      ],
      recurringEvents: [
        CalendarEvent(
          id: 'recurring:juku:2026-09-21',
          title: '塾 数学',
          start: DateTime(2026, 9, 21, 19, 40),
          end: DateTime(2026, 9, 21, 21, 40),
        ),
      ],
      tests: [
        SchoolTest(
          id: 't1',
          kind: SchoolTestKind.quiz,
          title: '漢字テスト',
          subject: '現代の国語',
          scope: 'p.20〜35',
          date: DateTime(2026, 10, 2),
        ),
      ],
    );
    expect(items.keys.toSet(), {'e_a', 'r_recurring_juku_2026-09-21', 't_t1'});
    expect(items['t_t1']!['summary'], '【小テスト】現代の国語 漢字テスト p.20〜35');
    expect(items['t_t1']!['start'], {'date': '2026-10-02'});
  });
}
