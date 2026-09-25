/// 設定 ＞ よく使う路線
library;

import 'package:material_ui/material_ui.dart';

import '../settings/preferences_pages.dart';
import '../settings/settings_scope.dart';
import 'train_lines.dart';

class LinePickerPage extends StatefulWidget {
  const LinePickerPage({super.key});

  @override
  State<LinePickerPage> createState() => _LinePickerPageState();
}

class _LinePickerPageState extends State<LinePickerPage> {
  final _idController = TextEditingController();
  final _nameController = TextEditingController();
  String? _addError;

  @override
  void dispose() {
    _idController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = SettingsScope.of(context);
    final selected = s.favoriteLineIds.toSet();
    final custom = s.customLineNames;

    void toggle(String id, bool value) {
      final next = selected.toSet();
      if (value) {
        next.add(id);
      } else {
        next.remove(id);
      }
      saveSettings(context, s.copyWith(favoriteLineIds: next.toList()));
    }

    void addCustom() {
      final id = _idController.text.trim();
      final name = _nameController.text.trim();
      if (!id.startsWith('odpt.Railway:')) {
        setState(() => _addError = '路線IDは "odpt.Railway:" で始まります');
        return;
      }
      if (name.isEmpty) {
        setState(() => _addError = '路線名を入力してください');
        return;
      }
      final nextCustom = {...custom, id: name};
      final nextSelected = {...selected, id};
      saveSettings(
        context,
        s.copyWith(
          customLineNames: nextCustom,
          favoriteLineIds: nextSelected.toList(),
        ),
      );
      _idController.clear();
      _nameController.clear();
      setState(() => _addError = null);
    }

    void removeCustom(String id) {
      final nextCustom = {...custom}..remove(id);
      final nextSelected = {...selected}..remove(id);
      saveSettings(
        context,
        s.copyWith(
          customLineNames: nextCustom,
          favoriteLineIds: nextSelected.toList(),
        ),
      );
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
              if (custom.isNotEmpty) ...[
                const Padding(
                  padding: EdgeInsets.fromLTRB(16, 16, 16, 4),
                  child: Text('自分で追加した路線'),
                ),
                for (final entry in custom.entries)
                  CheckboxListTile(
                    title: Text(entry.value),
                    subtitle: Text(
                      entry.key,
                      style: const TextStyle(fontSize: 11),
                    ),
                    value: selected.contains(entry.key),
                    onChanged: (v) => toggle(entry.key, v ?? false),
                    secondary: IconButton(
                      icon: const Icon(Icons.delete_outline),
                      tooltip: '削除',
                      onPressed: () => removeCustom(entry.key),
                    ),
                  ),
              ],
              const Divider(height: 32),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '一覧に無い路線を追加',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'ODPT（公共交通オープンデータセンター、https://developer.odpt.org/）'
                      'の路線一覧で調べた路線ID（odpt.Railway:〜 の形）を入力すると、'
                      '日本全国どの路線でも追加できます。',
                      style: TextStyle(fontSize: 12),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _nameController,
                      decoration: const InputDecoration(
                        labelText: '路線名（例：札幌市営地下鉄南北線）',
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _idController,
                      decoration: const InputDecoration(
                        labelText: '路線ID（odpt.Railway:〜）',
                      ),
                    ),
                    if (_addError != null) ...[
                      const SizedBox(height: 6),
                      Text(
                        _addError!,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
                    ],
                    const SizedBox(height: 8),
                    Align(
                      alignment: Alignment.centerRight,
                      child: FilledButton(
                        onPressed: addCustom,
                        child: const Text('追加'),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
