/// ホームに出す「がんばり」カード
library;

import 'package:material_ui/material_ui.dart';

import 'gamification.dart';

class GamificationCard extends StatelessWidget {
  const GamificationCard({super.key, required this.stats});

  final GamificationStats stats;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    Widget stat(String label, String value) => Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: tt.bodySmall?.copyWith(color: cs.outline)),
          Text(value, style: tt.titleLarge),
        ],
      ),
    );

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.emoji_events_outlined, color: cs.primary),
                const SizedBox(width: 8),
                Text('がんばり', style: tt.titleMedium),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                stat('ポイント', '${stats.points}pt'),
                stat(
                  '連続達成',
                  stats.currentStreak == 0 ? '－' : '${stats.currentStreak}日',
                ),
                stat('達成した数', '${stats.completedCount}個'),
              ],
            ),
            if (stats.badges.isNotEmpty) ...[
              const SizedBox(height: 12),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  for (final b in stats.badges.take(6))
                    Tooltip(
                      message: '${b.label}\n${b.description}',
                      child: Chip(
                        visualDensity: VisualDensity.compact,
                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        avatar: Text(b.icon),
                        label: Text(b.label),
                      ),
                    ),
                ],
              ),
            ],
            if (stats.nextBadge != null) ...[
              const SizedBox(height: 8),
              Text(
                '次のバッジ：${stats.nextBadge}',
                style: tt.bodySmall?.copyWith(color: cs.outline),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
