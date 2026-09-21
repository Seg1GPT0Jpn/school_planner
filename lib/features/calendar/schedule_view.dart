import 'package:material_ui/material_ui.dart';

import '../events/calendar_event.dart';
import '../settings/settings_scope.dart';
import '../timetable/timetable_repository.dart';
import 'schedule_items.dart';

/// スケジュール表示で先まで見る日数
const int scheduleDays = 120;

const _wd = ['月', '火', '水', '木', '金', '土', '日'];

/// Google カレンダーの「スケジュール」のような、日付順の一覧
class ScheduleView extends StatelessWidget {
  const ScheduleView({
    super.key,
    required this.data,
    required this.from,
    required this.today,
    required this.events,
    required this.colorOf,
    required this.showLessons,
    required this.onToggleLessons,
    required this.onEventTap,
    required this.onDayTap,
    this.days = scheduleDays,
  });

  final TimetableData data;
  final DateTime from;
  final DateTime today;
  final List<CalendarEvent> events;
  final Color Function(CalendarEvent) colorOf;
  final bool showLessons;
  final ValueChanged<bool> onToggleLessons;
  final ValueChanged<CalendarEvent> onEventTap;
  final ValueChanged<DateTime> onDayTap;

  /// 何日ぶん先まで出すか
  final int days;

  @override
  Widget build(BuildContext context) {
    final settings = SettingsScope.of(context);
    final resolver = data.resolver;
    final list = <ScheduleDay>[];
    for (var i = 0; i < days; i++) {
      final d = DateTime(from.year, from.month, from.day + i);
      final day = buildScheduleDay(
        day: resolver.resolve(d),
        events: events,
        tests: data.testsOn(d),
        showLessons: showLessons,
        use24Hour: settings.use24Hour,
        colorOf: (e) => colorOf(e).toARGB32(),
      );
      // 予定のない日は出さない（今日だけは「予定なし」を出す）
      if (day.items.isNotEmpty || d == today) list.add(day);
    }

    // 月の見出しを入れながら並べる
    final rows = <Widget>[];
    int? month;
    for (final day in list) {
      if (day.date.month != month) {
        month = day.date.month;
        rows.add(_MonthHeader(date: day.date));
      }
      rows.add(
        _DayBlock(
          day: day,
          isToday: day.date == today,
          isPast: settings.dimPastEvents && day.date.isBefore(today),
          onEventTap: onEventTap,
          onDayTap: onDayTap,
        ),
      );
    }

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              const Spacer(),
              FilterChip(
                label: const Text('授業も表示'),
                selected: showLessons,
                onSelected: onToggleLessons,
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.only(bottom: 96),
            children: rows,
          ),
        ),
      ],
    );
  }
}

class _MonthHeader extends StatelessWidget {
  const _MonthHeader({required this.date});
  final DateTime date;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 6),
      child: Text(
        '${date.year}年${date.month}月',
        style: Theme.of(context).textTheme.titleMedium,
      ),
    );
  }
}

class _DayBlock extends StatelessWidget {
  const _DayBlock({
    required this.day,
    required this.isToday,
    required this.isPast,
    required this.onEventTap,
    required this.onDayTap,
  });

  final ScheduleDay day;
  final bool isToday;

  /// 過ぎた日（設定で「うすくする」のときだけ true）
  final bool isPast;
  final ValueChanged<CalendarEvent> onEventTap;
  final ValueChanged<DateTime> onDayTap;

  Color _dotColor(BuildContext context, ScheduleItem item) {
    final cs = Theme.of(context).colorScheme;
    return switch (item.kind) {
      ScheduleKind.holiday => const Color(0xFF0B8043),
      ScheduleKind.test => const Color(0xFFE65100),
      ScheduleKind.lesson => cs.outline,
      ScheduleKind.event =>
        item.color == null ? cs.primary : Color(item.color!),
    };
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final d = day.date;
    final weekend = d.weekday >= DateTime.saturday;

    return Opacity(
      opacity: isPast ? 0.5 : 1,
      child: InkWell(
        onTap: () => onDayTap(d),
        child: Container(
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(
                color: cs.outlineVariant.withValues(alpha: 0.5),
              ),
            ),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 日付
              SizedBox(
                width: 64,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Container(
                      width: 32,
                      height: 32,
                      alignment: Alignment.center,
                      decoration: isToday
                          ? BoxDecoration(
                              color: cs.primary,
                              shape: BoxShape.circle,
                            )
                          : null,
                      child: Text(
                        '${d.day}',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w500,
                          color: isToday
                              ? cs.onPrimary
                              : (weekend ? cs.error : cs.onSurface),
                        ),
                      ),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      _wd[d.weekday - 1],
                      style: TextStyle(fontSize: 12, color: cs.outline),
                    ),
                  ],
                ),
              ),
              // その日の予定
              Expanded(
                child: day.items.isEmpty
                    ? Padding(
                        padding: const EdgeInsets.symmetric(vertical: 7),
                        child: Text(
                          '予定なし',
                          style: TextStyle(color: cs.outline),
                        ),
                      )
                    : Column(
                        children: [
                          for (final item in day.items)
                            InkWell(
                              onTap: item.event == null
                                  ? () => onDayTap(d)
                                  : () => onEventTap(item.event!),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 7,
                                ),
                                child: Row(
                                  children: [
                                    Container(
                                      width: 10,
                                      height: 10,
                                      decoration: BoxDecoration(
                                        color: _dotColor(context, item),
                                        shape: BoxShape.circle,
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    SizedBox(
                                      width: 92,
                                      child: Text(
                                        item.timeText,
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: cs.outline,
                                        ),
                                      ),
                                    ),
                                    Expanded(
                                      child: Text(
                                        item.title,
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          color:
                                              item.kind == ScheduleKind.lesson
                                              ? cs.outline
                                              : cs.onSurface,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                        ],
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
