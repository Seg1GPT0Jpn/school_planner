import 'package:firebase_auth/firebase_auth.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/date_format.dart';
import '../timetable/timetable_repository.dart';
import 'goal.dart';
import 'goal_repository.dart';

GoalRepository _repo() =>
    GoalRepository(uid: FirebaseAuth.instance.currentUser!.uid);

String _daysLeft(DateTime due) {
  final now = DateTime.now();
  final d = DateTime.utc(
    due.year,
    due.month,
    due.day,
  ).difference(DateTime.utc(now.year, now.month, now.day)).inDays;
  return d < 0 ? '${-d}日過ぎています' : (d == 0 ? '今日まで' : 'あと$d日');
}

class GoalsPage extends StatefulWidget {
  const GoalsPage({super.key});

  @override
  State<GoalsPage> createState() => _GoalsPageState();
}

class _GoalsPageState extends State<GoalsPage> {
  bool _reflection = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('目標')),
      floatingActionButton: _reflection
          ? null
          : FloatingActionButton(
              tooltip: '目標を追加',
              onPressed: () => _openGoal(context),
              child: const Icon(Icons.add),
            ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(8),
            child: SegmentedButton<bool>(
              segments: const [
                ButtonSegment(value: false, label: Text('目標')),
                ButtonSegment(value: true, label: Text('ふり返り')),
              ],
              selected: {_reflection},
              showSelectedIcon: false,
              onSelectionChanged: (s) => setState(() => _reflection = s.first),
            ),
          ),
          Expanded(
            child: _reflection ? const _ReflectionView() : const _GoalList(),
          ),
        ],
      ),
    );
  }
}

void _openGoal(BuildContext context, [Goal? g]) {
  Navigator.of(context, rootNavigator: true).push(
    MaterialPageRoute<void>(
      fullscreenDialog: true,
      builder: (_) => GoalEditPage(goal: g),
    ),
  );
}

// ---------------- 目標の一覧 ----------------

class _GoalList extends StatefulWidget {
  const _GoalList();

  @override
  State<_GoalList> createState() => _GoalListState();
}

class _GoalListState extends State<_GoalList> {
  late final _stream = _repo().watchGoals();

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Goal>>(
      stream: _stream,
      builder: (context, snap) {
        if (!snap.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final all = sortGoals(snap.data!);
        final sections = {
          '短期': [
            for (final g in all)
              if (!g.achieved && g.term == GoalTerm.short) g,
          ],
          '長期': [
            for (final g in all)
              if (!g.achieved && g.term == GoalTerm.long) g,
          ],
          '達成済み': [
            for (final g in all)
              if (g.achieved) g,
          ],
        };
        if (all.isEmpty) {
          return const Center(child: Text('右下の＋から目標を追加しましょう'));
        }
        return ListView(
          padding: const EdgeInsets.only(bottom: 88),
          children: [
            for (final e in sections.entries)
              if (e.value.isNotEmpty) ...[
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                  child: Text(
                    e.key,
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                ),
                for (final g in e.value) _GoalTile(goal: g),
              ],
          ],
        );
      },
    );
  }
}

class _GoalTile extends StatelessWidget {
  const _GoalTile({required this.goal});
  final Goal goal;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final g = goal;
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: InkWell(
        onTap: () => _openGoal(context, g),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      g.subject == null ? g.title : '【${g.subject}】${g.title}',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ),
                  if (g.dueDate != null)
                    Text(
                      _daysLeft(g.dueDate!),
                      style: Theme.of(context).textTheme.bodySmall
                          ?.copyWith(color: cs.outline),
                    ),
                ],
              ),
              if (g.type != GoalProgressType.none) ...[
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: LinearProgressIndicator(
                        value: g.progress,
                        minHeight: 8,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(g.progressText),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------- 目標の追加・編集 ----------------

class GoalEditPage extends StatefulWidget {
  const GoalEditPage({super.key, this.goal});
  final Goal? goal;

  @override
  State<GoalEditPage> createState() => _GoalEditPageState();
}

class _GoalEditPageState extends State<GoalEditPage> {
  late final Goal? _g = widget.goal;
  late final _title = TextEditingController(text: _g?.title);
  late final _current = TextEditingController(text: '${_g?.current ?? 0}');
  late final _target = TextEditingController(text: '${_g?.target ?? 100}');
  late final _unit = TextEditingController(text: _g?.unit);
  late final _memo = TextEditingController(text: _g?.memo);
  final _newMs = TextEditingController();
  late GoalTerm _term = _g?.term ?? GoalTerm.short;
  late GoalProgressType _type = _g?.type ?? GoalProgressType.number;
  late DateTime? _due = _g?.dueDate;
  late bool _achieved = _g?.achieved ?? false;
  late String? _subject = _g?.subject;
  late final _subjects = TimetableRepository(
    uid: FirebaseAuth.instance.currentUser!.uid,
  ).watch();
  late final List<Milestone> _ms = [...?_g?.milestones];
  String? _error;

  Future<void> _save() async {
    if (_title.text.trim().isEmpty) {
      return setState(() => _error = '目標を入力してください');
    }
    final nav = Navigator.of(context);
    await _repo().saveGoal(
      Goal(
        id: _g?.id,
        title: _title.text,
        term: _term,
        dueDate: _due,
        type: _type,
        current: num.tryParse(_current.text) ?? 0,
        target: num.tryParse(_target.text) ?? 100,
        unit: _unit.text.trim(),
        milestones: _ms,
        achieved: _achieved,
        subject: _subject,
        memo: _memo.text,
      ),
    );
    nav.pop();
  }

  Future<void> _delete() async {
    final nav = Navigator.of(context);
    await _repo().deleteGoal(_g!.id!);
    nav.pop();
  }

  void _addMs() {
    final t = _newMs.text.trim();
    if (t.isEmpty) return;
    setState(() {
      _ms.add(Milestone(t));
      _newMs.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(_g == null ? '目標を追加' : '目標を編集'),
        actions: [
          if (_g != null)
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
          TextField(
            controller: _title,
            autofocus: _g == null,
            decoration: const InputDecoration(
              labelText: '目標（例：LEAP 2000 まで覚える）',
            ),
          ),
          const SizedBox(height: 12),
          SegmentedButton<GoalTerm>(
            segments: [
              for (final t in GoalTerm.values)
                ButtonSegment(value: t, label: Text(t.label)),
            ],
            selected: {_term},
            showSelectedIcon: false,
            onSelectionChanged: (s) => setState(() => _term = s.first),
          ),
          Row(
            children: [
              const Text('期限'),
              const Spacer(),
              TextButton(
                onPressed: () async {
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
              if (_due != null)
                IconButton(
                  icon: const Icon(Icons.clear),
                  onPressed: () => setState(() => _due = null),
                ),
            ],
          ),
          const Divider(height: 24),
          StreamBuilder<TimetableData>(
            stream: _subjects,
            builder: (context, snap) {
              final names = [...?snap.data?.subjects.map((s) => s.name)];
              if (_subject != null && !names.contains(_subject)) {
                names.add(_subject!);
              }
              return Row(
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
                      onChanged: (v) => setState(() => _subject = v),
                    ),
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 8),
          const Text('進み具合'),
          const SizedBox(height: 8),
          SegmentedButton<GoalProgressType>(
            segments: [
              for (final t in GoalProgressType.values)
                ButtonSegment(value: t, label: Text(t.label)),
            ],
            selected: {_type},
            showSelectedIcon: false,
            onSelectionChanged: (s) => setState(() => _type = s.first),
          ),
          const SizedBox(height: 8),
          if (_type == GoalProgressType.number)
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _current,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: '今'),
                  ),
                ),
                const Text('  /  '),
                Expanded(
                  child: TextField(
                    controller: _target,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: '目標'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: _unit,
                    decoration: const InputDecoration(labelText: '単位（語・点など）'),
                  ),
                ),
              ],
            ),
          if (_type == GoalProgressType.checklist) ...[
            for (var i = 0; i < _ms.length; i++)
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                controlAffinity: ListTileControlAffinity.leading,
                value: _ms[i].done,
                title: Text(_ms[i].title),
                onChanged: (v) => setState(
                  () => _ms[i] = Milestone(_ms[i].title, done: v ?? false),
                ),
                secondary: IconButton(
                  icon: const Icon(Icons.close, size: 18),
                  onPressed: () => setState(() => _ms.removeAt(i)),
                ),
              ),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _newMs,
                    decoration: const InputDecoration(hintText: '小さな目標を追加'),
                    onSubmitted: (_) => _addMs(),
                  ),
                ),
                IconButton(icon: const Icon(Icons.add), onPressed: _addMs),
              ],
            ),
          ],
          const Divider(height: 24),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('達成した！'),
            value: _achieved,
            onChanged: (v) => setState(() => _achieved = v),
          ),
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

// ---------------- ふり返り ----------------

class _ReflectionView extends StatefulWidget {
  const _ReflectionView();

  @override
  State<_ReflectionView> createState() => _ReflectionViewState();
}

class _ReflectionViewState extends State<_ReflectionView> {
  late final _stream = _repo().watchReflections();
  final _text = TextEditingController();
  DateTime _date = DateTime.now();
  List<Reflection> _all = const [];

  /// 選んだ日のふり返りを入力欄に出す
  void _load(DateTime d) {
    _date = d;
    String text = '';
    for (final r in _all) {
      if (r.date.year == d.year &&
          r.date.month == d.month &&
          r.date.day == d.day) {
        text = r.text;
      }
    }
    _text.text = text;
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Reflection>>(
      stream: _stream,
      builder: (context, snap) {
        final firstLoad = _all.isEmpty && (snap.data?.isNotEmpty ?? false);
        _all = snap.data ?? const [];
        if (firstLoad) {
          WidgetsBinding.instance.addPostFrameCallback((_) => _load(_date));
        }

        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Row(
              children: [
                TextButton.icon(
                  icon: const Icon(Icons.edit_calendar),
                  label: Text(formatDateJa(_date)),
                  onPressed: () async {
                    final d = await showDatePicker(
                      context: context,
                      initialDate: _date,
                      firstDate: DateTime(2020),
                      lastDate: DateTime(2035, 12, 31),
                    );
                    if (d != null) _load(d);
                  },
                ),
                const Spacer(),
                FilledButton(
                  onPressed: () async {
                    final messenger = ScaffoldMessenger.of(context);
                    await _repo().saveReflection(_date, _text.text);
                    messenger.showSnackBar(
                      const SnackBar(content: Text('保存しました')),
                    );
                  },
                  child: const Text('保存'),
                ),
              ],
            ),
            TextField(
              controller: _text,
              minLines: 4,
              maxLines: 12,
              decoration: const InputDecoration(
                hintText: '今日やったこと・気づき・明日やりたいこと',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            for (final r in _all)
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(formatDateJa(r.date)),
                subtitle: Text(
                  r.text,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                onTap: () => _load(r.date),
              ),
          ],
        );
      },
    );
  }
}
