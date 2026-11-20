/// 「AIアドバイス」カード（ホーム画面用）
library;

import 'package:material_ui/material_ui.dart';

import 'advisor.dart';

IconData _iconFor(AdvisorKind k) => switch (k) {
  AdvisorKind.workload => Icons.event_busy_outlined,
  AdvisorKind.examSoon => Icons.edit_note,
  AdvisorKind.todoOverdue => Icons.error_outline,
  AdvisorKind.streak => Icons.local_fire_department,
  AdvisorKind.streakBroken => Icons.refresh,
  AdvisorKind.mood => Icons.favorite_border,
  AdvisorKind.allGood => Icons.check_circle_outline,
};

class AdvisorCard extends StatelessWidget {
  const AdvisorCard({super.key, required this.tips});

  final List<AdvisorTip> tips;

  Color _color(ColorScheme cs, AdvisorTone tone) => switch (tone) {
    AdvisorTone.praise => cs.primary,
    AdvisorTone.notice => cs.error,
    AdvisorTone.tip => cs.outline,
  };

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.auto_awesome, size: 20, color: cs.primary),
                const SizedBox(width: 6),
                Text('AIアドバイス', style: tt.titleMedium),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              'あなたの記録から、自動で分析しています',
              style: tt.bodySmall?.copyWith(color: cs.outline),
            ),
            const SizedBox(height: 10),
            for (final t in tips)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 5),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      _iconFor(t.kind),
                      size: 18,
                      color: _color(cs, t.tone),
                    ),
                    const SizedBox(width: 8),
                    Expanded(child: Text(t.message)),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}
