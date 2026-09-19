import 'package:material_ui/material_ui.dart';

import '../../core/date_format.dart';
import 'upcoming_tests.dart';

/// ホームに出す「これからのテスト・提出物」
class UpcomingTestsCard extends StatelessWidget {
  const UpcomingTestsCard({
    super.key,
    required this.items,
    required this.today,
    required this.days,
    this.onTapItem,
  });

  final List<UpcomingItem> items;
  final DateTime today;

  /// 何日分を集めたか（見出しに表示）
  final int days;

  /// 項目をタップしたとき（手で登録したものの編集など）
  final ValueChanged<UpcomingItem>? onTapItem;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text('これからのテスト・提出物', style: textTheme.titleMedium),
                ),
                Text(
                  days == 14 ? '2週間' : '$days日間',
                  style: textTheme.bodySmall?.copyWith(
                    color: colorScheme.outline,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (items.isEmpty)
              Text(
                'この期間の予定はありません',
                style: textTheme.bodyMedium?.copyWith(
                  color: colorScheme.outline,
                ),
              )
            else
              for (final item in items)
                _UpcomingRow(
                  item: item,
                  today: today,
                  onTap: (onTapItem != null && item.source != null)
                      ? () => onTapItem!(item)
                      : null,
                ),
          ],
        ),
      ),
    );
  }
}

class _UpcomingRow extends StatelessWidget {
  const _UpcomingRow({required this.item, required this.today, this.onTap});

  final UpcomingItem item;
  final DateTime today;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    final n = item.daysFrom(today);
    final countdown = switch (n) {
      0 => '今日',
      1 => '明日',
      _ => 'あと$n日',
    };
    final isSoon = n <= 2;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 日付と「あと○日」
            SizedBox(
              width: 72,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${item.date.month}/${item.date.day}'
                    '(${weekdayLabel(item.date.weekday)})',
                    style: textTheme.bodySmall,
                  ),
                  Text(
                    countdown,
                    style: textTheme.labelSmall?.copyWith(
                      color: isSoon ? colorScheme.error : colorScheme.outline,
                      fontWeight: isSoon ? FontWeight.bold : null,
                    ),
                  ),
                ],
              ),
            ),
            // 名前と範囲
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.period == null
                        ? item.title
                        : '${item.title}（${item.period}限）',
                  ),
                  if (item.detail != null)
                    Text(
                      item.detail!,
                      style: textTheme.bodySmall?.copyWith(
                        color: colorScheme.outline,
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            // 種類
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: item.isTest
                    ? colorScheme.errorContainer
                    : colorScheme.secondaryContainer,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                item.kindLabel,
                style: textTheme.labelSmall?.copyWith(
                  color: item.isTest
                      ? colorScheme.onErrorContainer
                      : colorScheme.onSecondaryContainer,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
