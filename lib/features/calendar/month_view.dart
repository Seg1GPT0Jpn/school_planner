import 'package:material_ui/material_ui.dart';

import '../../widgets/color_palette_picker.dart';
import '../events/calendar_event.dart';
import '../school_tests/school_test.dart';
import '../settings/app_settings.dart';
import '../settings/settings_scope.dart';
import '../timetable/day_timetable_resolver.dart';
import '../timetable/school_periods.dart';
import '../timetable/timetable_repository.dart';
import '../timetable/week_cycle.dart';

/// 月表示（週の始まりは設定にしたがう。左端にⅠ週/Ⅱ週）
class MonthView extends StatelessWidget {
  const MonthView({
    super.key,
    required this.data,
    required this.month,
    required this.today,
    required this.events,
    required this.colorOf,
    required this.onDayTap,
  });

  final TimetableData data;

  /// 表示する月（日付は何日でもよい）
  final DateTime month;

  final DateTime today;

  final List<CalendarEvent> events;
  final Color Function(CalendarEvent event) colorOf;

  /// 日付がタップされたとき
  final ValueChanged<DateTime> onDayTap;

  /// 左端（Ⅰ週/Ⅱ週）の列の幅
  static const double _weekLabelWidth = 32;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final settings = SettingsScope.of(context);
    final resolver = data.resolver;

    // 週の始まりから数えて i 番目の曜日（月=1 … 日=7）
    int weekdayAt(int i) => ((settings.weekStart.weekday - 1 + i) % 7) + 1;

    // 出す列（週末を隠す設定のときは土日を飛ばす）
    final columns = [
      for (var i = 0; i < 7; i++)
        if (settings.showWeekend ||
            (weekdayAt(i) != DateTime.saturday &&
                weekdayAt(i) != DateTime.sunday))
          i,
    ];

    // 表示する範囲：月の1日を含む週のはじめ 〜 月末を含む週
    final firstDay = DateTime(month.year, month.month, 1);
    final lastDay = DateTime(month.year, month.month + 1, 0);
    final gridStart = settings.startOfWeek(firstDay);

    final weekStarts = <DateTime>[];
    for (
      var d = gridStart;
      !d.isAfter(lastDay);
      d = DateTime(d.year, d.month, d.day + 7)
    ) {
      weekStarts.add(d);
    }

    Color? headerColor(int weekday) => switch (weekday) {
      DateTime.sunday => colorScheme.error,
      DateTime.saturday => Colors.blue.shade700,
      _ => null,
    };

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(8, 0, 8, 88),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 900),
          child: Column(
            children: [
              // 曜日の見出し
              Row(
                children: [
                  const SizedBox(width: _weekLabelWidth),
                  for (final i in columns)
                    Expanded(
                      child: Center(
                        child: Text(
                          settings.weekdayLabels[i],
                          style: Theme.of(context).textTheme.labelSmall
                              ?.copyWith(color: headerColor(weekdayAt(i))),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 4),

              // 週ごとの行（Ⅰ週/Ⅱ週は、その週の月曜日で判定）
              for (final weekStart in weekStarts)
                Builder(
                  builder: (context) {
                    final monday = DateTime(
                      weekStart.year,
                      weekStart.month,
                      weekStart.day + (1 - weekStart.weekday + 7) % 7,
                    );
                    return Row(
                      children: [
                        _WeekLabel(
                          weekType: resolver.weekCalculator.weekTypeFor(monday),
                          isOverridden: resolver.weekCalculator.isOverridden(
                            monday,
                          ),
                          width: _weekLabelWidth,
                        ),
                        for (final i in columns)
                          Expanded(
                            child: _buildDayCell(
                              DateTime(
                                weekStart.year,
                                weekStart.month,
                                weekStart.day + i,
                              ),
                              resolver,
                              settings,
                            ),
                          ),
                      ],
                    );
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDayCell(
    DateTime date,
    DayTimetableResolver resolver,
    AppSettings settings,
  ) {
    // その日の予定（終日を先に、あとは開始時刻の順）
    final dayEvents =
        [
          for (final e in events)
            if (e.occursOn(date)) e,
        ]..sort((a, b) {
          if (a.isAllDay != b.isAllDay) return a.isAllDay ? -1 : 1;
          return a.start.compareTo(b.start);
        });

    return _DayCell(
      date: date,
      day: resolver.resolve(date),
      events: dayEvents,
      // 時限なしの小テスト・学校イベント（時限ありは授業の印で表示される）
      allDayTests: [
        for (final t in data.testsOn(date))
          if (t.period == null) t,
      ],
      colorOf: colorOf,
      isInMonth: date.month == month.month,
      isToday:
          date.year == today.year &&
          date.month == today.month &&
          date.day == today.day,
      isPast: settings.dimPastEvents && date.isBefore(today),
      onTap: () => onDayTap(date),
    );
  }
}

/// 左端の「Ⅰ」「Ⅱ」の表示
class _WeekLabel extends StatelessWidget {
  const _WeekLabel({
    required this.weekType,
    required this.isOverridden,
    required this.width,
  });

  final WeekType? weekType;
  final bool isOverridden;
  final double width;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final text = switch (weekType) {
      WeekType.one => 'Ⅰ',
      WeekType.two => 'Ⅱ',
      null => '',
    };

    return SizedBox(
      width: width,
      child: Center(
        child: Text(
          isOverridden ? '$text*' : text,
          style: Theme.of(context).textTheme.labelMedium?.copyWith(
            color: colorScheme.secondary,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
}

/// 1日分のマス
class _DayCell extends StatelessWidget {
  const _DayCell({
    required this.date,
    required this.day,
    required this.events,
    required this.allDayTests,
    required this.colorOf,
    required this.isInMonth,
    required this.isToday,
    required this.isPast,
    required this.onTap,
  });

  final DateTime date;
  final DayTimetable day;
  final List<CalendarEvent> events;
  final List<SchoolTest> allDayTests;
  final Color Function(CalendarEvent event) colorOf;
  final bool isInMonth;
  final bool isToday;

  /// 過ぎた日（設定で「うすくする」のときだけ true）
  final bool isPast;

  final VoidCallback onTap;

  /// 1マスに表示する帯の最大数
  static const int _maxItems = 2;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    final isHoliday = day.status == DayStatus.holiday;
    final isClosed = day.status == DayStatus.closed;
    final isSchool = day.status == DayStatus.school;
    final isExam = isSchool && day.schedule == DaySchedule.exam;

    // 短縮日課・時間割変更（試験以外）は小さな●だけ
    final hasMinorChange =
        isSchool &&
        !isExam &&
        (day.schedule == DaySchedule.shortened || day.hasChanges);

    // 日付の文字色
    Color? numberColor;
    if (isHoliday || date.weekday == DateTime.sunday) {
      numberColor = colorScheme.error;
    } else if (date.weekday == DateTime.saturday) {
      numberColor = Colors.blue.shade700;
    }

    final smallStyle = textTheme.labelSmall?.copyWith(fontSize: 10);

    // 日付の下に並べるもの（祝日名・休業日名・試験・小テスト・行事・予定）
    final items = <Widget>[
      if (isHoliday)
        Text(
          day.holidayName ?? '',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: smallStyle?.copyWith(color: colorScheme.error),
        ),
      if (isClosed)
        Text(
          day.closureTitle ?? '',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: smallStyle?.copyWith(color: colorScheme.onSurfaceVariant),
        ),
      if (isExam)
        _Band(
          text: day.note ?? '試験',
          background: colorScheme.primaryContainer,
          foreground: colorScheme.onPrimaryContainer,
        ),
      // 授業で行う小テスト（LEAP・時限を指定した小テスト）
      for (final lesson in day.lessons)
        if (lesson.testLabel != null)
          _Band(
            text: '${lesson.subject ?? ''} ${lesson.testLabel}',
            background: colorScheme.errorContainer,
            foreground: colorScheme.onErrorContainer,
          ),
      // 時限なしの小テスト・学校イベント
      for (final t in allDayTests)
        _Band(
          text: t.displayTitle,
          background: t.kind.isTest
              ? colorScheme.errorContainer
              : colorScheme.secondaryContainer,
          foreground: t.kind.isTest
              ? colorScheme.onErrorContainer
              : colorScheme.onSecondaryContainer,
        ),
      for (final e in events)
        _Band(
          text: e.title,
          background: colorOf(e),
          foreground: readableTextColor(colorOf(e)),
        ),
    ];
    final hiddenCount = items.length - _maxItems;

    return Opacity(
      opacity: isInMonth ? (isPast ? 0.5 : 1) : 0.35,
      child: InkWell(
        onTap: onTap,
        child: Container(
          height: 76,
          padding: const EdgeInsets.all(3),
          decoration: BoxDecoration(
            // 学校休業日はマス全体を灰色に
            color: isClosed ? colorScheme.surfaceContainerHighest : null,
            border: Border.all(color: colorScheme.outlineVariant, width: 0.5),
          ),
          // 中身があふれても、エラーにならないようにする
          child: SingleChildScrollView(
            physics: const NeverScrollableScrollPhysics(),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    // 日付（今日は丸で囲む）
                    Container(
                      width: 22,
                      height: 22,
                      alignment: Alignment.center,
                      decoration: isToday
                          ? BoxDecoration(
                              color: colorScheme.primary,
                              shape: BoxShape.circle,
                            )
                          : null,
                      child: Text(
                        '${date.day}',
                        style: textTheme.labelMedium?.copyWith(
                          color: isToday ? colorScheme.onPrimary : numberColor,
                        ),
                      ),
                    ),
                    if (hasMinorChange)
                      Container(
                        margin: const EdgeInsets.only(left: 2),
                        width: 6,
                        height: 6,
                        decoration: BoxDecoration(
                          color: colorScheme.tertiary,
                          shape: BoxShape.circle,
                        ),
                      ),
                  ],
                ),
                ...items.take(_maxItems),
                if (hiddenCount > 0)
                  Text(
                    '+$hiddenCount',
                    style: smallStyle?.copyWith(color: colorScheme.outline),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// 月表示の色付きの帯
class _Band extends StatelessWidget {
  const _Band({
    required this.text,
    required this.background,
    required this.foreground,
  });

  final String text;
  final Color background;
  final Color foreground;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: 2),
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 1),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(3),
      ),
      child: Text(
        text,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: Theme.of(context).textTheme.labelSmall
            ?.copyWith(fontSize: 10, color: foreground),
      ),
    );
  }
}
