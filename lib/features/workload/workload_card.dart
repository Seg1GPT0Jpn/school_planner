/// ホームに出す「予定の負荷」カード
library;

import 'package:material_ui/material_ui.dart';

import '../settings/app_settings.dart';
import 'workload.dart';

class WorkloadCard extends StatelessWidget {
  const WorkloadCard({
    super.key,
    required this.week,
    required this.settings,
  });

  final List<DayLoad> week;
  final AppSettings settings;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final warning = weekLoadWarning(week);
    final maxMinutes = week
        .map((d) => d.busyMinutes)
        .fold<int>(60, (m, x) => x > m ? x : m);

    return Card(
      color: warning != null ? cs.errorContainer.withValues(alpha: 0.35) : null,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.insights_outlined, color: cs.primary),
                const SizedBox(width: 8),
                Text('今週の予定の負荷', style: tt.titleMedium),
              ],
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 64,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  for (final d in week)
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 3),
                        child: Tooltip(
                          message: [
                            settings.date(d.day, weekday: true),
                            if (d.busyMinutes > 0) '予定 ${d.eventCount}件',
                            if (d.testCount > 0) 'テスト ${d.testCount}件',
                          ].join('・'),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              if (d.testCount > 0)
                                const Text('📝', style: TextStyle(fontSize: 11)),
                              Expanded(
                                child: FractionallySizedBox(
                                  heightFactor: d.busyMinutes == 0
                                      ? 0.02
                                      : (d.busyMinutes / maxMinutes).clamp(
                                          0.05,
                                          1.0,
                                        ),
                                  alignment: Alignment.bottomCenter,
                                  child: Container(
                                    decoration: BoxDecoration(
                                      color: d.isHeavy
                                          ? cs.error
                                          : cs.primary.withValues(alpha: 0.6),
                                      borderRadius: BorderRadius.circular(3),
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                _weekdayLabel(d.day),
                                style: tt.bodySmall?.copyWith(
                                  color: cs.outline,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            if (warning != null) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(Icons.warning_amber_outlined, size: 16, color: cs.error),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      warning,
                      style: tt.bodySmall?.copyWith(color: cs.error),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  static String _weekdayLabel(DateTime d) =>
      const ['月', '火', '水', '木', '金', '土', '日'][d.weekday - 1];
}
