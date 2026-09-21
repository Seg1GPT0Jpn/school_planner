/// レビュー・カルテ・イベントで共通の見た目の部品
library;

import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';

/// 見出しつきのカード
class InfoCard extends StatelessWidget {
  const InfoCard({
    super.key,
    required this.title,
    required this.children,
    this.icon,
    this.trailing,
  });

  final String title;
  final IconData? icon;
  final Widget? trailing;
  final List<Widget> children;

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
                if (icon != null) ...[
                  Icon(icon, size: 20, color: cs.primary),
                  const SizedBox(width: 6),
                ],
                Expanded(child: Text(title, style: tt.titleMedium)),
                ?trailing,
              ],
            ),
            const SizedBox(height: 8),
            ...children,
          ],
        ),
      ),
    );
  }
}

/// うすい色の説明文
class Faint extends StatelessWidget {
  const Faint(this.text, {super.key});
  final String text;

  @override
  Widget build(BuildContext context) => Text(
    text,
    style: TextStyle(
      color: Theme.of(context).colorScheme.outline,
      fontSize: 13,
    ),
  );
}

/// 大きい数字と、その下の説明
class BigNumber extends StatelessWidget {
  const BigNumber({super.key, required this.value, required this.label});
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(value, style: tt.headlineSmall),
        Text(
          label,
          style: tt.bodySmall?.copyWith(
            color: Theme.of(context).colorScheme.outline,
          ),
        ),
      ],
    );
  }
}

/// かんたんな棒グラフ（勉強時間など）
class MiniBars extends StatelessWidget {
  const MiniBars({
    super.key,
    required this.values,
    this.labels = const [],
    this.height = 72,
    this.highlight,
  });

  final List<int> values;

  /// 棒の下に出す文字（values と同じ数。空なら出さない）
  final List<String> labels;
  final double height;

  /// 色を変える棒（今日など）
  final int? highlight;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final top = math.max(1, values.fold<int>(0, math.max));
    return Column(
      children: [
        SizedBox(
          height: height,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              for (var i = 0; i < values.length; i++)
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 1.5),
                    child: Tooltip(
                      message: '${values[i]}分',
                      child: Container(
                        height: values[i] == 0
                            ? 2
                            : math.max(3, height * values[i] / top),
                        decoration: BoxDecoration(
                          color: values[i] == 0
                              ? cs.outlineVariant
                              : (i == highlight ? cs.tertiary : cs.primary),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
        if (labels.length == values.length) ...[
          const SizedBox(height: 4),
          Row(
            children: [
              for (final l in labels)
                Expanded(
                  child: Text(
                    l,
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 10, color: cs.outline),
                  ),
                ),
            ],
          ),
        ],
      ],
    );
  }
}

/// 科目ごとの横棒
class SubjectBars extends StatelessWidget {
  const SubjectBars({super.key, required this.entries, this.max = 6});

  final List<MapEntry<String, int>> entries;
  final int max;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    if (entries.isEmpty) return const SizedBox.shrink();
    final top = entries.first.value.clamp(1, 1 << 30);
    return Column(
      children: [
        for (final e in entries.take(max))
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 3),
            child: Row(
              children: [
                SizedBox(
                  width: 96,
                  child: Text(e.key, overflow: TextOverflow.ellipsis),
                ),
                Expanded(
                  child: LinearProgressIndicator(
                    value: e.value / top,
                    minHeight: 8,
                    borderRadius: BorderRadius.circular(4),
                    backgroundColor: cs.surfaceContainerHighest,
                  ),
                ),
                SizedBox(
                  width: 72,
                  child: Text(
                    _hm(e.value),
                    textAlign: TextAlign.right,
                    style: TextStyle(fontSize: 12, color: cs.outline),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

String _hm(int m) =>
    m < 60 ? '$m分' : (m % 60 == 0 ? '${m ~/ 60}時間' : '${m ~/ 60}時間${m % 60}分');
