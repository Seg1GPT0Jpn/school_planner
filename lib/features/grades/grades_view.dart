import 'package:firebase_auth/firebase_auth.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/date_format.dart';
import '../timetable/timetable_repository.dart';
import 'grade.dart';
import 'grade_repository.dart';

GradeRepository _repo() =>
    GradeRepository(uid: FirebaseAuth.instance.currentUser!.uid);

/// 目標タブの「成績」
class GradesView extends StatefulWidget {
  const GradesView({super.key});

  @override
  State<GradesView> createState() => _GradesViewState();
}

class _GradesViewState extends State<GradesView> {
  late final _stream = _repo().watch();
  ExamKind _kind = ExamKind.regular;
  String? _subject;

  void _edit([Exam? e]) {
    Navigator.of(context, rootNavigator: true).push(
      MaterialPageRoute<void>(
        fullscreenDialog: true,
        builder: (_) => ExamEditPage(exam: e, kind: _kind),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return StreamBuilder<List<Exam>>(
      stream: _stream,
      builder: (context, snap) {
        final exams = [
          for (final e in snap.data ?? const <Exam>[])
            if (e.kind == _kind) e,
        ];
        final subjects = {
          for (final e in exams)
            for (final x in e.entries) x.subject,
        }.toList();
        final subject = subjects.contains(_subject)
            ? _subject
            : (subjects.isEmpty ? null : subjects.first);
        final history = subject == null
            ? const <(Exam, GradeEntry)>[]
            : subjectHistory(exams, subject);

        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
          children: [
            Row(
              children: [
                SegmentedButton<ExamKind>(
                  segments: [
                    for (final k in ExamKind.values)
                      ButtonSegment(value: k, label: Text(k.label)),
                  ],
                  selected: {_kind},
                  showSelectedIcon: false,
                  onSelectionChanged: (s) => setState(() => _kind = s.first),
                ),
                const Spacer(),
                FilledButton.icon(
                  onPressed: _edit,
                  icon: const Icon(Icons.add),
                  label: const Text('追加'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (exams.isEmpty)
              Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  '「追加」から記録しましょう',
                  style: TextStyle(color: cs.outline),
                ),
              ),
            for (final e in exams)
              Card(
                child: ListTile(
                  title: Text(e.title),
                  subtitle: Text(
                    [
                      formatDateJa(e.date),
                      '合計 ${numText(e.total)}/${numText(e.maxTotal)}',
                      if (e.averageTotal != null)
                        '（平均 ${numText(e.averageTotal!)}）',
                      if (e.totalRank != null) '総合 ${e.totalRank}位',
                    ].join('　'),
                  ),
                  onTap: () => _edit(e),
                ),
              ),

            if (subjects.isNotEmpty) ...[
              const SizedBox(height: 16),
              Row(
                children: [
                  Text(
                    '科目ごとの推移',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: DropdownButton<String>(
                      isExpanded: true,
                      value: subject,
                      items: [
                        for (final s in subjects)
                          DropdownMenuItem(value: s, child: Text(s)),
                      ],
                      onChanged: (v) => setState(() => _subject = v),
                    ),
                  ),
                ],
              ),
              for (final (ex, en) in history)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 110,
                        child: Text(
                          '${ex.date.month}/${ex.date.day} ${ex.title}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ),
                      Expanded(
                        child: Stack(
                          children: [
                            Container(
                              height: 16,
                              decoration: BoxDecoration(
                                color: cs.surfaceContainerHighest,
                                borderRadius: BorderRadius.circular(4),
                              ),
                            ),
                            FractionallySizedBox(
                              widthFactor: en.percent,
                              child: Container(
                                height: 16,
                                decoration: BoxDecoration(
                                  color: cs.primary,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                              ),
                            ),
                            // 平均点の位置に線
                            if (en.average != null && en.max > 0)
                              FractionallySizedBox(
                                widthFactor: (en.average! / en.max)
                                    .clamp(0, 1)
                                    .toDouble(),
                                child: Align(
                                  alignment: Alignment.centerRight,
                                  child: Container(
                                    width: 2,
                                    height: 16,
                                    color: cs.error,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                      SizedBox(
                        width: 84,
                        child: Text(
                          '${numText(en.score)}/${numText(en.max)}'
                          '${en.rank == null ? '' : ' ${en.rank}位'}',
                          textAlign: TextAlign.right,
                        ),
                      ),
                    ],
                  ),
                ),
              if (history.any((h) => h.$2.average != null))
                Text(
                  '赤い線：平均点',
                  style: TextStyle(color: cs.outline, fontSize: 11),
                ),
            ],
          ],
        );
      },
    );
  }
}

// ---------------- 追加・編集 ----------------

class _Row {
  _Row({
    this.subject,
    String score = '',
    String max = '100',
    String avg = '',
    String rank = '',
  }) : score = TextEditingController(text: score),
       max = TextEditingController(text: max),
       avg = TextEditingController(text: avg),
       rank = TextEditingController(text: rank);

  String? subject;
  final TextEditingController score, max, avg, rank;
}

class ExamEditPage extends StatefulWidget {
  const ExamEditPage({super.key, this.exam, required this.kind});

  final Exam? exam;
  final ExamKind kind;

  @override
  State<ExamEditPage> createState() => _ExamEditPageState();
}

class _ExamEditPageState extends State<ExamEditPage> {
  late final Exam? _e = widget.exam;
  late final _title = TextEditingController(text: _e?.title);
  late final _totalRank = TextEditingController(
    text: _e?.totalRank?.toString() ?? '',
  );
  late ExamKind _kind = _e?.kind ?? widget.kind;
  late DateTime _date = _e?.date ?? DateTime.now();
  late final List<_Row> _rows = [
    for (final x in _e?.entries ?? const <GradeEntry>[])
      _Row(
        subject: x.subject,
        score: numText(x.score),
        max: numText(x.max),
        avg: x.average == null ? '' : numText(x.average!),
        rank: x.rank?.toString() ?? '',
      ),
    if (_e == null) _Row(),
  ];
  late final _timetable = TimetableRepository(
    uid: FirebaseAuth.instance.currentUser!.uid,
  ).watch();
  String? _error;

  static const _presets = {
    ExamKind.regular: ['前期中間試験', '前期期末試験', '後期中間試験', '後期期末試験', '実力テスト', '模試'],
    ExamKind.quiz: ['LEAP単語テスト', 'EEVI', '漢字テスト', '単語テスト', '文法テスト'],
  };

  Future<void> _save() async {
    if (_title.text.trim().isEmpty) {
      return setState(() => _error = 'テスト名を入力してください');
    }
    final entries = [
      for (final r in _rows)
        if (r.subject != null && num.tryParse(r.score.text) != null)
          GradeEntry(
            subject: r.subject!,
            score: num.parse(r.score.text),
            max: num.tryParse(r.max.text) ?? 100,
            average: num.tryParse(r.avg.text),
            rank: int.tryParse(r.rank.text),
          ),
    ];
    final nav = Navigator.of(context);
    await _repo().save(
      Exam(
        id: _e?.id,
        title: _title.text,
        kind: _kind,
        date: _date,
        entries: entries,
        totalRank: int.tryParse(_totalRank.text),
      ),
    );
    nav.pop();
  }

  Future<void> _delete() async {
    final nav = Navigator.of(context);
    await _repo().delete(_e!.id!);
    nav.pop();
  }

  Widget _num(TextEditingController c, String label, double width) => SizedBox(
    width: width,
    child: TextField(
      controller: c,
      keyboardType: TextInputType.number,
      decoration: InputDecoration(labelText: label, isDense: true),
    ),
  );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(_e == null ? '成績を追加' : '成績を編集'),
        actions: [
          if (_e != null)
            IconButton(
              icon: const Icon(Icons.delete_outline),
              tooltip: '削除',
              onPressed: _delete,
            ),
          TextButton(onPressed: _save, child: const Text('保存')),
        ],
      ),
      body: StreamBuilder<TimetableData>(
        stream: _timetable,
        builder: (context, ts) {
          final data = ts.data;
          final allSubjects = [
            for (final s in data?.subjects ?? const []) s.name,
          ];
          final current = data == null
              ? <String>[]
              : {for (final s in data.slotsForDate(_date)) s.subject}.toList();

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              SegmentedButton<ExamKind>(
                segments: [
                  for (final k in ExamKind.values)
                    ButtonSegment(value: k, label: Text(k.label)),
                ],
                selected: {_kind},
                showSelectedIcon: false,
                onSelectionChanged: (s) => setState(() => _kind = s.first),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                children: [
                  for (final p in _presets[_kind]!)
                    ActionChip(
                      label: Text(p),
                      onPressed: () => setState(() => _title.text = p),
                    ),
                ],
              ),
              TextField(
                controller: _title,
                decoration: const InputDecoration(labelText: 'テスト名'),
              ),
              Row(
                children: [
                  const Text('日付'),
                  const Spacer(),
                  TextButton(
                    onPressed: () async {
                      final d = await showDatePicker(
                        context: context,
                        initialDate: _date,
                        firstDate: DateTime(2020),
                        lastDate: DateTime(2035, 12, 31),
                      );
                      if (d != null) setState(() => _date = d);
                    },
                    child: Text(formatDateJa(_date)),
                  ),
                ],
              ),
              _num(_totalRank, '総合順位（任意）', 160),
              const Divider(height: 32),

              for (var i = 0; i < _rows.length; i++)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: DropdownButton<String>(
                              isExpanded: true,
                              value: _rows[i].subject,
                              hint: const Text('科目'),
                              items: [
                                for (final n in {
                                  ...allSubjects,
                                  ?_rows[i].subject,
                                })
                                  DropdownMenuItem(value: n, child: Text(n)),
                              ],
                              onChanged: (v) =>
                                  setState(() => _rows[i].subject = v),
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.close, size: 18),
                            onPressed: () => setState(() => _rows.removeAt(i)),
                          ),
                        ],
                      ),
                      Row(
                        children: [
                          _num(_rows[i].score, '点数', 64),
                          const Text(' / '),
                          _num(_rows[i].max, '満点', 56),
                          const SizedBox(width: 12),
                          _num(_rows[i].avg, '平均点', 64),
                          const SizedBox(width: 12),
                          _num(_rows[i].rank, '順位', 56),
                        ],
                      ),
                    ],
                  ),
                ),

              Wrap(
                spacing: 8,
                children: [
                  OutlinedButton.icon(
                    onPressed: () => setState(() => _rows.add(_Row())),
                    icon: const Icon(Icons.add),
                    label: const Text('科目を追加'),
                  ),
                  if (_kind == ExamKind.regular)
                    OutlinedButton.icon(
                      onPressed: () => setState(() {
                        final have = {for (final r in _rows) r.subject};
                        _rows.removeWhere(
                          (r) => r.subject == null && r.score.text.isEmpty,
                        );
                        for (final s in current) {
                          if (!have.contains(s)) _rows.add(_Row(subject: s));
                        }
                      }),
                      icon: const Icon(Icons.playlist_add),
                      label: const Text('時間割の科目をまとめて入れる'),
                    ),
                ],
              ),
              if (_error != null) ...[
                const SizedBox(height: 16),
                Text(
                  _error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ],
            ],
          );
        },
      ),
    );
  }
}
