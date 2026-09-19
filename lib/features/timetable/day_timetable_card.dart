import 'package:material_ui/material_ui.dart';

import 'day_timetable_resolver.dart';
import 'school_periods.dart';
import '../../core/date_format.dart';
import 'day_timetable_resolver.dart';

/// 1日分の時間割を表示するカード
class DayTimetableCard extends StatelessWidget {
  const DayTimetableCard({super.key, required this.title, required this.day});

  /// カードの見出し（例：今日の時間割）
  final String title;

  /// 表示する1日分の時間割
  final DayTimetable day;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final isException = day.isWeekOverridden || day.isDayWeekTypeOverridden;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 見出しと週の種類
            Row(
              children: [
                Expanded(child: Text(title, style: textTheme.titleMedium)),
                if (day.weekType != null && day.status == DayStatus.school)
                  _Tag(
                    label: isException
                        ? '${day.weekType!.label}（例外）'
                        : day.weekType!.label,
                    background: colorScheme.secondaryContainer,
                    foreground: colorScheme.onSecondaryContainer,
                  ),
              ],
            ),
            Text(
              formatDateJa(day.date),
              style: textTheme.bodySmall?.copyWith(color: colorScheme.outline),
            ),

            // 時間割変更あり（目立ちすぎない表示）
            if (day.hasChanges) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(
                    Icons.info_outline,
                    size: 16,
                    color: colorScheme.tertiary,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '時間割変更あり',
                    style: textTheme.bodySmall?.copyWith(
                      color: colorScheme.tertiary,
                    ),
                  ),
                ],
              ),
            ],
            if (day.note != null) ...[
              const SizedBox(height: 4),
              Text(day.note!, style: textTheme.bodySmall),
            ],

            const SizedBox(height: 12),
            ..._buildBody(context),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildBody(BuildContext context) {
    switch (day.status) {
      case DayStatus.closed:
        return [Text('休業日：${day.closureTitle ?? ''}')];
      case DayStatus.noSchool:
        return [const Text('授業はありません')];
      case DayStatus.weekUnknown:
        return [const Text('Ⅰ週/Ⅱ週の基準日が設定されていません')];
      case DayStatus.school:
        final rows = <Widget>[];
        const lunchAfter = SchoolPeriods.lunchAfterPeriod;
        final hasMorning = day.lessons.any((l) => l.period <= lunchAfter);
        for (final lesson in day.lessons) {
          // 午前の授業と午後の授業の間に昼休みを入れる
          if (lesson.period == lunchAfter + 1 && hasMorning) {
            rows.add(const _LunchRow());
          }
          rows.add(_LessonRow(lesson: lesson));
        }
        return rows;
    }
  }
}

/// 授業1コマの行
class _LessonRow extends StatelessWidget {
  const _LessonRow({required this.lesson});

  final ResolvedLesson lesson;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final isCancelled = lesson.status == LessonStatus.cancelled;

    final statusLabel = switch (lesson.status) {
      LessonStatus.changed => '変更',
      LessonStatus.added => '追加',
      LessonStatus.cancelled => '休講',
      _ => null,
    };

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          SizedBox(
            width: 96,
            child: Text(
              '${lesson.start}〜${lesson.end}',
              style: textTheme.bodySmall?.copyWith(color: colorScheme.outline),
            ),
          ),
          SizedBox(
            width: 36,
            child: Text('${lesson.period}限', style: textTheme.bodySmall),
          ),
          Expanded(
            child: Text(
              lesson.subject ?? '（未設定）',
              style: isCancelled
                  ? TextStyle(
                      decoration: TextDecoration.lineThrough,
                      color: colorScheme.outline,
                    )
                  : null,
            ),
          ),
          if (statusLabel != null)
            _Tag(
              label: statusLabel,
              background: colorScheme.tertiaryContainer,
              foreground: colorScheme.onTertiaryContainer,
            ),
        ],
      ),
    );
  }
}

/// 昼休みの行
class _LunchRow extends StatelessWidget {
  const _LunchRow();

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.outline;
    final style = Theme.of(context).textTheme.bodySmall?.copyWith(color: color);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          SizedBox(
            width: 96,
            child: Text(
              '${SchoolPeriods.lunchStart}〜${SchoolPeriods.lunchEnd}',
              style: style,
            ),
          ),
          Text('昼休み', style: style),
        ],
      ),
    );
  }
}

/// 小さな印（Ⅰ週・変更・休講など）
class _Tag extends StatelessWidget {
  const _Tag({
    required this.label,
    required this.background,
    required this.foreground,
  });

  final String label;
  final Color background;
  final Color foreground;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall
            ?.copyWith(color: foreground),
      ),
    );
  }
}
