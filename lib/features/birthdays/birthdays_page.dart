/// 誕生日一覧・登録・編集画面
library;

import 'package:material_ui/material_ui.dart';

import '../review/review_widgets.dart';
import 'birthday.dart';
import 'birthday_repository.dart';

void openBirthdays(BuildContext context, {required BirthdayRepository repository}) {
  Navigator.of(context, rootNavigator: true).push(
    MaterialPageRoute<void>(builder: (_) => BirthdaysPage(repository: repository)),
  );
}

class BirthdaysPage extends StatefulWidget {
  const BirthdaysPage({super.key, required this.repository});

  final BirthdayRepository repository;

  @override
  State<BirthdaysPage> createState() => _BirthdaysPageState();
}

class _BirthdaysPageState extends State<BirthdaysPage> {
  Future<void> _openEditor([Birthday? existing]) async {
    await showDialog<void>(
      context: context,
      builder: (_) =>
          _BirthdayEditDialog(repository: widget.repository, existing: existing),
    );
  }

  Future<void> _confirmDelete(Birthday b) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('削除しますか？'),
        content: Text('「${b.name}」の誕生日を削除します'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('キャンセル'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('削除'),
          ),
        ],
      ),
    );
    if (ok == true && b.id != null) {
      await widget.repository.delete(b.id!);
    }
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    return Scaffold(
      appBar: AppBar(title: const Text('誕生日')),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _openEditor(),
        child: const Icon(Icons.add),
      ),
      body: StreamBuilder<List<Birthday>>(
        stream: widget.repository.watch(),
        builder: (context, snapshot) {
          final items = [...?snapshot.data]
            ..sort((a, b) => a.daysUntilNext(now).compareTo(b.daysUntilNext(now)));
          if (items.isEmpty) {
            return const Center(child: Faint('まだ誕生日が登録されていません'));
          }
          return Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 640),
              child: ListView.builder(
                padding: const EdgeInsets.fromLTRB(8, 8, 8, 80),
                itemCount: items.length,
                itemBuilder: (context, i) {
                  final b = items[i];
                  final days = b.daysUntilNext(now);
                  final age = b.ageOn(b.nextOccurrence(now));
                  final subtitleParts = <String>[
                    '${b.month}月${b.day}日',
                    if (age != null) '$age歳に',
                    days == 0 ? '🎉今日！' : 'あと$days日',
                  ];
                  return Card(
                    child: ListTile(
                      leading: CircleAvatar(
                        child: Text(
                          b.name.isEmpty ? '?' : b.name.substring(0, 1),
                        ),
                      ),
                      title: Text(b.name),
                      subtitle: Text(subtitleParts.join(' ・ ')),
                      trailing: IconButton(
                        icon: const Icon(Icons.delete_outline),
                        onPressed: () => _confirmDelete(b),
                      ),
                      onTap: () => _openEditor(b),
                    ),
                  );
                },
              ),
            ),
          );
        },
      ),
    );
  }
}

class _BirthdayEditDialog extends StatefulWidget {
  const _BirthdayEditDialog({required this.repository, this.existing});

  final BirthdayRepository repository;
  final Birthday? existing;

  @override
  State<_BirthdayEditDialog> createState() => _BirthdayEditDialogState();
}

class _BirthdayEditDialogState extends State<_BirthdayEditDialog> {
  late final _nameController = TextEditingController(
    text: widget.existing?.name ?? '',
  );
  late final _memoController = TextEditingController(
    text: widget.existing?.memo ?? '',
  );
  late int _month = widget.existing?.month ?? DateTime.now().month;
  late int _day = widget.existing?.day ?? DateTime.now().day;
  late int? _year = widget.existing?.year;
  String? _error;
  bool _saving = false;

  @override
  void dispose() {
    _nameController.dispose();
    _memoController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final b = Birthday(
      id: widget.existing?.id,
      name: _nameController.text,
      month: _month,
      day: _day,
      year: _year,
      memo: _memoController.text,
    );
    final error = b.validate();
    if (error != null) {
      setState(() => _error = error);
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await widget.repository.save(b);
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = '保存できませんでした：$e';
          _saving = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.existing == null ? '誕生日を追加' : '誕生日を編集'),
      content: SizedBox(
        width: 360,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _nameController,
              autofocus: true,
              decoration: const InputDecoration(labelText: '名前'),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<int>(
                    initialValue: _month,
                    decoration: const InputDecoration(labelText: '月'),
                    items: [
                      for (var m = 1; m <= 12; m++)
                        DropdownMenuItem(value: m, child: Text('$m月')),
                    ],
                    onChanged: (v) => setState(() => _month = v ?? _month),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: DropdownButtonFormField<int>(
                    initialValue: _day,
                    decoration: const InputDecoration(labelText: '日'),
                    items: [
                      for (var d = 1; d <= 31; d++)
                        DropdownMenuItem(value: d, child: Text('$d日')),
                    ],
                    onChanged: (v) => setState(() => _day = v ?? _day),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            TextFormField(
              initialValue: _year?.toString() ?? '',
              decoration: const InputDecoration(
                labelText: '生まれた年（任意）',
                hintText: '例：2010',
              ),
              keyboardType: TextInputType.number,
              onChanged: (v) => _year = int.tryParse(v.trim()),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _memoController,
              decoration: const InputDecoration(labelText: 'メモ（任意）'),
            ),
            if (_error != null) ...[
              const SizedBox(height: 8),
              Text(_error!, style: const TextStyle(color: Colors.red)),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('キャンセル'),
        ),
        FilledButton(
          onPressed: _saving ? null : _save,
          child: Text(_saving ? '保存中…' : '保存'),
        ),
      ],
    );
  }
}
