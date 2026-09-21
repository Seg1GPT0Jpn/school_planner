/// 「今日のおすすめ」カード（ホーム画面用）
library;

import 'package:material_ui/material_ui.dart';

import '../todo/todo.dart';
import 'today_plan.dart';

String _fmt(int m) => m >= 60 ? '${m ~/ 60}時間${m % 60 == 0 ? '' : '${m % 60}分'}' : '$m分';

class TodayPlanCard extends StatelessWidget {
  const TodayPlanCard({
    super.key,
    required this.plan,
    required this.onToggle,
    required this.onTap,
  });

  final TodayPlan plan;
  final void Function(Todo todo, bool done) onToggle;
  final ValueChanged<Todo> onTap;

  String _dot(PlanPriority p) => switch (p) {
    PlanPriority.high => '🔴',
    PlanPriority.medium => '🟡',
    PlanPriority.low => '🟢',
  };

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    if (plan.items.isEmpty) return const SizedBox.shrink();

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
                Text('今日のおすすめ', style: tt.titleMedium),
              ],
            ),
            const SizedBox(height: 8),
            for (final item in plan.items)
              InkWell(
                onTap: () => onTap(item.todo),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    children: [
                      Checkbox(
                        value: item.todo.done,
                        onChanged: (v) => onToggle(item.todo, v ?? false),
                      ),
                      Text(_dot(item.priority)),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          item.todo.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Text(
                        _fmt(item.minutes),
                        style: tt.bodySmall?.copyWith(color: cs.outline),
                      ),
                    ],
                  ),
                ),
              ),
            const Divider(height: 20),
            Row(
              children: [
                Text('合計：約${_fmt(plan.totalMinutes)}', style: tt.labelLarge),
              ],
            ),
            if (plan.note != null) ...[
              const SizedBox(height: 6),
              Text(
                plan.note!,
                style: tt.bodySmall?.copyWith(color: cs.error),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
