import 'package:flutter_test/flutter_test.dart';
import 'package:school_planner/features/calendar/schedule_items.dart';
import 'package:school_planner/features/widget/widget_text.dart';

ScheduleItem _item(
  String title, {
  ScheduleKind kind = ScheduleKind.event,
  int? color,
}) => ScheduleItem(kind: kind, title: title, color: color);

void main() {
  final today = DateTime(2026, 9, 21);

  final days = [
    ScheduleDay(DateTime(2026, 9, 21), [
      _item('秋分の日', kind: ScheduleKind.holiday),
      _item('歯医者', color: 0xFF00BCD4),
    ]),
    ScheduleDay(DateTime(2026, 9, 22), const []),
    ScheduleDay(DateTime(2026, 9, 23), [_item('模試', kind: ScheduleKind.test)]),
  ];

  test('予定がある日だけ、日付の見出しをつけて並べる', () {
    final lines = buildWidgetSchedule(days: days, today: today);
    expect(lines.length, 5);
    expect(lines[0].header, isTrue);
    expect(lines[0].left, '9/21(月)');
    expect(lines[0].today, isTrue);
    expect(lines[1].title, '秋分の日');
    expect(lines[2].title, '歯医者');
    // 9/22 は予定がないので飛ばす
    expect(lines[3].header, isTrue);
    expect(lines[3].left, '9/23(水)');
    expect(lines[3].today, isFalse);
    expect(lines[4].title, '模試');
  });

  test('色は、予定の色 → なければ種類ごとの色', () {
    final lines = buildWidgetSchedule(days: days, today: today);
    expect(lines[1].color, 0xFFD32F2F); // 祝日
    expect(lines[2].color, 0xFF00BCD4); // 予定の色
    expect(lines[4].color, 0xFFE65100); // テスト
  });

  test('多すぎるときは途中で止める', () {
    expect(
      buildWidgetSchedule(days: days, today: today, maxLines: 3).length,
      3,
    );
  });

  test('ウィジェットに渡す形（タブ区切り・改行区切り）', () {
    final lines = buildWidgetSchedule(days: days, today: today);
    expect(lines[0].encode(), 'h\t9/21(月)\t\t0\t1');
    expect(encodeScheduleLines(lines).split('\n').length, 5);
  });

  test('月ビューは6週ぶん・日曜はじまり', () {
    final m = buildWidgetMonth(month: today, today: today, days: days);
    expect(m.title, '2026年9月');
    expect(m.weekdays, ['日', '月', '火', '水', '木', '金', '土']);
    expect(m.cells.length, 42);

    // 2026年9月1日は火曜なので、最初のマスは8/30
    expect(m.cells[0].day, 30);
    expect(m.cells[0].inMonth, isFalse);
    expect(m.cells[2].day, 1);
    expect(m.cells[2].inMonth, isTrue);

    // 8/30 から22日後が9/21
    expect(m.cells[22].today, isTrue);
    expect(m.cells[22].marks, 2);
    expect(m.cells[22].holiday, isTrue);
    expect(m.cells[22].color, 0xFFD32F2F);

    expect(m.cells[23].marks, 0); // 9/22 は予定なし
    expect(m.cells[24].marks, 1); // 9/23
  });

  test('月ビューは月曜はじまりにもできる', () {
    final m = buildWidgetMonth(
      month: today,
      today: today,
      days: days,
      weekStart: DateTime.monday,
    );
    expect(m.weekdays.first, '月');
    expect(m.cells[0].day, 31); // 8/31（月）から
    expect(m.cells[1].day, 1);
  });

  test('点は最大3つ', () {
    final many = [
      ScheduleDay(DateTime(2026, 9, 21), [
        for (var i = 0; i < 5; i++) _item('予定$i'),
      ]),
    ];
    final m = buildWidgetMonth(month: today, today: today, days: many);
    expect(m.cells[22].marks, 3);
  });
}
