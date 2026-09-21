import 'package:flutter_test/flutter_test.dart';
import 'package:school_planner/features/settings/app_settings.dart';

void main() {
  final day = DateTime(2026, 9, 21); // 月曜日

  test('日付の書き方', () {
    expect(formatDateWith(day, DateStyle.ymdSlash), '2026/9/21');
    expect(formatDateWith(day, DateStyle.ymdJa), '2026年9月21日');
    expect(formatDateWith(day, DateStyle.mdJa), '9月21日');
    expect(formatDateWith(day, DateStyle.dmySlash), '21/9/2026');
    expect(formatDateWith(day, DateStyle.mdJa, weekday: true), '9月21日(月)');
  });

  test('24時間表示と午前・午後', () {
    expect(formatMinutesWith(9 * 60 + 5, use24Hour: true), '9:05');
    expect(formatMinutesWith(21 * 60 + 40, use24Hour: true), '21:40');
    expect(formatMinutesWith(9 * 60 + 5, use24Hour: false), '午前9:05');
    expect(formatMinutesWith(21 * 60 + 40, use24Hour: false), '午後9:40');
    expect(formatMinutesWith(0, use24Hour: false), '午前12:00');
    expect(formatMinutesWith(12 * 60, use24Hour: false), '午後12:00');
  });

  test('「◯分前」の言い方', () {
    expect(reminderLabel(0), '予定の時刻');
    expect(reminderLabel(30), '30分前');
    expect(reminderLabel(60), '1時間前');
    expect(reminderLabel(120), '2時間前');
    expect(reminderLabel(1440), '1日前');
    expect(reminderLabel(90), '90分前');
  });

  test('週の始まり', () {
    const sun = AppSettings();
    expect(sun.weekdayLabels, ['日', '月', '火', '水', '木', '金', '土']);
    expect(sun.startOfWeek(day), DateTime(2026, 9, 20));

    final mon = sun.copyWith(weekStart: WeekStart.monday);
    expect(mon.weekdayLabels.first, '月');
    expect(mon.startOfWeek(day), DateTime(2026, 9, 21));

    final sat = sun.copyWith(weekStart: WeekStart.saturday);
    expect(sat.weekdayLabels.first, '土');
    expect(sat.startOfWeek(day), DateTime(2026, 9, 19));
  });

  test('少し早く終わる設定', () {
    const s = AppSettings(defaultEventMinutes: 60);
    expect(s.eventMinutes, 60);
    expect(s.copyWith(speedyEvents: true).eventMinutes, 55);
    expect(
      const AppSettings(
        defaultEventMinutes: 90,
        speedyEvents: true,
      ).eventMinutes,
      80,
    );
  });

  test('保存と読み出し', () {
    final s = const AppSettings().copyWith(
      weekStart: WeekStart.monday,
      use24Hour: false,
      dateStyle: DateStyle.ymdJa,
      defaultEventMinutes: 70,
      showWorldClock: true,
      secondTimeZone: 'Europe/Vienna',
    );
    final back = AppSettings.fromMap(s.toMap());
    expect(back.weekStart, WeekStart.monday);
    expect(back.use24Hour, isFalse);
    expect(back.dateStyle, DateStyle.ymdJa);
    expect(back.defaultEventMinutes, 70);
    expect(back.secondTimeZone, 'Europe/Vienna');
  });

  test('こわれた値や空のときは、はじめの設定にもどす', () {
    const d = AppSettings();
    expect(AppSettings.fromMap(null).toMap(), d.toMap());
    expect(AppSettings.fromMap(const {}).toMap(), d.toMap());

    final broken = AppSettings.fromMap(const {
      'weekStart': 'きんようび',
      'use24Hour': 'はい',
      'defaultEventMinutes': 99999,
      'allDayReminderMinutes': 5000,
      'dateStyle': 42,
    });
    expect(broken.weekStart, d.weekStart);
    expect(broken.use24Hour, d.use24Hour);
    expect(broken.defaultEventMinutes, d.defaultEventMinutes);
    expect(broken.allDayReminderMinutes, d.allDayReminderMinutes);
    expect(broken.dateStyle, d.dateStyle);
  });
}
