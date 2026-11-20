/// 完了直後に「実際どれくらいかかったか」を軽く聞くシート
///
/// 回答は完全に任意（スキップできる）。学習（[TimingLearningRepository]）の
/// 記録にだけ使う。
library;

import 'package:material_ui/material_ui.dart';

import '../todo/todo.dart';
import 'timing_learning.dart';

const _quickOptions = <int>[5, 15, 30, 45, 60, 90, 120];

String _label(int m) {
  if (m < 60) return '$m分';
  final h = m ~/ 60;
  final rest = m % 60;
  return rest == 0 ? '$h時間' : '$h時間$rest分';
}

Future<void> promptActualTime(
  BuildContext context, {
  required Todo todo,
  required TimingLearningRepository repository,
}) async {
  final selected = await showModalBottomSheet<int>(
    context: context,
    builder: (ctx) {
      final tt = Theme.of(ctx).textTheme;
      final cs = Theme.of(ctx).colorScheme;
      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '「${todo.title}」実際どれくらいかかりましたか？',
                style: tt.titleSmall,
              ),
              const SizedBox(height: 4),
              Text(
                '次回からの見積もりの参考にします（任意です）',
                style: tt.bodySmall?.copyWith(color: cs.outline),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final m in _quickOptions)
                    ActionChip(
                      label: Text(_label(m)),
                      onPressed: () => Navigator.of(ctx).pop(m),
                    ),
                ],
              ),
              const SizedBox(height: 4),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () => Navigator.of(ctx).pop(),
                  child: const Text('スキップ'),
                ),
              ),
            ],
          ),
        ),
      );
    },
  );
  if (selected != null) {
    await repository.record(todo, selected);
  }
}
