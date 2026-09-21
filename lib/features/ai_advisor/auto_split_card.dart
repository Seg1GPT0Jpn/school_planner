/// 「自動分割」カード（ホーム画面用）
///
/// 大きめの ToDo を見つけたら、締切までの分割プランをその場で見られるようにする。
/// あくまでプレビューで、保存はしない（安全に何度でも試せる）。
library;

import 'package:material_ui/material_ui.dart';

import '../todo/todo.dart';
import '../workload/workload.dart';
import 'auto_split.dart';
import 'today_plan.dart';

class AutoSplitCard extends StatelessWidget {
  const AutoSplitCard({
    super.key,
    required this.candidates,
    required this.weekLoad,
    required this.now,
  });

  final List<Todo> candidates;
  final List<DayLoad> weekLoad;
  final DateTime now;

  void _showPlan(BuildContext context, Todo t) {
    final total = estimateMinutes(t) * 3; // 分割の対象になるくらいの規模感の目安
    final plan = splitWorkload(
      from: now,
      dueDate: t.dueDate!,
      totalMinutes: total,
      heavyDays: heavyDaysFrom(weekLoad),
    );
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('「${t.title}」の分割プラン'),
        content: SizedBox(
          width: 360,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '合計の見積もりを、締切までの日に振り分けました（忙しい日は少なめにしています）。',
                ),
                const SizedBox(height: 12),
                for (final d in plan)
                  if (d.minutes > 0)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 2),
                      child: Text(
                        '${d.date.month}/${d.date.day}　約${d.minutes}分',
                      ),
                    ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('閉じる'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (candidates.isEmpty) return const SizedBox.shrink();
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
                Icon(Icons.call_split, size: 20, color: cs.primary),
                const SizedBox(width: 6),
                Text('自動分割の提案', style: tt.titleMedium),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              'ボリュームがありそうな ToDo を、締切までの日に分けるプランを見られます',
              style: tt.bodySmall?.copyWith(color: cs.outline),
            ),
            const SizedBox(height: 8),
            for (final t in candidates.take(3))
              ListTile(
                contentPadding: EdgeInsets.zero,
                dense: true,
                title: Text(t.title, maxLines: 1, overflow: TextOverflow.ellipsis),
                trailing: TextButton(
                  onPressed: () => _showPlan(context, t),
                  child: const Text('分割プランを見る'),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
