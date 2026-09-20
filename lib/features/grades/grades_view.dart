import 'package:firebase_auth/firebase_auth.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/date_format.dart';
import '../timetable/timetable_repository.dart';
import 'grade.dart';
import 'grade_chart.dart';
import 'grade_repository.dart';

GradeRepository _repo() =>
    GradeRepository(uid: FirebaseAuth.instance.currentUser!.uid);

/// 「12位」「12位/240人」
String rankText(int rank, [int? participants]) =>
    participants == null ? '$rank位' : '$rank位/$participants人';

/// 目標タブの「成績」
class GradesView extends StatefulWidget {
  const GradesView({super.key});

  @override
  State<GradesView> createState() => _GradesViewState();
}

class _GradesViewState extends State<GradesView> {
  late final _stream = _repo().watch();
  late final _targets = _repo().watchTargets();
  ExamKind _kind = ExamKind.regular;
  GradeMetric _metric = GradeMetric.score;
  String? _subject;

  void _edit([Exam? e]) {
    Navigator.of(context, rootNavigator: true).push(
      MaterialPageRoute<void>(
        fullscreenDialog: true,
        builder: (_) => ExamEditPage(exam: e, kind: _kind),
      ),
    );
  }

  Future<void> _editTarget(
    Map<String, GradeTarget> targets,
    String subject,
  ) async {
    final key = targetKey(_kind, subject);
    final current = targets[key] ?? const GradeTarget();
    final now = current.valueFor(_metric);
    final c = TextEditingController(text: now == null ? '' : numText(now));
    final unit = switch (_metric) {
      GradeMetric.score => '点（100点満点で）',
      GradeMetric.deviation => '',
      GradeMetric.rank => '位',
    };

    // null = キャンセル、'' = 消す
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('$subject の目標${_metric.label}'),
        content: TextField(
          controller: c,
          autofocus: true,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: InputDecoration(
            labelText: '目標${_metric.label}',
            suffixText: unit,
            helperText: '例：志望校の目安の偏差値など',
          ),
        ),
        actions: [
          if (now != null)
            TextButton(
              onPressed: () => Navigator.pop(ctx, ''),
              child: const Text('消す'),
            ),
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('キャンセル'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, c.text.trim()),
            child: const Text('保存'),
          ),
        ],
      ),
    );
    if (result == null) return;
    final value = result.isEmpty ? null : num.tryParse(result);
    if (result.isNotEmpty && value == null) return;
    await _repo().saveTarget(targets, key, current.withValue(_metric, value));
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final small = TextStyle(color: cs.outline, fontSize: 11);

    return StreamBuilder<Map<String, GradeTarget>>(
      stream: _targets,
      builder: (context, tsnap) {
        final targets = tsnap.data ?? const <String, GradeTarget>{};
        return StreamBuilder<List<Exam>>(
          stream: _stream,
          builder: (context, snap) {
            final exams = [
              for (final e in snap.data ?? const <Exam>[])
                if (e.kind == _kind) e,
            ];
            final subjects = [
              if (exams.isNotEmpty) totalSubject,
              ...{
                for (final e in exams)
                  for (final x in e.entries) x.subject,
              },
            ];
            final subject = subjects.contains(_subject)
                ? _subject
                : (subjects.isEmpty ? null : subjects.first);
            final points = subject == null
                ? const <ChartPoint>[]
                : chartSeries(exams, subject, _metric);
            final target = subject == null
                ? null
                : targets[targetKey(_kind, subject)]?.valueFor(_metric);

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
                      onSelectionChanged: (s) =>
                          setState(() => _kind = s.first),
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

                // ---------- 推移のグラフ ----------
                if (subject != null) ...[
                  Row(
                    children: [
                      Text(
                        '推移',
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
                  Wrap(
                    alignment: WrapAlignment.spaceBetween,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      SegmentedButton<GradeMetric>(
                        segments: [
                          for (final m in GradeMetric.values)
                            ButtonSegment(value: m, label: Text(m.label)),
                        ],
                        selected: {_metric},
                        showSelectedIcon: false,
                        onSelectionChanged: (s) =>
                            setState(() => _metric = s.first),
                      ),
                      TextButton.icon(
                        onPressed: () => _editTarget(targets, subject),
                        icon: const Icon(Icons.flag_outlined, size: 18),
                        label: Text(
                          target == null ? '目標ライン' : '目標 ${numText(target)}',
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  if (points.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 24),
                      child: Text(
                        '$subject の${_metric.label}はまだ記録がありません',
                        style: TextStyle(color: cs.outline),
                      ),
                    )
                  else
                    GradeLineChart(
                      points: points,
                      metric: _metric,
                      target: target,
                    ),
                  Wrap(
                    spacing: 12,
                    children: [
                      Text('━ 自分', style: small.copyWith(color: cs.primary)),
                      if (points.any((p) => p.average != null))
                        Text('┅ 平均', style: small),
                      if (target != null)
                        Text('┅ 目標', style: small.copyWith(color: cs.error)),
                      if (_metric == GradeMetric.score)
                        Text('※ 100点満点に換算', style: small),
                    ],
                  ),
                  const SizedBox(height: 16),
                ],

                // ---------- テストの一覧 ----------
                for (final e in exams)
                  Card(
                    child: ListTile(
                      title: Text(e.title),
                      subtitle: Text(
                        [
                          formatDateJa(e.date),
                          if (e.entries.isNotEmpty)
                            '合計 ${numText(e.total)}/${numText(e.maxTotal)}',
                          if (e.averageTotal != null)
                            '（平均 ${numText(e.averageTotal!)}）',
                          if (e.totalDeviation != null)
                            '偏差値 ${numText(e.totalDeviation!)}',
                          if (e.totalRank != null)
                            '総合 ${rankText(e.totalRank!, e.participants)}',
                        ].join('　'),
                      ),
                      onTap: () => _edit(e),
                    ),
                  ),
              ],
            );
          },
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
    String dev = '',
  }) : score = TextEditingController(text: score),
       max = TextEditingController(text: max),
       avg = TextEditingController(text: avg),
       rank = TextEditingController(text: rank),
       dev = TextEditingController(text: dev);

  String? subject;
  final TextEditingController score, max, avg, rank, dev;
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
  late final _participants = TextEditingController(
    text: _e?.participants?.toString() ?? '',
  );
  late final _totalDev = TextEditingController(
    text: _e?.totalDeviation == null ? '' : numText(_e!.totalDeviation!),
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
        dev: x.deviation == null ? '' : numText(x.deviation!),
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
            deviation: num.tryParse(r.dev.text),
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
        totalDeviation: num.tryParse(_totalDev.text),
        participants: int.tryParse(_participants.text),
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
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
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
              Wrap(
                spacing: 12,
                runSpacing: 8,
                children: [
                  _num(_totalRank, '総合順位', 90),
                  _num(_participants, '受験者数', 90),
                  _num(_totalDev, '総合偏差値', 100),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                'どれも分かるものだけでOK',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.outline,
                  fontSize: 11,
                ),
              ),
              const Divider(height: 32),

              for (var i = 0; i < _rows.length; i++)
                Padding(
                  padding: const EdgeInsets.only(bottom: 16),
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
                      Wrap(
                        spacing: 12,
                        runSpacing: 8,
                        crossAxisAlignment: WrapCrossAlignment.end,
                        children: [
                          _num(_rows[i].score, '点数', 60),
                          _num(_rows[i].max, '満点', 56),
                          _num(_rows[i].avg, '平均点', 60),
                          _num(_rows[i].dev, '偏差値', 60),
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
