import 'dart:async';
import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';

import '../../core/date_format.dart';
import '../../widgets/color_palette_picker.dart';
import '../events/calendar_event.dart';
import '../timetable/day_timetable_resolver.dart';
import '../timetable/school_periods.dart';
import '../timetable/subject_colors.dart';
import '../timetable/timetable_repository.dart';
import '../timetable/week_cycle.dart';
import 'overlap_layout.dart';

/// 1時間あたりの高さ（ピクセル）
const double _hourHeight = 56;

/// 左端の時刻の列の幅
const double _gutterWidth = 44;

/// 空き時間をタップしたとき、何分単位で開始時刻を決めるか
const int _tapSnapMinutes = 30;

/// 分数を、上からの位置（ピクセル）に変換する
double _yOfMinutes(num minutes) => minutes / 60 * _hourHeight;

bool _isSameDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;

String _hm(DateTime d) => '${d.hour}:${d.minute.toString().padLeft(2, '0')}';

/// Google カレンダー風の時間軸表示（週表示・日表示の共通部品）
class TimeGridView extends StatefulWidget {
  const TimeGridView({
    super.key,
    required this.data,
    required this.days,
    required this.today,
    required this.events,
    required this.colorOf,
    required this.onCreateAt,
    required this.onEventTap,
  });

  final TimetableData data;

  /// 表示する日（週表示なら7日、日表示なら1日）
  final List<DateTime> days;

  final DateTime today;

  /// 予定（表示する日に関係ないものが混ざっていてもよい）
  final List<CalendarEvent> events;

  /// 予定の色（カテゴリの色）
  final Color Function(CalendarEvent event) colorOf;

  /// 空き時間がタップされたとき（その時刻から始まる予定を作る）
  final ValueChanged<DateTime> onCreateAt;

  /// 予定がタップされたとき
  final ValueChanged<CalendarEvent> onEventTap;

  @override
  State<TimeGridView> createState() => _TimeGridViewState();
}

class _TimeGridViewState extends State<TimeGridView> {
  /// 最初は朝 7:30 あたりが見える位置にスクロールしておく
  final ScrollController _scrollController = ScrollController(
    initialScrollOffset: _hourHeight * 7.5,
  );

  /// 現在時刻の線を動かすためのタイマー（1分ごと）
  Timer? _timer;
  DateTime _now = DateTime.now();

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(minutes: 1), (_) {
      if (mounted) setState(() => _now = DateTime.now());
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final resolver = widget.data.resolver;
    final timetables = [for (final d in widget.days) resolver.resolve(d)];

    // 科目名 → 教科名（色分けに使う）
    final categoryOf = {
      for (final s in widget.data.subjects) s.name: s.category,
    };

    // 左上に出す Ⅰ週/Ⅱ週（表示している日の中の月曜日で判定）
    WeekType? weekType;
    for (final d in widget.days) {
      if (d.weekday == DateTime.monday) {
        weekType = resolver.weekCalculator.weekTypeFor(d);
      }
    }
    if (widget.days.length == 1) weekType = timetables.first.weekType;

    return Column(
      children: [
        _Header(
          days: widget.days,
          timetables: timetables,
          today: widget.today,
          weekType: weekType,
          events: widget.events,
          colorOf: widget.colorOf,
          onEventTap: widget.onEventTap,
        ),
        const Divider(height: 1),
        Expanded(
          child: SingleChildScrollView(
            controller: _scrollController,
            child: SizedBox(
              height: _hourHeight * 24,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const _HourGutter(),
                  for (var i = 0; i < widget.days.length; i++)
                    Expanded(
                      child: _DayColumn(
                        date: widget.days[i],
                        day: timetables[i],
                        isToday: _isSameDay(widget.days[i], widget.today),
                        now: _now,
                        categoryOf: categoryOf,
                        events: [
                          for (final e in widget.events)
                            if (!e.isAllDay && e.occursOn(widget.days[i])) e,
                        ],
                        colorOf: widget.colorOf,
                        onCreateAt: widget.onCreateAt,
                        onEventTap: widget.onEventTap,
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// ------------------------------------------------------------
// 上部：日付と終日欄
// ------------------------------------------------------------

class _Header extends StatelessWidget {
  const _Header({
    required this.days,
    required this.timetables,
    required this.today,
    required this.weekType,
    required this.events,
    required this.colorOf,
    required this.onEventTap,
  });

  final List<DateTime> days;
  final List<DayTimetable> timetables;
  final DateTime today;
  final WeekType? weekType;
  final List<CalendarEvent> events;
  final Color Function(CalendarEvent event) colorOf;
  final ValueChanged<CalendarEvent> onEventTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: _gutterWidth,
            child: Padding(
              padding: const EdgeInsets.only(top: 10),
              child: Text(
                weekType?.label ?? '',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: colorScheme.secondary,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          for (var i = 0; i < days.length; i++)
            Expanded(
              child: _DayHeader(
                date: days[i],
                day: timetables[i],
                isToday: _isSameDay(days[i], today),
                allDayEvents: [
                  for (final e in events)
                    if (e.isAllDay && e.occursOn(days[i])) e,
                ],
                colorOf: colorOf,
                onEventTap: onEventTap,
              ),
            ),
        ],
      ),
    );
  }
}

class _DayHeader extends StatelessWidget {
  const _DayHeader({
    required this.date,
    required this.day,
    required this.isToday,
    required this.allDayEvents,
    required this.colorOf,
    required this.onEventTap,
  });

  final DateTime date;
  final DayTimetable day;
  final bool isToday;
  final List<CalendarEvent> allDayEvents;
  final Color Function(CalendarEvent event) colorOf;
  final ValueChanged<CalendarEvent> onEventTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    Color? weekdayColor;
    if (date.weekday == DateTime.sunday || day.status == DayStatus.holiday) {
      weekdayColor = colorScheme.error;
    } else if (date.weekday == DateTime.saturday) {
      weekdayColor = Colors.blue.shade700;
    }

    return Container(
      decoration: BoxDecoration(
        border: Border(
          left: BorderSide(color: colorScheme.outlineVariant, width: 0.5),
        ),
      ),
      padding: const EdgeInsets.fromLTRB(2, 6, 2, 6),
      child: Column(
        children: [
          Text(
            weekdayLabel(date.weekday),
            style: textTheme.labelSmall?.copyWith(color: weekdayColor),
          ),
          const SizedBox(height: 2),
          Container(
            width: 30,
            height: 30,
            alignment: Alignment.center,
            decoration: isToday
                ? BoxDecoration(
                    color: colorScheme.primary,
                    shape: BoxShape.circle,
                  )
                : null,
            child: Text(
              '${date.day}',
              style: textTheme.titleMedium?.copyWith(
                color: isToday ? colorScheme.onPrimary : weekdayColor,
              ),
            ),
          ),
          const SizedBox(height: 4),
          for (final chip in _allDayChips(context, day))
            Padding(padding: const EdgeInsets.only(bottom: 2), child: chip),
          // 終日の予定
          for (final event in allDayEvents)
            Padding(
              padding: const EdgeInsets.only(bottom: 2),
              child: _AllDayChip(
                text: event.title,
                background: colorOf(event),
                foreground: readableTextColor(colorOf(event)),
                onTap: () => onEventTap(event),
              ),
            ),
        ],
      ),
    );
  }
}

/// 終日欄に出す帯（祝日・休業日・試験・短縮・週の変更）
List<Widget> _allDayChips(BuildContext context, DayTimetable day) {
  final colorScheme = Theme.of(context).colorScheme;
  final isSchool = day.status == DayStatus.school;

  return [
    if (day.status == DayStatus.holiday)
      _AllDayChip(
        text: day.holidayName ?? '祝日',
        background: colorScheme.errorContainer,
        foreground: colorScheme.onErrorContainer,
      ),
    if (day.status == DayStatus.closed)
      _AllDayChip(
        text: day.closureTitle ?? '休業日',
        background: colorScheme.surfaceContainerHighest,
        foreground: colorScheme.onSurfaceVariant,
      ),
    if (isSchool && day.schedule == DaySchedule.exam)
      _AllDayChip(
        text: day.note ?? '試験',
        background: colorScheme.primaryContainer,
        foreground: colorScheme.onPrimaryContainer,
      ),
    if (isSchool && day.schedule == DaySchedule.shortened)
      _AllDayChip(
        text: '短縮日課',
        background: colorScheme.tertiaryContainer,
        foreground: colorScheme.onTertiaryContainer,
      ),
    if (isSchool && day.isDayWeekTypeOverridden && day.weekType != null)
      _AllDayChip(
        text: '${day.weekType!.label}の時間割',
        background: colorScheme.secondaryContainer,
        foreground: colorScheme.onSecondaryContainer,
      ),
  ];
}

class _AllDayChip extends StatelessWidget {
  const _AllDayChip({
    required this.text,
    required this.background,
    required this.foreground,
    this.onTap,
  });

  final String text;
  final Color background;
  final Color foreground;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: background,
      borderRadius: BorderRadius.circular(4),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(4),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
          child: Text(
            text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.labelSmall
                ?.copyWith(fontSize: 10, color: foreground),
          ),
        ),
      ),
    );
  }
}

// ------------------------------------------------------------
// 左端：時刻の目盛り
// ------------------------------------------------------------

class _HourGutter extends StatelessWidget {
  const _HourGutter();

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(context).textTheme.labelSmall
        ?.copyWith(fontSize: 10, color: Theme.of(context).colorScheme.outline);

    return SizedBox(
      width: _gutterWidth,
      child: Stack(
        children: [
          for (var h = 1; h < 24; h++)
            Positioned(
              top: h * _hourHeight - 7,
              right: 6,
              child: Text('$h:00', style: style),
            ),
        ],
      ),
    );
  }
}

// ------------------------------------------------------------
// 1日分の列
// ------------------------------------------------------------

/// 列の中に置くもの（授業 または 予定）
class _GridItem {
  _GridItem.lesson(this.lesson, this.start, this.end) : event = null;
  _GridItem.event(this.event, this.start, this.end) : lesson = null;

  final ResolvedLesson? lesson;
  final CalendarEvent? event;

  /// その日の 0:00 からの分数
  final int start;
  final int end;
}

class _DayColumn extends StatelessWidget {
  const _DayColumn({
    required this.date,
    required this.day,
    required this.isToday,
    required this.now,
    required this.categoryOf,
    required this.events,
    required this.colorOf,
    required this.onCreateAt,
    required this.onEventTap,
  });

  final DateTime date;
  final DayTimetable day;
  final bool isToday;
  final DateTime now;
  final Map<String, String> categoryOf;

  /// この日に表示する、時刻のある予定
  final List<CalendarEvent> events;

  final Color Function(CalendarEvent event) colorOf;
  final ValueChanged<DateTime> onCreateAt;
  final ValueChanged<CalendarEvent> onEventTap;

  List<_GridItem> _buildItems() {
    final dayStart = DateTime(date.year, date.month, date.day);
    final dayEnd = DateTime(date.year, date.month, date.day + 1);

    return [
      // 授業
      if (day.status == DayStatus.school)
        for (final lesson in day.lessons)
          _GridItem.lesson(
            lesson,
            lesson.start.totalMinutes,
            lesson.end.totalMinutes,
          ),

      // 予定（日付をまたぐ予定は、その日の分だけ切り出す）
      for (final e in events)
        () {
          final start = e.start.isBefore(dayStart) ? dayStart : e.start;
          final end = e.end.isAfter(dayEnd) ? dayEnd : e.end;
          final startMin = start.difference(dayStart).inMinutes;
          final endMin = end.difference(dayStart).inMinutes;
          // 短すぎる予定も、最低15分ぶんの高さで表示する
          return _GridItem.event(e, startMin, math.max(endMin, startMin + 15));
        }(),
    ];
  }

  /// 空き時間のタップ → 30分単位にそろえた時刻で予定を作る
  void _handleTap(TapUpDetails details) {
    final minutes = (details.localPosition.dy / _hourHeight * 60).floor();
    final snapped = (minutes ~/ _tapSnapMinutes) * _tapSnapMinutes;
    onCreateAt(
      DateTime(date.year, date.month, date.day, snapped ~/ 60, snapped % 60),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isSchool = day.status == DayStatus.school;

    const lunchAfter = SchoolPeriods.lunchAfterPeriod;
    final showLunch =
        isSchool &&
        day.schedule.hasLunch &&
        day.lessons.any((l) => l.period <= lunchAfter) &&
        day.lessons.any((l) => l.period > lunchAfter);

    final items = _buildItems();
    final slots = layoutOverlaps([
      for (final item in items) TimeRange(item.start, item.end),
    ]);
    final nowMinutes = now.hour * 60 + now.minute;

    return Container(
      decoration: BoxDecoration(
        color: isToday ? colorScheme.primary.withValues(alpha: 0.04) : null,
        border: Border(
          left: BorderSide(color: colorScheme.outlineVariant, width: 0.5),
        ),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final width = constraints.maxWidth;

          return Stack(
            children: [
              // 一番下：空き時間のタップを受け取る
              Positioned.fill(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTapUp: _handleTap,
                ),
              ),

              // 1時間ごとの横線
              for (var h = 1; h < 24; h++)
                Positioned(
                  top: h * _hourHeight,
                  left: 0,
                  right: 0,
                  child: IgnorePointer(
                    child: Container(
                      height: 0.5,
                      color: colorScheme.outlineVariant,
                    ),
                  ),
                ),

              // 昼休み
              if (showLunch)
                Positioned(
                  top: _yOfMinutes(SchoolPeriods.lunchStart.totalMinutes),
                  height:
                      _yOfMinutes(SchoolPeriods.lunchEnd.totalMinutes) -
                      _yOfMinutes(SchoolPeriods.lunchStart.totalMinutes),
                  left: 2,
                  right: 2,
                  child: IgnorePointer(
                    child: Container(
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: colorScheme.surfaceContainerLow,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        '昼休み',
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          fontSize: 10,
                          color: colorScheme.outline,
                        ),
                      ),
                    ),
                  ),
                ),

              // 授業と予定のブロック（重なったら横に並べる）
              for (var i = 0; i < items.length; i++)
                Positioned(
                  top: _yOfMinutes(items[i].start) + 1,
                  height: math.max(
                    _yOfMinutes(items[i].end) - _yOfMinutes(items[i].start) - 2,
                    16,
                  ),
                  left: width * slots[i].column / slots[i].columnCount + 2,
                  width: width / slots[i].columnCount - 4,
                  child: items[i].lesson != null
                      ? _LessonBlock(
                          date: date,
                          lesson: items[i].lesson!,
                          category: categoryOf[items[i].lesson!.subject],
                        )
                      : _EventBlock(
                          event: items[i].event!,
                          color: colorOf(items[i].event!),
                          onTap: () => onEventTap(items[i].event!),
                        ),
                ),

              // 現在時刻の赤い線（今日だけ）
              if (isToday)
                Positioned(
                  top: _yOfMinutes(nowMinutes) - 4,
                  left: 0,
                  right: 0,
                  child: const IgnorePointer(child: _NowLine()),
                ),
            ],
          );
        },
      ),
    );
  }
}

/// 予定1件のブロック（カテゴリの色で塗りつぶす）
class _EventBlock extends StatelessWidget {
  const _EventBlock({
    required this.event,
    required this.color,
    required this.onTap,
  });

  final CalendarEvent event;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final foreground = readableTextColor(color);

    return Material(
      color: color,
      borderRadius: BorderRadius.circular(6),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(4, 2, 2, 2),
          child: SingleChildScrollView(
            physics: const NeverScrollableScrollPhysics(),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  event.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: textTheme.labelMedium?.copyWith(
                    color: foreground,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  '${_hm(event.start)}〜${_hm(event.end)}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: textTheme.labelSmall?.copyWith(
                    fontSize: 10,
                    color: foreground,
                  ),
                ),
                if (event.location != null)
                  Text(
                    event.location!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: textTheme.labelSmall?.copyWith(
                      fontSize: 10,
                      color: foreground,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// 授業1コマのブロック（教科の色を淡く）
class _LessonBlock extends StatelessWidget {
  const _LessonBlock({
    required this.date,
    required this.lesson,
    required this.category,
  });

  final DateTime date;
  final ResolvedLesson lesson;
  final String? category;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    final isCancelled = lesson.status == LessonStatus.cancelled;
    final isEmpty = lesson.status == LessonStatus.empty;
    final isFaded = isCancelled || isEmpty;

    final base = categoryColor(category);
    final background = isFaded
        ? colorScheme.surfaceContainerHigh
        : base.withValues(alpha: 0.22);
    final foreground = isFaded
        ? colorScheme.outline
        : Color.lerp(base, Colors.black, 0.45)!;

    final statusLabel = switch (lesson.status) {
      LessonStatus.changed => '変更',
      LessonStatus.added => '追加',
      LessonStatus.cancelled => '休講',
      _ => null,
    };

    return Material(
      color: background,
      borderRadius: BorderRadius.circular(6),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => _showLessonDetails(context, date, lesson, category),
        child: Container(
          decoration: BoxDecoration(
            border: Border(
              left: BorderSide(
                color: isFaded ? colorScheme.outline : base,
                width: 3,
              ),
            ),
          ),
          padding: const EdgeInsets.fromLTRB(4, 2, 2, 2),
          // ブロックが小さいときに文字があふれても、エラーにならないようにする
          child: SingleChildScrollView(
            physics: const NeverScrollableScrollPhysics(),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  lesson.subject ?? '未設定',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: textTheme.labelMedium?.copyWith(
                    color: foreground,
                    fontWeight: FontWeight.bold,
                    decoration: isCancelled ? TextDecoration.lineThrough : null,
                  ),
                ),
                Text(
                  '${lesson.period}限 ${lesson.start}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: textTheme.labelSmall?.copyWith(
                    fontSize: 10,
                    color: foreground,
                  ),
                ),
                if (statusLabel != null)
                  Text(
                    statusLabel,
                    style: textTheme.labelSmall?.copyWith(
                      fontSize: 10,
                      color: colorScheme.tertiary,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// 授業の詳細（下から出てくるシート）
void _showLessonDetails(
  BuildContext context,
  DateTime date,
  ResolvedLesson lesson,
  String? category,
) {
  final statusText = switch (lesson.status) {
    LessonStatus.normal => null,
    LessonStatus.changed => '時間割変更あり',
    LessonStatus.added => '追加の授業',
    LessonStatus.cancelled => '休講',
    LessonStatus.empty => '時間割が未設定',
  };

  showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    builder: (context) {
      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                lesson.subject ?? '未設定',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 8),
              _DetailRow(
                icon: Icons.schedule,
                text:
                    '${formatDateJa(date)}  ${lesson.period}限  '
                    '${lesson.start}〜${lesson.end}',
              ),
              if (category != null)
                _DetailRow(icon: Icons.label_outline, text: category),
              if (lesson.room != null)
                _DetailRow(icon: Icons.room_outlined, text: lesson.room!),
              if (lesson.teacher != null)
                _DetailRow(icon: Icons.person_outline, text: lesson.teacher!),
              if (lesson.memo != null)
                _DetailRow(icon: Icons.notes, text: lesson.memo!),
              if (statusText != null)
                _DetailRow(icon: Icons.info_outline, text: statusText),
            ],
          ),
        ),
      );
    },
  );
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, size: 20, color: Theme.of(context).colorScheme.outline),
          const SizedBox(width: 12),
          Expanded(child: Text(text)),
        ],
      ),
    );
  }
}

/// 現在時刻の赤い線
class _NowLine extends StatelessWidget {
  const _NowLine();

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.error;
    return SizedBox(
      height: 8,
      child: Row(
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          Expanded(child: Container(height: 2, color: color)),
        ],
      ),
    );
  }
}
