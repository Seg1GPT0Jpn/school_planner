import 'package:material_ui/material_ui.dart';

import '../../widgets/color_palette_picker.dart';
import '../events/calendar_event.dart';
import '../timetable/day_timetable_resolver.dart';
import '../timetable/school_periods.dart';
import '../timetable/timetable_repository.dart';
import '../timetable/week_cycle.dart';

/// 月表示（日曜始まり、左端にⅠ週/Ⅱ週）
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

  static const List<String> _weekdayHeaders = [
    '日',
    '月',
    '火',
    '水',
    '木',
    '金',
    '土',
  ];

  /// 左端（Ⅰ週/Ⅱ週）の列の幅
  static const double _weekLabelWidth = 32;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final resolver = data.resolver;

    // 表示する範囲：月の1日を含む週の日曜日 〜 月末を含む週
    final firstDay = DateTime(month.year, month.month, 1);
    final lastDay = DateTime(month.year, month.month + 1, 0);
    final gridStart = DateTime(
      firstDay.year,
      firstDay.month,
      firstDay.day - (firstDay.weekday % 7), // 日曜日なら0日戻る
    );

    final sundays = <DateTime>[];
    for (
      var d = gridStart;
      !d.isAfter(lastDay);
      d = DateTime(d.year, d.month, d.day + 7)
    ) {
      sundays.add(d);
    }

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
                  for (var i = 0; i < 7; i++)
                    Expanded(
                      child: Center(
                        child: Text(
                          _weekdayHeaders[i],
                          style: Theme.of(context).textTheme.labelSmall
                              ?.copyWith(
                                color: i == 0
                                    ? colorScheme.error
                                    : i == 6
                                    ? Colors.blue.shade700
                                    : null,
                              ),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 4),

              // 週ごとの行（Ⅰ週/Ⅱ週は、その行の月曜日で判定）
              for (final sunday in sundays)
                Builder(
                  builder: (context) {
                    final monday = DateTime(
                      sunday.year,
                      sunday.month,
                      sunday.day + 1,
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
                        for (var i = 0; i < 7; i++)
                          Expanded(
                            child: _buildDayCell(
                              DateTime(
                                sunday.year,
                                sunday.month,
                                sunday.day + i,
                              ),
                              resolver,
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

  Widget _buildDayCell(DateTime date, DayTimetableResolver resolver) {
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
      colorOf: colorOf,
      isInMonth: date.month == month.month,
      isToday:
          date.year == today.year &&
          date.month == today.month &&
          date.day == today.day,
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
    required this.colorOf,
    required this.isInMonth,
    required this.isToday,
    required this.onTap,
  });

  final DateTime date;
  final DayTimetable day;
  final List<CalendarEvent> events;
  final Color Function(CalendarEvent event) colorOf;
  final bool isInMonth;
  final bool isToday;
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

    // 日付の下に並べるもの（祝日名・休業日名・試験の帯・予定の帯）
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
      for (final e in events)
        _Band(
          text: e.title,
          background: colorOf(e),
          foreground: readableTextColor(colorOf(e)),
        ),
    ];
    final hiddenCount = items.length - _maxItems;

    return Opacity(
      opacity: isInMonth ? 1 : 0.35,
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
