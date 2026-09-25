/// ごく軽量な Markdown 表示
///
/// 対応するのは、見出し（# ## ###）・太字（**text**）・箇条書き（- text）・
/// チェックリスト（- [ ] text / - [x] text）だけ。外部パッケージを使わず、
/// メモに必要な最低限だけを自前で描く。
library;

import 'package:material_ui/material_ui.dart';

final _checklistLine = RegExp(r'^(\s*)-\s\[([ xX])\]\s?(.*)$');
final _bulletLine = RegExp(r'^(\s*)[-*]\s(.*)$');
final _boldPattern = RegExp(r'\*\*(.+?)\*\*');

class MiniMarkdownView extends StatelessWidget {
  const MiniMarkdownView({super.key, required this.text, this.onToggleCheck});

  final String text;

  /// チェックリストの行（テキスト全体での行番号）がタップされたときに呼ばれる
  final void Function(int lineIndex, bool checked)? onToggleCheck;

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    final lines = text.split('\n');
    final widgets = <Widget>[];

    for (var i = 0; i < lines.length; i++) {
      final line = lines[i];

      final checklist = _checklistLine.firstMatch(line);
      if (checklist != null) {
        final checked = checklist.group(2)!.toLowerCase() == 'x';
        final label = checklist.group(3) ?? '';
        widgets.add(
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 1),
            child: InkWell(
              onTap: onToggleCheck == null
                  ? null
                  : () => onToggleCheck!(i, !checked),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Icon(
                      checked
                          ? Icons.check_box
                          : Icons.check_box_outline_blank,
                      size: 20,
                      color: checked ? cs.primary : cs.outline,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text.rich(
                      _inline(label, tt.bodyMedium),
                      style: checked
                          ? TextStyle(
                              decoration: TextDecoration.lineThrough,
                              color: cs.outline,
                            )
                          : null,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
        continue;
      }

      if (line.startsWith('### ')) {
        widgets.add(_heading(line.substring(4), tt.titleSmall));
        continue;
      }
      if (line.startsWith('## ')) {
        widgets.add(_heading(line.substring(3), tt.titleMedium));
        continue;
      }
      if (line.startsWith('# ')) {
        widgets.add(_heading(line.substring(2), tt.titleLarge));
        continue;
      }

      final bullet = _bulletLine.firstMatch(line);
      if (bullet != null) {
        widgets.add(
          Padding(
            padding: const EdgeInsets.only(bottom: 2),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Padding(
                  padding: EdgeInsets.only(left: 4, right: 8),
                  child: Text('•'),
                ),
                Expanded(
                  child: Text.rich(_inline(bullet.group(2) ?? '', tt.bodyMedium)),
                ),
              ],
            ),
          ),
        );
        continue;
      }

      if (line.trim().isEmpty) {
        widgets.add(const SizedBox(height: 8));
        continue;
      }

      widgets.add(
        Padding(
          padding: const EdgeInsets.only(bottom: 4),
          child: Text.rich(_inline(line, tt.bodyMedium)),
        ),
      );
    }

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: widgets);
  }

  Widget _heading(String text, TextStyle? style) => Padding(
    padding: const EdgeInsets.only(top: 10, bottom: 4),
    child: Text(text.trim(), style: style?.copyWith(fontWeight: FontWeight.bold)),
  );

  TextSpan _inline(String s, TextStyle? base) {
    final spans = <InlineSpan>[];
    var last = 0;
    for (final m in _boldPattern.allMatches(s)) {
      if (m.start > last) spans.add(TextSpan(text: s.substring(last, m.start)));
      spans.add(
        TextSpan(
          text: m.group(1),
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
      );
      last = m.end;
    }
    if (last < s.length) spans.add(TextSpan(text: s.substring(last)));
    return TextSpan(style: base, children: spans);
  }
}
