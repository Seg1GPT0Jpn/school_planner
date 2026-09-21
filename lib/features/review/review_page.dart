/// 週・月・学期のレビュー
library;

import 'package:firebase_auth/firebase_auth.dart';
import 'package:material_ui/material_ui.dart';

import '../recurring/recurring_test_rule.dart';
import '../school_tests/upcoming_tests.dart';
import '../settings/settings_scope.dart';
import '../study/study.dart';
import 'period.dart';
import 'review_repository.dart';
import 'review_summary.dart';
import 'review_widgets.dart';
import 'test_karte_page.dart';
import 'tsuzuri_data.dart';

const _wd = ['月', '火', '水', '木', '金', '土', '日'];

/// レビューを開く
void openReview(BuildContext context, {ReviewKind kind = ReviewKind.week}) {
  Navigator.of(
    context,
    rootNavigator: true,
  ).push(MaterialPageRoute<void>(builder: (_) => ReviewPage(kind: kind)));
}

class ReviewPage extends StatefulWidget {
  const ReviewPage({super.key, this.kind = ReviewKind.week});

  final ReviewKind kind;

  @override
  State<ReviewPage> createState() => _ReviewPageState();
}

class _ReviewPageState extends State<ReviewPage> {
  late ReviewKind _kind = widget.kind;
  DateTime _anchor = DateTime.now();

  ReviewPeriod _period(BuildContext context) => ReviewPeriod.of(
    _kind,
    _anchor,
    weekStart: SettingsScope.of(context).weekStart.weekday,
  );

  @override
  Widget build(BuildContext context) {
    final period = _period(context);
    final isCurrent = period.contains(DateTime.now());

    return Scaffold(
      appBar: AppBar(title: const Text('ふり返りレビュー')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
            child: SegmentedButton<ReviewKind>(
              segments: [
                for (final k in ReviewKind.values)
                  ButtonSegment(value: k, label: Text(k.label)),
              ],
              selected: {_kind},
              showSelectedIcon: false,
              onSelectionChanged: (s) => setState(() {
                _kind = s.first;
                _anchor = DateTime.now();
              }),
            ),
          ),
          Row(
            children: [
              IconButton(
                icon: const Icon(Icons.chevron_left),
                tooltip: '前の${_kind.label}',
                onPressed: () =>
                    setState(() => _anchor = period.previous.start),
              ),
              Expanded(
                child: Text(
                  period.label,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.chevron_right),
                tooltip: '次の${_kind.label}',
                onPressed: isCurrent
                    ? null
                    : () => setState(() => _anchor = period.next.start),
              ),
            ],
          ),
          Expanded(
            child: TsuzuriDataBuilder(
              parts: const {
                DataPart.timetable,
                DataPart.recurring,
                DataPart.todos,
                DataPart.goals,
                DataPart.reflections,
                DataPart.events,
                DataPart.study,
                DataPart.grades,
                DataPart.testReviews,
              },
              builder: (context, data) =>
                  _ReviewBody(period: period, data: data),
            ),
          ),
        ],
      ),
    );
  }
}

class _ReviewBody extends StatelessWidget {
  const _ReviewBody({required this.period, required this.data});

  final ReviewPeriod period;
  final TsuzuriSnapshot data;

  @override
  Widget build(BuildContext context) {
    final t = data.timetable!;
    final next = period.next;
    final span = period.days + next.days;

    final upcoming = [
      ...collectUpcoming(
        from: period.start,
        days: span,
        resolver: t.baseResolver,
        rules: t.activeRules,
        schoolTests: t.schoolTests,
      ),
      ...upcomingRecurringTests(data.recurring, period.start, span),
    ];
    final s = buildReview(
      period: period,
      sessions: data.sessions,
      todos: data.allTodos,
      upcoming: upcoming,
      exams: data.exams,
      testReviews: data.testReviews,
      goals: data.goals,
      events: [
        ...data.events,
        ...expandRecurringWithTests(data.recurring, period.start, next.end),
      ],
      reflections: data.reflections,
    );

    final kindLabel = period.kind.label;
    const gap = SizedBox(height: 12);

    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 720),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
          children: [
            _StudySection(summary: s, sessions: data.sessions),
            gap,
            _TestSection(summary: s),
            gap,
            _TodoGoalSection(summary: s),
            gap,
            _EventsSection(summary: s),
            if (s.reflections.isNotEmpty) ...[
              gap,
              InfoCard(
                title: '毎日のふり返り',
                icon: Icons.edit_note,
                children: [
                  for (final r in s.reflections)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SizedBox(
                            width: 72,
                            child: Faint(
                              '${r.date.month}/${r.date.day}'
                              '(${_wd[r.date.weekday - 1]})',
                            ),
                          ),
                          Expanded(child: Text(r.text)),
                        ],
                      ),
                    ),
                ],
              ),
            ],
            gap,
            _NextSection(summary: s),
            gap,
            _PeriodNote(periodKey: period.key, kindLabel: kindLabel),
          ],
        ),
      ),
    );
  }
}

// ───────────────────────── 勉強時間 ─────────────────────────

class _StudySection extends StatelessWidget {
  const _StudySection({required this.summary, required this.sessions});

  final ReviewSummary summary;
  final List<StudySession> sessions;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final p = summary.period;
    final diff = summary.studyDiff;

    // 棒グラフ：週と月は1日ずつ、学期は1か月ずつ
    late final List<int> bars;
    late final List<String> labels;
    int? highlight;
    final today = DateTime.now();
    if (p.kind == ReviewKind.term) {
      bars = [];
      labels = [];
      for (
        var m = p.start;
        m.isBefore(p.end);
        m = DateTime(m.year, m.month + 1, 1)
      ) {
        bars.add(totalMinutes(sessions, m, DateTime(m.year, m.month + 1, 1)));
        labels.add('${m.month}月');
      }
    } else {
      bars = summary.dailyStudy;
      labels = p.kind == ReviewKind.week
          ? [
              for (var i = 0; i < p.days; i++)
                _wd[DateTime(
                      p.start.year,
                      p.start.month,
                      p.start.day + i,
                    ).weekday -
                    1],
            ]
          : const [];
      if (p.contains(today)) {
        highlight = DateTime.utc(today.year, today.month, today.day)
            .difference(DateTime.utc(p.start.year, p.start.month, p.start.day))
            .inDays;
      }
    }

    return InfoCard(
      title: '勉強時間',
      icon: Icons.timer_outlined,
      children: [
        Row(
          children: [
            Expanded(
              child: BigNumber(
                value: formatMinutes(summary.studyMinutes),
                label: 'この${p.kind.label}',
              ),
            ),
            Expanded(
              child: BigNumber(
                value: formatMinutes(summary.previousStudyMinutes),
                label: '前の${p.kind.label}',
              ),
            ),
          ],
        ),
        if (summary.studyMinutes > 0 || summary.previousStudyMinutes > 0)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(
              diff == 0
                  ? '前の${p.kind.label}と同じ'
                  : '前の${p.kind.label}より ${diff > 0 ? '+' : '−'}'
                        '${formatMinutes(diff.abs())}',
              style: TextStyle(
                color: diff >= 0 ? cs.primary : cs.error,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        const SizedBox(height: 12),
        MiniBars(values: bars, labels: labels, highlight: highlight),
        if (summary.studyBySubject.isNotEmpty) ...[
          const SizedBox(height: 12),
          SubjectBars(entries: summary.studyBySubject),
        ],
      ],
    );
  }
}

// ───────────────────────── テスト・点数 ─────────────────────────

class _TestSection extends StatelessWidget {
  const _TestSection({required this.summary});

  final ReviewSummary summary;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final s = summary;
    return InfoCard(
      title: 'テスト',
      icon: Icons.assignment_outlined,
      trailing: Faint('${s.tests.length}件'),
      children: [
        if (s.tests.isEmpty) const Faint('この期間のテストはありません'),
        for (final t in s.tests)
          ListTile(
            contentPadding: EdgeInsets.zero,
            dense: true,
            leading: Faint('${t.date.month}/${t.date.day}'),
            title: Text(t.title),
            subtitle: t.detail == null ? null : Text(t.detail!),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => openTestKarte(context, t),
          ),
        if (s.scores.isNotEmpty) ...[
          const Divider(height: 20),
          Text('点数', style: Theme.of(context).textTheme.labelLarge),
          const SizedBox(height: 4),
          for (final x in s.scores)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 3),
              child: Row(
                children: [
                  Expanded(child: Text(x.title)),
                  Text(
                    '${_n(x.score)}/${_n(x.max)}',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: x.percent >= 80
                          ? cs.primary
                          : (x.percent < 50 ? cs.error : null),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ],
    );
  }
}

String _n(num v) =>
    v == v.roundToDouble() ? '${v.toInt()}' : v.toStringAsFixed(1);

// ───────────────────────── ToDo・目標 ─────────────────────────

class _TodoGoalSection extends StatelessWidget {
  const _TodoGoalSection({required this.summary});

  final ReviewSummary summary;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final s = summary;
    final todoTotal = s.todosDone.length + s.todosLeft.length;
    return InfoCard(
      title: 'ToDo・目標',
      icon: Icons.check_circle_outline,
      children: [
        Row(
          children: [
            Expanded(
              child: BigNumber(
                value: '${s.todosDone.length} / $todoTotal',
                label: 'ToDo 完了（期限がこの期間）',
              ),
            ),
            Expanded(
              child: BigNumber(
                value: '${s.goalsAchieved} / ${s.goals.length}',
                label: '目標 達成（期限がこの期間）',
              ),
            ),
          ],
        ),
        if (s.todosLeft.isNotEmpty) ...[
          const SizedBox(height: 10),
          Text('終わっていない ToDo', style: TextStyle(color: cs.error)),
          for (final t in s.todosLeft)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(
                '・${t.title}'
                '${t.dueDate == null ? '' : '（${t.dueDate!.month}/${t.dueDate!.day}）'}',
              ),
            ),
        ],
        if (s.goals.isNotEmpty) ...[
          const SizedBox(height: 10),
          for (final g in s.goals)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 3),
              child: Row(
                children: [
                  Icon(
                    g.achieved || g.progress >= 1
                        ? Icons.emoji_events
                        : Icons.flag_outlined,
                    size: 18,
                    color: g.achieved || g.progress >= 1
                        ? cs.tertiary
                        : cs.outline,
                  ),
                  const SizedBox(width: 6),
                  Expanded(child: Text(g.title)),
                  Faint(g.progressText),
                ],
              ),
            ),
        ],
      ],
    );
  }
}

// ───────────────────────── 予定 ─────────────────────────

class _EventsSection extends StatelessWidget {
  const _EventsSection({required this.summary});

  final ReviewSummary summary;

  @override
  Widget build(BuildContext context) {
    final events = summary.events;
    return InfoCard(
      title: '予定',
      icon: Icons.event_outlined,
      trailing: Faint('${events.length}件'),
      children: [
        if (events.isEmpty) const Faint('この期間の予定はありません'),
        for (final e in events.take(12))
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 2),
            child: Row(
              children: [
                SizedBox(
                  width: 56,
                  child: Faint('${e.start.month}/${e.start.day}'),
                ),
                Expanded(child: Text(e.title)),
              ],
            ),
          ),
        if (events.length > 12) Faint('ほか${events.length - 12}件'),
      ],
    );
  }
}

// ───────────────────────── 次の期間 ─────────────────────────

class _NextSection extends StatelessWidget {
  const _NextSection({required this.summary});

  final ReviewSummary summary;

  @override
  Widget build(BuildContext context) {
    final s = summary;
    final k = s.period.kind.label;
    return InfoCard(
      title: '次の$k',
      icon: Icons.arrow_forward,
      children: [
        Row(
          children: [
            Expanded(
              child: BigNumber(value: '${s.nextTests.length}', label: 'テスト'),
            ),
            Expanded(
              child: BigNumber(value: '${s.nextTodos.length}', label: '締切'),
            ),
            Expanded(
              child: BigNumber(value: '${s.nextEvents.length}', label: '予定'),
            ),
          ],
        ),
        if (s.nextTests.isNotEmpty) ...[
          const SizedBox(height: 8),
          for (final t in s.nextTests.take(8))
            InkWell(
              onTap: () => openTestKarte(context, t),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 3),
                child: Text('📝 ${t.date.month}/${t.date.day} ${t.title}'),
              ),
            ),
        ],
        if (s.nextTodos.isNotEmpty) ...[
          const SizedBox(height: 4),
          for (final t in s.nextTodos.take(8))
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 3),
              child: Text('✅ ${t.dueDate!.month}/${t.dueDate!.day} ${t.title}'),
            ),
        ],
      ],
    );
  }
}

// ───────────────────────── 期間のふり返り ─────────────────────────

class _PeriodNote extends StatefulWidget {
  const _PeriodNote({required this.periodKey, required this.kindLabel});

  final String periodKey;
  final String kindLabel;

  @override
  State<_PeriodNote> createState() => _PeriodNoteState();
}

class _PeriodNoteState extends State<_PeriodNote> {
  final _repo = ReviewRepository(uid: FirebaseAuth.instance.currentUser!.uid);
  final _text = TextEditingController();
  String? _loadedKey;
  String _saved = '';
  bool _saving = false;

  Stream<String>? _stream;
  String? _streamKey;

  /// 期間が変わったときだけ、読み込み直す
  Stream<String> get _note {
    if (_streamKey != widget.periodKey) {
      _streamKey = widget.periodKey;
      _stream = _repo.watchPeriodNote(widget.periodKey);
    }
    return _stream!;
  }

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    await _repo.savePeriodNote(widget.periodKey, _text.text);
    if (!mounted) return;
    setState(() {
      _saving = false;
      _saved = _text.text.trim();
    });
    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text('ふり返りを保存しました')));
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<String>(
      stream: _note,
      builder: (context, snap) {
        // 期間が変わったとき・はじめて読んだときだけ入力欄に入れる
        if (snap.hasData && _loadedKey != widget.periodKey) {
          _loadedKey = widget.periodKey;
          _saved = snap.data!;
          _text.text = snap.data!;
        }
        final changed = _text.text.trim() != _saved;
        return InfoCard(
          title: 'この${widget.kindLabel}のふり返り',
          icon: Icons.rate_review_outlined,
          children: [
            TextField(
              controller: _text,
              minLines: 3,
              maxLines: 10,
              onChanged: (_) => setState(() {}),
              decoration: const InputDecoration(
                hintText: 'よかったこと・うまくいかなかったこと・次にやること',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerRight,
              child: FilledButton(
                onPressed: _saving || !changed ? null : _save,
                child: const Text('保存'),
              ),
            ),
          ],
        );
      },
    );
  }
}
