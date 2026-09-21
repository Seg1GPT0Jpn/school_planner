/// キーボードショートカットの一覧と ON/OFF
library;

import 'package:material_ui/material_ui.dart';

import 'preferences_pages.dart';
import 'settings_scope.dart';

/// ショートカット1つ（一覧と、カレンダーの割り当ての両方で使う）
class ShortcutInfo {
  const ShortcutInfo(this.keys, this.description, {this.always = false});

  /// 押すキー（例：W）
  final String keys;

  final String description;

  /// 設定が OFF でも使えるもの
  final bool always;
}

/// つづりのキーボードショートカット
const tsuzuriShortcuts = [
  ShortcutInfo('Ctrl + Z', '前の表示にもどる', always: true),
  ShortcutInfo('Ctrl + Y', '次の表示にすすむ', always: true),
  ShortcutInfo('Alt + ← / →', '前の表示にもどる／すすむ', always: true),
  ShortcutInfo('D', '日の表示にする'),
  ShortcutInfo('W', '週の表示にする'),
  ShortcutInfo('M', '月の表示にする'),
  ShortcutInfo('A', 'スケジュールの表示にする'),
  ShortcutInfo('X', 'カスタムの表示にする'),
  ShortcutInfo('T', '今日にもどる'),
  ShortcutInfo('J / N / →', '次の週・月へ'),
  ShortcutInfo('K / P / ←', '前の週・月へ'),
  ShortcutInfo('C', '予定を追加する'),
];

class ShortcutsPage extends StatelessWidget {
  const ShortcutsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final s = SettingsScope.of(context);
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('キーボードショートカット')),
      body: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: ListView(
            padding: const EdgeInsets.only(bottom: 24),
            children: [
              SwitchListTile(
                secondary: const Icon(Icons.keyboard_outlined),
                title: const Text('キーボードショートカットを使う'),
                subtitle: const Text('パソコンでカレンダーを見ているときに効きます'),
                value: s.keyboardShortcuts,
                onChanged: (v) =>
                    saveSettings(context, s.copyWith(keyboardShortcuts: v)),
              ),
              const Divider(height: 24),
              for (final k in tsuzuriShortcuts)
                Opacity(
                  opacity: (s.keyboardShortcuts || k.always) ? 1 : 0.4,
                  child: ListTile(
                    dense: true,
                    leading: Container(
                      constraints: const BoxConstraints(minWidth: 84),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: cs.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        k.keys,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontFamily: 'monospace',
                          fontSize: 12,
                        ),
                      ),
                    ),
                    title: Text(k.description),
                    subtitle: k.always ? const Text('いつでも使えます') : null,
                  ),
                ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                child: Text(
                  '文字を入力しているときは、ショートカットは効きません。',
                  style: TextStyle(color: cs.outline, fontSize: 12),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
