import 'package:firebase_auth/firebase_auth.dart';
import 'package:material_ui/material_ui.dart';

import 'subject_colors.dart';
import 'subject_repository.dart';
import 'timetable_models.dart';
import 'timetable_repository.dart';

class SubjectManagePage extends StatefulWidget {
  const SubjectManagePage({super.key});

  @override
  State<SubjectManagePage> createState() => _SubjectManagePageState();
}

class _SubjectManagePageState extends State<SubjectManagePage> {
  late final String _uid = FirebaseAuth.instance.currentUser!.uid;
  late final _stream = TimetableRepository(uid: _uid).watch();
  late final _repo = SubjectRepository(uid: _uid);

  /// 名前と教科を入力するダイアログ（existing があれば教科の変更だけ）
  Future<Subject?> _dialog(List<String> categories, [Subject? existing]) {
    final name = TextEditingController(text: existing?.name);
    final category = TextEditingController(text: existing?.category);
    return showDialog<Subject>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text(existing == null ? '科目を追加' : '教科を変更'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: name,
              enabled: existing == null,
              decoration: const InputDecoration(labelText: '科目（例：数学Ⅱ）'),
            ),
            TextField(
              controller: category,
              decoration: const InputDecoration(labelText: '教科（例：数学）'),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              children: [
                for (final cat in categories)
                  ActionChip(
                    label: Text(cat),
                    onPressed: () => category.text = cat,
                  ),
              ],
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(c).pop(),
            child: const Text('キャンセル'),
          ),
          FilledButton(
            onPressed: () {
              if (name.text.trim().isEmpty || category.text.trim().isEmpty) {
                return;
              }
              Navigator.of(c).pop(
                Subject(name: name.text.trim(), category: category.text.trim()),
              );
            },
            child: const Text('保存'),
          ),
        ],
      ),
    );
  }

  Future<void> _delete(Subject s) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text('「${s.name}」を削除しますか？'),
        content: const Text('時間割に入っている場合、名前は残りますが色がグレーになります。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(c).pop(false),
            child: const Text('キャンセル'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(c).pop(true),
            child: const Text('削除'),
          ),
        ],
      ),
    );
    if (ok == true) await _repo.delete(s.name);
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<TimetableData>(
      stream: _stream,
      builder: (context, snap) {
        final subjects = snap.data?.subjects ?? const <Subject>[];
        final categories = <String>[];
        for (final s in subjects) {
          if (!categories.contains(s.category)) categories.add(s.category);
        }

        return Scaffold(
          appBar: AppBar(title: const Text('科目の管理')),
          floatingActionButton: FloatingActionButton.extended(
            icon: const Icon(Icons.add),
            label: const Text('追加'),
            onPressed: () async {
              final s = await _dialog(categories);
              if (s != null) await _repo.save(s, subjects.length);
            },
          ),
          body: !snap.hasData
              ? const Center(child: CircularProgressIndicator())
              : ListView(
                  padding: const EdgeInsets.only(bottom: 88),
                  children: [
                    ListTile(
                      leading: const Icon(Icons.school_outlined),
                      title: const Text('2・3年生の科目をまとめて追加'),
                      subtitle: const Text('すでにある科目は追加しません'),
                      trailing: FilledButton(
                        onPressed: () async {
                          final messenger = ScaffoldMessenger.of(context);
                          final n = await _repo.addUpperGrade(subjects);
                          messenger.showSnackBar(
                            SnackBar(content: Text('$n 科目を追加しました')),
                          );
                        },
                        child: const Text('追加'),
                      ),
                    ),
                    const Divider(),
                    for (final cat in categories) ...[
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                        child: Row(
                          children: [
                            CircleAvatar(
                              radius: 6,
                              backgroundColor: subjectColorOf(context, cat),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              cat,
                              style: Theme.of(context).textTheme.titleSmall,
                            ),
                          ],
                        ),
                      ),
                      for (var i = 0; i < subjects.length; i++)
                        if (subjects[i].category == cat)
                          ListTile(
                            dense: true,
                            title: Text(subjects[i].name),
                            onTap: () async {
                              final s = await _dialog(categories, subjects[i]);
                              if (s != null) await _repo.save(s, i);
                            },
                            trailing: IconButton(
                              icon: const Icon(Icons.delete_outline, size: 20),
                              tooltip: '削除',
                              onPressed: () => _delete(subjects[i]),
                            ),
                          ),
                    ],
                  ],
                ),
        );
      },
    );
  }
}
