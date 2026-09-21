/// 設定 ＞ よく使う路線
library;

import 'package:material_ui/material_ui.dart';

import '../settings/preferences_pages.dart';
import '../settings/settings_scope.dart';
import 'train_lines.dart';

class LinePickerPage extends StatelessWidget {
  const LinePickerPage({super.key});

  @override
  Widget build(BuildContext context) {
    final s = SettingsScope.of(context);
    final selected = s.favoriteLineIds.toSet();

    void toggle(String id, bool value) {
      final next = selected.toSet();
      if (value) {
        next.add(id);
      } else {
        next.remove(id);
      }
      saveSettings(context, s.copyWith(favoriteLineIds: next.toList()));
    }

    return Scaffold(
      appBar: AppBar(title: const Text('よく使う路線')),
      body: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: ListView(
            padding: const EdgeInsets.only(bottom: 24),
            children: [
              const Padding(
                padding: EdgeInsets.fromLTRB(16, 12, 16, 4),
                child: Text('選んだ路線の運行状況を、ホーム画面で見られるようにします。'),
              ),
              for (final line in trainLines)
                CheckboxListTile(
                  title: Text(line.name),
                  subtitle: Text(line.operatorName),
                  value: selected.contains(line.id),
                  onChanged: (v) => toggle(line.id, v ?? false),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
