import 'dart:async';
import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';

import '../../core/date_format.dart';
import '../timetable/day_timetable_resolver.dart';
import '../timetable/school_periods.dart';
import '../timetable/subject_colors.dart';
import '../timetable/timetable_repository.dart';
import '../timetable/week_cycle.dart';

/// 1時間あたりの高さ（ピクセル）
const double _hourHeight = 56;

/// 左端の時刻の列の幅
const double _gutterWidth = 44;

/// 時刻を、上からの位置（ピクセル）に変換する
double _yOf(ClockTime time) => time.totalMinutes / 60 * _hourHeight;

bool _isSameDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;

/// Google カレンダー風の時間軸表示（週表示・日表示の共通部品）
class TimeGridView extends StatefulWidget {
  const TimeGridView({
    super.key,
    required this.data,
    required this.days,
    required this.today,
  });

  final TimetableData data;

  /// 表示する日（週表示なら7日、日表示なら1日）
  final List<DateTime> days;

  final DateTime today;

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
  });

  final List<DateTime> days;
  final List<DayTimetable> timetables;
  final DateTime today;
  final WeekType? weekType;

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
  });

  final DateTime date;
  final DayTimetable day;
  final bool isToday;

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
  });

  final String text;
  final Color background;
  final Color foreground;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(4),
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

class _DayColumn extends StatelessWidget {
  const _DayColumn({
    required this.date,
    required this.day,
    required this.isToday,
    required this.now,
    required this.categoryOf,
  });

  final DateTime date;
  final DayTimetable day;
  final bool isToday;
  final DateTime now;
  final Map<String, String> categoryOf;

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

    final nowMinutes = now.hour * 60 + now.minute;

    return Container(
      decoration: BoxDecoration(
        color: isToday ? colorScheme.primary.withValues(alpha: 0.04) : null,
        border: Border(
          left: BorderSide(color: colorScheme.outlineVariant, width: 0.5),
        ),
      ),
      child: Stack(
        children: [
          // 1時間ごとの横線
          for (var h = 1; h < 24; h++)
            Positioned(
              top: h * _hourHeight,
              left: 0,
              right: 0,
              child: Container(height: 0.5, color: colorScheme.outlineVariant),
            ),

          // 昼休み
          if (showLunch)
            Positioned(
              top: _yOf(SchoolPeriods.lunchStart),
              height:
                  _yOf(SchoolPeriods.lunchEnd) - _yOf(SchoolPeriods.lunchStart),
              left: 2,
              right: 2,
              child: Container(
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: colorScheme.surfaceContainerLow,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  '昼休み',
                  style: Theme.of(context).textTheme.labelSmall
                      ?.copyWith(fontSize: 10, color: colorScheme.outline),
                ),
              ),
            ),

          // 授業のブロック
          if (isSchool)
            for (final lesson in day.lessons)
              Positioned(
                top: _yOf(lesson.start) + 1,
                height: math.max(_yOf(lesson.end) - _yOf(lesson.start) - 2, 16),
                left: 2,
                right: 2,
                child: _LessonBlock(
                  date: date,
                  lesson: lesson,
                  category: categoryOf[lesson.subject],
                ),
              ),

          // 現在時刻の赤い線（今日だけ）
          if (isToday)
            Positioned(
              top: nowMinutes / 60 * _hourHeight - 4,
              left: 0,
              right: 0,
              child: const _NowLine(),
            ),
        ],
      ),
    );
  }
}

/// 授業1コマのブロック
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
