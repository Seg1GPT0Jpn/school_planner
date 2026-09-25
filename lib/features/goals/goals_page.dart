import 'package:firebase_auth/firebase_auth.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/date_format.dart';
import '../timetable/timetable_repository.dart';
import '../grades/grades_view.dart';
import '../study/study_view.dart';
import '../grades/last_grade_hint.dart';
import '../review/review_page.dart';
import 'exam_goal.dart';
import 'exam_goal_edit_page.dart';
import 'exam_goal_repository.dart';
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
  /// 0：目標　1：テスト目標　2：ふり返り　3：勉強時間　4：成績
  int _view = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('目標'),
        actions: [
          IconButton(
            icon: const Icon(Icons.insights),
            tooltip: 'ふり返りレビュー（週・月・学期）',
            onPressed: () => openReview(context),
          ),
        ],
      ),
      floatingActionButton: switch (_view) {
        0 => FloatingActionButton(
          tooltip: '目標を追加',
          onPressed: () => _openGoal(context),
          child: const Icon(Icons.add),
        ),
        1 => FloatingActionButton(
          tooltip: 'テスト目標を追加',
          onPressed: () => openExamGoal(context),
          child: const Icon(Icons.add),
        ),
        _ => null,
      },
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(8),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: SegmentedButton<int>(
                segments: const [
                  ButtonSegment(value: 0, label: Text('目標')),
                  ButtonSegment(value: 1, label: Text('テスト目標')),
                  ButtonSegment(value: 2, label: Text('ふり返り')),
                  ButtonSegment(value: 3, label: Text('勉強時間')),
                  ButtonSegment(value: 4, label: Text('成績')),
                ],
                selected: {_view},
                showSelectedIcon: false,
                onSelectionChanged: (s) => setState(() => _view = s.first),
              ),
            ),
          ),
          Expanded(
            child: switch (_view) {
              1 => const _ExamGoalList(),
              2 => const _ReflectionView(),
              3 => const StudyView(),
              4 => const GradesView(),
              _ => const _GoalList(),
            },
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

// ---------------- テスト目標（定期テスト・模試）の一覧 ----------------

String _num(num v) => v == v.roundToDouble() ? '${v.toInt()}' : '$v';

class _ExamGoalList extends StatefulWidget {
  const _ExamGoalList();

  @override
  State<_ExamGoalList> createState() => _ExamGoalListState();
}

class _ExamGoalListState extends State<_ExamGoalList> {
  late final _stream = ExamGoalRepository(
    uid: FirebaseAuth.instance.currentUser!.uid,
  ).watch();

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<ExamGoal>>(
      stream: _stream,
      builder: (context, snap) {
        if (!snap.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final all = sortExamGoals(snap.data!);
        if (all.isEmpty) {
          return const Center(child: Text('右下の＋から、定期テスト・模試の目標を追加しましょう'));
        }
        return ListView(
          padding: const EdgeInsets.only(bottom: 88),
          children: [for (final g in all) _ExamGoalTile(goal: g)],
        );
      },
    );
  }
}

class _ExamGoalTile extends StatelessWidget {
  const _ExamGoalTile({required this.goal});
  final ExamGoal goal;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final g = goal;
    final materialsTotal = [for (final s in g.subjects) ...s.materials].length;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: InkWell(
        onTap: () => openExamGoal(context, g),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      '【${g.kind.label}】${g.title}',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ),
                  if (g.examDate != null)
                    Text(
                      _daysLeft(g.examDate!),
                      style: Theme.of(context).textTheme.bodySmall
                          ?.copyWith(color: cs.outline),
                    ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                '${g.subjectCount}教科'
                '${g.totalTargetScore > 0 ? '・目標合計${_num(g.totalTargetScore)}点' : ''}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              if (g.scoredSubjectCount > 0)
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Text(
                    '結果：${g.achievedSubjectCount}/${g.scoredSubjectCount}教科で目標達成'
                    '${g.allScoresIn ? '・合計${_num(g.totalCurrentScore)}点' : ''}',
                  ),
                ),
              if (materialsTotal > 0) ...[
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: LinearProgressIndicator(
                        value: g.materialsProgress,
                        minHeight: 8,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Text('やること'),
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
  late DateTime _start = _g?.startDate ?? DateTime.now();
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
    await _repo().saveGoalAndRecompute(
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
        startDate: _type == GoalProgressType.studyTime ? _start : null,
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
          if (_subject != null) LastGradeHint(subject: _subject!),
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
          if (_type == GoalProgressType.studyTime) ...[
            TextField(
              controller: _target,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: '目標（時間）'),
            ),
            Row(
              children: [
                const Text('数え始める日'),
                const Spacer(),
                TextButton(
                  onPressed: () async {
                    final d = await showDatePicker(
                      context: context,
                      initialDate: _start,
                      firstDate: DateTime(2020),
                      lastDate: DateTime(2035, 12, 31),
                    );
                    if (d != null) setState(() => _start = d);
                  },
                  child: Text(formatDateJa(_start)),
                ),
              ],
            ),
            Text(
              '科目が「なし」ならすべての科目の合計。期限の日までの記録を数えます。',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
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
