import 'package:firebase_auth/firebase_auth.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/date_format.dart';
import '../timetable/timetable_models.dart';
import '../timetable/timetable_repository.dart';
import 'todo.dart';
import 'todo_repository.dart';

TodoRepository _repo() =>
    TodoRepository(uid: FirebaseAuth.instance.currentUser!.uid);

/// 期限の表示（例：9/25(金)・あと3日）
String dueText(DateTime due, DateTime today) {
  final d = DateTime.utc(
    due.year,
    due.month,
    due.day,
  ).difference(DateTime.utc(today.year, today.month, today.day)).inDays;
  final when = switch (d) {
    < 0 => '${-d}日過ぎています',
    0 => '今日まで',
    1 => '明日まで',
    _ => 'あと$d日',
  };
  return '${due.month}/${due.day}(${weekdayLabel(due.weekday)})・$when';
}

class TodoPage extends StatefulWidget {
  const TodoPage({super.key});

  @override
  State<TodoPage> createState() => _TodoPageState();
}

class _TodoPageState extends State<TodoPage> {
  late final _todos = _repo().watch();
  late final _timetable = TimetableRepository(
    uid: FirebaseAuth.instance.currentUser!.uid,
  ).watch();
  bool _showDone = false;
  List<Subject> _subjects = const [];

  void _edit([Todo? t]) {
    Navigator.of(context, rootNavigator: true).push(
      MaterialPageRoute<void>(
        fullscreenDialog: true,
        builder: (_) => TodoEditPage(todo: t, subjects: _subjects),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final now = DateTime.now();

    return Scaffold(
      appBar: AppBar(title: const Text('ToDo')),
      floatingActionButton: FloatingActionButton(
        tooltip: 'ToDo を追加',
        onPressed: _edit,
        child: const Icon(Icons.add),
      ),
      body: StreamBuilder<TimetableData>(
        stream: _timetable,
        builder: (context, ts) => StreamBuilder<List<Todo>>(
          stream: _todos,
          builder: (context, snap) {
            if (!ts.hasData || !snap.hasData) {
              return const Center(child: CircularProgressIndicator());
            }
            _subjects = ts.data!.subjects;
            final all = sortTodos(mergeTodos(snap.data!, ts.data!.schoolTests));
            final list = [
              for (final t in all)
                if (t.done == _showDone) t,
            ];

            return Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(8),
                  child: SegmentedButton<bool>(
                    segments: [
                      ButtonSegment(
                        value: false,
                        label: Text('未完了（${all.where((t) => !t.done).length}）'),
                      ),
                      const ButtonSegment(value: true, label: Text('完了')),
                    ],
                    selected: {_showDone},
                    showSelectedIcon: false,
                    onSelectionChanged: (s) =>
                        setState(() => _showDone = s.first),
                  ),
                ),
                Expanded(
                  child: list.isEmpty
                      ? Center(
                          child: Text(
                            _showDone ? '完了した ToDo はありません' : 'やることはありません',
                          ),
                        )
                      : ListView(
                          padding: const EdgeInsets.only(bottom: 88),
                          children: [
                            for (final t in list)
                              Dismissible(
                                key: ValueKey(t.id),
                                direction: t.isLinked
                                    ? DismissDirection.none
                                    : DismissDirection.horizontal,
                                background: Container(color: cs.errorContainer),
                                onDismissed: (_) => _repo().delete(t.id!),
                                child: ListTile(
                                  leading: Checkbox(
                                    value: t.done,
                                    onChanged: (v) => _repo().save(
                                      t.copyWith(done: v ?? false),
                                    ),
                                  ),
                                  title: Text(
                                    t.title,
                                    style: t.done
                                        ? TextStyle(
                                            decoration:
                                                TextDecoration.lineThrough,
                                            color: cs.outline,
                                          )
                                        : null,
                                  ),
                                  subtitle: Text(
                                    [
                                      if (t.dueDate != null)
                                        dueText(t.dueDate!, now),
                                      if (t.progressText != null)
                                        '✓ ${t.progressText}',
                                    ].join('　'),
                                    style: t.isOverdue(now)
                                        ? TextStyle(color: cs.error)
                                        : null,
                                  ),
                                  trailing: t.isLinked
                                      ? Icon(
                                          Icons.link,
                                          color: cs.outline,
                                          size: 18,
                                        )
                                      : null,
                                  onTap: () => _edit(t),
                                ),
                              ),
                          ],
                        ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

/// ToDo の追加・編集
class TodoEditPage extends StatefulWidget {
  const TodoEditPage({super.key, this.todo, required this.subjects});

  final Todo? todo;
  final List<Subject> subjects;

  @override
  State<TodoEditPage> createState() => _TodoEditPageState();
}

class _TodoEditPageState extends State<TodoEditPage> {
  late final Todo? _t = widget.todo;
  late final bool _linked = _t?.isLinked ?? false;
  late final _title = TextEditingController(text: _t?.title);
  late final _memo = TextEditingController(text: _t?.memo);
  final _newSub = TextEditingController();
  late DateTime? _due = _t?.dueDate;
  late String? _subject = _t?.subject;
  late final List<Subtask> _subs = [...?_t?.subtasks];
  String? _error;

  void _addSub() {
    final text = _newSub.text.trim();
    if (text.isEmpty) return;
    setState(() {
      _subs.add(Subtask(text));
      _newSub.clear();
    });
  }

  Future<void> _save() async {
    if (_title.text.trim().isEmpty) {
      return setState(() => _error = 'やることを入力してください');
    }
    final nav = Navigator.of(context);
    await _repo().save(
      Todo(
        id: _t?.id,
        title: _title.text,
        dueDate: _due,
        subject: _subject,
        memo: _memo.text,
        done: _t?.done ?? false,
        subtasks: _subs,
        linkedTestId: _t?.linkedTestId,
      ),
    );
    nav.pop();
  }

  Future<void> _delete() async {
    final nav = Navigator.of(context);
    await _repo().delete(_t!.id!);
    nav.pop();
  }

  @override
  Widget build(BuildContext context) {
    final names = [for (final s in widget.subjects) s.name];
    if (_subject != null && !names.contains(_subject)) names.add(_subject!);

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(_t == null ? 'ToDo を追加' : 'ToDo を編集'),
        actions: [
          if (_t != null && !_linked)
            IconButton(
              icon: const Icon(Icons.delete_outline),
              tooltip: '削除',
              onPressed: _delete,
            ),
          TextButton(onPressed: _save, child: const Text('保存')),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (_linked)
            const Padding(
              padding: EdgeInsets.only(bottom: 8),
              child: Text('🔗 提出物などから自動で作られた ToDo です（名前・期限はカレンダー側で変更）'),
            ),
          TextField(
            controller: _title,
            enabled: !_linked,
            autofocus: _t == null,
            decoration: const InputDecoration(labelText: 'やること'),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              const Text('期限'),
              const Spacer(),
              TextButton(
                onPressed: _linked
                    ? null
                    : () async {
                        final d = await showDatePicker(
                          context: context,
                          initialDate: _due ?? DateTime.now(),
                          firstDate: DateTime(2020),
                          lastDate: DateTime(2035, 12, 31),
                        );
                        if (d != null) setState(() => _due = d);
                      },
                child: Text(_due == null ? 'なし' : formatDateJa(_due!)),
              ),
              if (!_linked && _due != null)
                IconButton(
                  icon: const Icon(Icons.clear),
                  onPressed: () => setState(() => _due = null),
                ),
            ],
          ),
          Row(
            children: [
              const Text('科目'),
              const SizedBox(width: 16),
              Expanded(
                child: DropdownButton<String?>(
                  isExpanded: true,
                  value: _subject,
                  hint: const Text('なし'),
                  items: [
                    const DropdownMenuItem<String?>(
                      value: null,
                      child: Text('なし'),
                    ),
                    for (final n in names)
                      DropdownMenuItem<String?>(value: n, child: Text(n)),
                  ],
                  onChanged: _linked
                      ? null
                      : (v) => setState(() => _subject = v),
                ),
              ),
            ],
          ),
          const Divider(height: 32),
          const Text('チェック項目'),
          for (var i = 0; i < _subs.length; i++)
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              controlAffinity: ListTileControlAffinity.leading,
              value: _subs[i].done,
              title: Text(_subs[i].title),
              onChanged: (v) => setState(
                () => _subs[i] = Subtask(_subs[i].title, done: v ?? false),
              ),
              secondary: IconButton(
                icon: const Icon(Icons.close, size: 18),
                onPressed: () => setState(() => _subs.removeAt(i)),
              ),
            ),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _newSub,
                  decoration: const InputDecoration(hintText: '項目を追加（例：p.1〜5）'),
                  onSubmitted: (_) => _addSub(),
                ),
              ),
              IconButton(icon: const Icon(Icons.add), onPressed: _addSub),
            ],
          ),
          const Divider(height: 32),
          TextField(
            controller: _memo,
            minLines: 2,
            maxLines: 6,
            decoration: const InputDecoration(labelText: 'メモ'),
          ),
          if (_error != null) ...[
            const SizedBox(height: 16),
            Text(
              _error!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ],
        ],
      ),
    );
  }
}
