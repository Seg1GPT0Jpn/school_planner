/// テスト目標（定期テスト・模試ぜんたいの目標）の追加・編集
library;

import 'package:firebase_auth/firebase_auth.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/date_format.dart';
import '../timetable/timetable_repository.dart';
import 'exam_goal.dart';
import 'exam_goal_repository.dart';
import 'goal.dart' show Milestone;

String _n(num v) => v == v.roundToDouble() ? '${v.toInt()}' : '$v';

void openExamGoal(BuildContext context, [ExamGoal? g]) {
  Navigator.of(context, rootNavigator: true).push(
    MaterialPageRoute<void>(
      fullscreenDialog: true,
      builder: (_) => ExamGoalEditPage(goal: g),
    ),
  );
}

/// 1教科ぶんの入力欄（コントローラーをまとめて持つ）
class _SubjectRow {
  _SubjectRow({
    String subject = '',
    num? targetScore,
    num? currentScore,
    List<Milestone> materials = const [],
  }) : subjectController = TextEditingController(text: subject),
       targetController = TextEditingController(
         text: targetScore == null ? '' : _n(targetScore),
       ),
       currentController = TextEditingController(
         text: currentScore == null ? '' : _n(currentScore),
       ),
       materials = [...materials];

  final TextEditingController subjectController;
  final TextEditingController targetController;
  final TextEditingController currentController;
  final TextEditingController newMaterialController = TextEditingController();
  List<Milestone> materials;

  void dispose() {
    subjectController.dispose();
    targetController.dispose();
    currentController.dispose();
    newMaterialController.dispose();
  }

  ExamSubjectGoal toGoal() => ExamSubjectGoal(
    subject: subjectController.text.trim(),
    targetScore: num.tryParse(targetController.text.trim()),
    currentScore: num.tryParse(currentController.text.trim()),
    materials: materials,
  );
}

class ExamGoalEditPage extends StatefulWidget {
  const ExamGoalEditPage({super.key, this.goal});
  final ExamGoal? goal;

  @override
  State<ExamGoalEditPage> createState() => _ExamGoalEditPageState();
}

class _ExamGoalEditPageState extends State<ExamGoalEditPage> {
  late final ExamGoal? _g = widget.goal;
  late final _title = TextEditingController(text: _g?.title);
  late final _memo = TextEditingController(text: _g?.memo);
  late ExamGoalKind _kind = _g?.kind ?? ExamGoalKind.regularExam;
  late DateTime? _examDate = _g?.examDate;
  late DateTime? _examEndDate = _g?.examEndDate;
  late final List<_SubjectRow> _rows = (_g == null || _g.subjects.isEmpty)
      ? [_SubjectRow()]
      : [
          for (final s in _g.subjects)
            _SubjectRow(
              subject: s.subject,
              targetScore: s.targetScore,
              currentScore: s.currentScore,
              materials: s.materials,
            ),
        ];
  late final _subjectsStream = TimetableRepository(
    uid: FirebaseAuth.instance.currentUser!.uid,
  ).watch();
  String? _error;

  @override
  void dispose() {
    for (final r in _rows) {
      r.dispose();
    }
    _title.dispose();
    _memo.dispose();
    super.dispose();
  }

  void _addRow() => setState(() => _rows.add(_SubjectRow()));

  void _removeRow(int i) => setState(() {
    _rows[i].dispose();
    _rows.removeAt(i);
  });

  void _addMaterial(int i) {
    final text = _rows[i].newMaterialController.text.trim();
    if (text.isEmpty) return;
    setState(() {
      _rows[i].materials = [..._rows[i].materials, Milestone(text)];
      _rows[i].newMaterialController.clear();
    });
  }

  void _removeMaterial(int i, int mi) => setState(() {
    _rows[i].materials = [
      for (var j = 0; j < _rows[i].materials.length; j++)
        if (j != mi) _rows[i].materials[j],
    ];
  });

  void _toggleMaterial(int i, int mi, bool value) => setState(() {
    _rows[i].materials = [
      for (var j = 0; j < _rows[i].materials.length; j++)
        if (j == mi)
          Milestone(_rows[i].materials[j].title, done: value)
        else
          _rows[i].materials[j],
    ];
  });

  Future<void> _save() async {
    if (_title.text.trim().isEmpty) {
      return setState(() => _error = 'テスト名を入力してください');
    }
    final subjects = [
      for (final r in _rows)
        if (r.subjectController.text.trim().isNotEmpty) r.toGoal(),
    ];
    if (subjects.isEmpty) {
      return setState(() => _error = '教科を1つ以上入力してください');
    }
    final nav = Navigator.of(context);
    final repo = ExamGoalRepository(uid: FirebaseAuth.instance.currentUser!.uid);
    await repo.save(
      ExamGoal(
        id: _g?.id,
        title: _title.text,
        kind: _kind,
        examDate: _examDate,
        examEndDate: _examEndDate,
        subjects: subjects,
        memo: _memo.text,
      ),
    );
    nav.pop();
  }

  Future<void> _delete() async {
    final nav = Navigator.of(context);
    await ExamGoalRepository(
      uid: FirebaseAuth.instance.currentUser!.uid,
    ).delete(_g!.id!);
    nav.pop();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(_g == null ? 'テスト目標を追加' : 'テスト目標を編集'),
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
              labelText: 'テスト名（例：後期期末試験、第2回全統模試）',
            ),
          ),
          const SizedBox(height: 12),
          SegmentedButton<ExamGoalKind>(
            segments: [
              for (final k in ExamGoalKind.values)
                ButtonSegment(value: k, label: Text(k.label)),
            ],
            selected: {_kind},
            showSelectedIcon: false,
            onSelectionChanged: (s) => setState(() => _kind = s.first),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              const Text('実施日'),
              const Spacer(),
              TextButton(
                onPressed: () async {
                  final d = await showDatePicker(
                    context: context,
                    initialDate: _examDate ?? DateTime.now(),
                    firstDate: DateTime(2020),
                    lastDate: DateTime(2035, 12, 31),
                  );
                  if (d != null) setState(() => _examDate = d);
                },
                child: Text(_examDate == null ? 'なし' : formatDateJa(_examDate!)),
              ),
              if (_examDate != null)
                IconButton(
                  icon: const Icon(Icons.clear),
                  onPressed: () => setState(() {
                    _examDate = null;
                    _examEndDate = null;
                  }),
                ),
            ],
          ),
          if (_examDate != null)
            Row(
              children: [
                const Text('最終日（複数日にわたるときだけ）'),
                const Spacer(),
                TextButton(
                  onPressed: () async {
                    final d = await showDatePicker(
                      context: context,
                      initialDate: _examEndDate ?? _examDate!,
                      firstDate: _examDate!,
                      lastDate: DateTime(2035, 12, 31),
                    );
                    if (d != null) setState(() => _examEndDate = d);
                  },
                  child: Text(
                    _examEndDate == null ? 'なし（1日だけ）' : formatDateJa(_examEndDate!),
                  ),
                ),
                if (_examEndDate != null)
                  IconButton(
                    icon: const Icon(Icons.clear),
                    onPressed: () => setState(() => _examEndDate = null),
                  ),
              ],
            ),
          const Divider(height: 32),
          Row(
            children: [
              Text('教科ごとの目標', style: Theme.of(context).textTheme.titleSmall),
              const Spacer(),
              TextButton.icon(
                onPressed: _addRow,
                icon: const Icon(Icons.add),
                label: const Text('教科を追加'),
              ),
            ],
          ),
          StreamBuilder<TimetableData>(
            stream: _subjectsStream,
            builder: (context, snap) {
              final names = [...?snap.data?.subjects.map((s) => s.name)];
              return Column(
                children: [
                  for (var i = 0; i < _rows.length; i++)
                    _SubjectCard(
                      row: _rows[i],
                      subjectNames: names,
                      onRemove: _rows.length <= 1 ? null : () => _removeRow(i),
                      onAddMaterial: () => _addMaterial(i),
                      onRemoveMaterial: (mi) => _removeMaterial(i, mi),
                      onToggleMaterial: (mi, v) => _toggleMaterial(i, mi, v),
                    ),
                ],
              );
            },
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

/// 1教科ぶんの入力カード
class _SubjectCard extends StatelessWidget {
  const _SubjectCard({
    required this.row,
    required this.subjectNames,
    required this.onRemove,
    required this.onAddMaterial,
    required this.onRemoveMaterial,
    required this.onToggleMaterial,
  });

  final _SubjectRow row;
  final List<String> subjectNames;
  final VoidCallback? onRemove;
  final VoidCallback onAddMaterial;
  final void Function(int) onRemoveMaterial;
  final void Function(int, bool) onToggleMaterial;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 6),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: row.subjectController,
                    decoration: const InputDecoration(labelText: '教科'),
                  ),
                ),
                if (onRemove != null)
                  IconButton(
                    icon: const Icon(Icons.close),
                    tooltip: 'この教科を削除',
                    onPressed: onRemove,
                  ),
              ],
            ),
            if (subjectNames.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 4, bottom: 4),
                child: Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  children: [
                    for (final n in subjectNames)
                      ActionChip(
                        label: Text(n),
                        onPressed: () => row.subjectController.text = n,
                      ),
                  ],
                ),
              ),
            const SizedBox(height: 4),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: row.targetController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: '目標点数'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: row.currentController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: '実際の点数（あとで）'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'やること（ワーク・単語帳など）',
                style: Theme.of(context).textTheme.labelMedium,
              ),
            ),
            for (var i = 0; i < row.materials.length; i++)
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                controlAffinity: ListTileControlAffinity.leading,
                value: row.materials[i].done,
                title: Text(row.materials[i].title),
                onChanged: (v) => onToggleMaterial(i, v ?? false),
                secondary: IconButton(
                  icon: const Icon(Icons.close, size: 18),
                  onPressed: () => onRemoveMaterial(i),
                ),
              ),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: row.newMaterialController,
                    decoration: const InputDecoration(
                      hintText: '例：4STEP p.20〜35、LEAP 1〜200',
                    ),
                    onSubmitted: (_) => onAddMaterial(),
                  ),
                ),
                IconButton(icon: const Icon(Icons.add), onPressed: onAddMaterial),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
