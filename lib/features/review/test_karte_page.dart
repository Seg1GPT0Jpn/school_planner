/// テストカルテ ― 1つのテストの「範囲・目標・勉強・結果・ふり返り」を1画面で
library;

import 'package:firebase_auth/firebase_auth.dart';
import 'package:material_ui/material_ui.dart';

import '../goals/goal.dart';
import '../goals/test_goal_link.dart';
import '../grades/grade.dart';
import '../school_tests/school_test.dart';
import '../school_tests/school_test_edit_page.dart';
import '../school_tests/school_test_repository.dart';
import '../school_tests/upcoming_tests.dart';
import '../study/study.dart';
import '../timetable/timetable_repository.dart';
import 'review_models.dart';
import 'review_repository.dart';
import 'review_widgets.dart';
import 'test_karte.dart';
import 'tsuzuri_data.dart';

const _wd = ['月', '火', '水', '木', '金', '土', '日'];

/// テストカルテを開く
void openTestKarte(BuildContext context, UpcomingItem item) {
  Navigator.of(
    context,
    rootNavigator: true,
  ).push(MaterialPageRoute<void>(builder: (_) => TestKartePage(item: item)));
}

/// 手で登録したテストからテストカルテを開く
void openTestKarteForTest(BuildContext context, SchoolTest t) => openTestKarte(
  context,
  UpcomingItem(
    date: DateTime(t.date.year, t.date.month, t.date.day),
    title: t.displayTitle,
    kindLabel: t.kind.label,
    isTest: t.kind.isTest,
    detail: t.scope,
    period: t.period,
    source: t,
    subject: t.subject,
  ),
);

String _n(num v) =>
    v == v.roundToDouble() ? '${v.toInt()}' : v.toStringAsFixed(1);

class TestKartePage extends StatelessWidget {
  const TestKartePage({super.key, required this.item});

  final UpcomingItem item;

  @override
  Widget build(BuildContext context) {
    final d = item.date;
    return Scaffold(
      appBar: AppBar(
        title: const Text('テストカルテ'),
        actions: [
          if (item.source != null)
            IconButton(
              icon: const Icon(Icons.edit_outlined),
              tooltip: 'テストの登録を直す',
              onPressed: () async {
                final uid = FirebaseAuth.instance.currentUser!.uid;
                final nav = Navigator.of(context);
                final t = await TimetableRepository(uid: uid).watch().first;
                await nav.push(
                  MaterialPageRoute<void>(
                    fullscreenDialog: true,
                    builder: (_) => SchoolTestEditPage(
                      repository: SchoolTestRepository(uid: uid),
                      subjects: t.subjects,
                      test: item.source,
                    ),
                  ),
                );
              },
            ),
        ],
      ),
      body: TsuzuriDataBuilder(
        parts: const {
          DataPart.study,
          DataPart.grades,
          DataPart.testReviews,
          DataPart.goals,
        },
        builder: (context, data) {
          final key = testKeyOf(item);
          final review = data.testReviews[key];
          final karte = buildKarte(
            date: d,
            subject: item.subject,
            sessions: data.sessions,
            exams: data.exams,
            review: review,
          );
          final goalId = item.source?.id == null
              ? null
              : testGoalId(item.source!.id!);
          final goal = goalId == null
              ? null
              : data.goals.where((g) => g.id == goalId).firstOrNull;
          final today = DateTime.now();
          final isOver = !DateTime(
            d.year,
            d.month,
            d.day,
          ).isAfter(DateTime(today.year, today.month, today.day));

          const gap = SizedBox(height: 12);
          return Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 720),
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
                children: [
                  _BasicCard(item: item),
                  gap,
                  if (isOver) ...[_ResultCard(karte: karte), gap],
                  _StudyCard(item: item, karte: karte),
                  gap,
                  _GoalCard(item: item, goal: goal, karte: karte),
                  gap,
                  if (isOver)
                    _ReviewEditor(
                      key: ValueKey(key),
                      reviewKey: key,
                      initial: review ?? const TestReview(),
                      testId: item.source?.id,
                      targetScore: item.source?.targetScore,
                    )
                  else
                    InfoCard(
                      title: 'ふり返り',
                      icon: Icons.rate_review_outlined,
                      children: [
                        const Faint(
                          'テストが終わったら、ここで点数とふり返りを書きます。\n'
                          '① 点数 → ② 勉強時間 → ③ 目標 → ④ ふり返り → ⑤ 次の目標',
                        ),
                        if (karte.previous != null) ...[
                          const SizedBox(height: 8),
                          Text(
                            '前回：${karte.previous!.$1.title} '
                            '${_n(karte.previous!.$2.score)}/'
                            '${_n(karte.previous!.$2.max)}点',
                          ),
                        ],
                      ],
                    ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

// ───────────────────────── 基本情報 ─────────────────────────

class _BasicCard extends StatelessWidget {
  const _BasicCard({required this.item});

  final UpcomingItem item;

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final d = item.date;
    final target = item.source?.targetScore;
    final scope = item.detail ?? item.source?.scope;
    final memo = item.source?.memo;

    Widget row(String k, String v) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 72, child: Faint(k)),
          Expanded(child: Text(v)),
        ],
      ),
    );

    return InfoCard(
      title: item.title,
      icon: Icons.assignment_outlined,
      children: [
        Text(item.kindLabel, style: tt.labelLarge),
        const SizedBox(height: 6),
        row(
          '日にち',
          '${d.year}年${d.month}月${d.day}日(${_wd[d.weekday - 1]})'
              '${item.period == null ? '' : '　${item.period}限'}',
        ),
        if (item.subject != null) row('科目', item.subject!),
        if (scope != null && scope.isNotEmpty) row('範囲', scope),
        if (target != null) row('目標点', '${_n(target)}点'),
        if (memo != null && memo.isNotEmpty) row('メモ', memo),
      ],
    );
  }
}

// ───────────────────────── 結果 ─────────────────────────

class _ResultCard extends StatelessWidget {
  const _ResultCard({required this.karte});

  final KarteData karte;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final g = karte.grade;
    final p = karte.previous;
    final diff = karte.diff;

    return InfoCard(
      title: '結果',
      icon: Icons.emoji_events_outlined,
      children: [
        if (karte.score == null)
          const Faint('まだ点数が入っていません（下の「ふり返り」で入れられます）')
        else ...[
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(_n(karte.score!), style: tt.displaySmall),
              Text(' / ${_n(karte.max!)}点', style: tt.titleMedium),
            ],
          ),
          if (g != null)
            Faint(
              [
                '「成績」の記録（${g.$1.title}）から',
                if (g.$2.average != null) '平均${numText(g.$2.average!)}',
                if (g.$2.deviation != null) '偏差値${numText(g.$2.deviation!)}',
                if (g.$2.rank != null) '${g.$2.rank}位',
              ].join('・'),
            ),
        ],
        if (p != null) ...[
          const SizedBox(height: 10),
          Text('前回 ${p.$1.title}：${_n(p.$2.score)}/${_n(p.$2.max)}点'),
          if (diff != null)
            Text(
              '前回より ${diff >= 0 ? '+' : '−'}${diff.abs().toStringAsFixed(1)}'
              '（100点満点に直して）',
              style: TextStyle(
                color: diff >= 0 ? cs.primary : cs.error,
                fontWeight: FontWeight.bold,
              ),
            ),
        ],
      ],
    );
  }
}

// ───────────────────────── 勉強 ─────────────────────────

class _StudyCard extends StatelessWidget {
  const _StudyCard({required this.item, required this.karte});

  final UpcomingItem item;
  final KarteData karte;

  @override
  Widget build(BuildContext context) {
    final from = karte.windowStart;
    final labels = [
      for (var i = 0; i < karte.daily.length; i++)
        i % 2 == 0
            ? '${DateTime(from.year, from.month, from.day + i).day}'
            : '',
    ];
    return InfoCard(
      title: '試験前の勉強（${karteStudyDays}日間）',
      icon: Icons.timer_outlined,
      children: [
        if (item.subject == null)
          const Faint('科目がわからないテストなので、科目の勉強時間は数えられません')
        else
          Row(
            children: [
              Expanded(
                child: BigNumber(
                  value: formatMinutes(karte.subjectMinutes),
                  label: item.subject!,
                ),
              ),
              Expanded(
                child: BigNumber(
                  value: formatMinutes(karte.allMinutes),
                  label: 'ぜんぶの科目',
                ),
              ),
            ],
          ),
        if (item.subject != null) ...[
          const SizedBox(height: 12),
          MiniBars(
            values: karte.daily,
            labels: labels,
            highlight: karte.daily.length - 1,
          ),
          const SizedBox(height: 4),
          Faint(
            '${from.month}/${from.day}〜テストの日まで。'
            'いちばん右がテストの日です',
          ),
        ],
      ],
    );
  }
}

// ───────────────────────── 目標 ─────────────────────────

class _GoalCard extends StatelessWidget {
  const _GoalCard({
    required this.item,
    required this.goal,
    required this.karte,
  });

  final UpcomingItem item;
  final Goal? goal;
  final KarteData karte;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final target = item.source?.targetScore;
    final score = karte.score;
    return InfoCard(
      title: '目標',
      icon: Icons.flag_outlined,
      children: [
        if (target == null && goal == null)
          const Faint('目標点は入っていません（テストの登録画面で入れられます）')
        else ...[
          if (goal != null) ...[
            Text(goal!.title),
            const SizedBox(height: 6),
            LinearProgressIndicator(
              value: goal!.progress,
              minHeight: 8,
              borderRadius: BorderRadius.circular(4),
            ),
            const SizedBox(height: 4),
            Faint(goal!.progressText),
          ] else
            Text('目標点 ${_n(target!)}点'),
          if (score != null && target != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                score >= target
                    ? '🎉 目標達成（+${_n(score - target)}点）'
                    : 'あと${_n(target - score)}点でした',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: score >= target ? cs.primary : cs.error,
                ),
              ),
            ),
        ],
      ],
    );
  }
}

// ───────────────────────── ふり返り ─────────────────────────

class _ReviewEditor extends StatefulWidget {
  const _ReviewEditor({
    super.key,
    required this.reviewKey,
    required this.initial,
    this.testId,
    this.targetScore,
  });

  final String reviewKey;
  final TestReview initial;
  final String? testId;
  final num? targetScore;

  @override
  State<_ReviewEditor> createState() => _ReviewEditorState();
}

class _ReviewEditorState extends State<_ReviewEditor> {
  late final _score = TextEditingController(
    text: widget.initial.score == null ? '' : _n(widget.initial.score!),
  );
  late final _max = TextEditingController(text: _n(widget.initial.maxScore));
  late final _good = TextEditingController(text: widget.initial.good);
  late final _bad = TextEditingController(text: widget.initial.bad);
  late final _improve = TextEditingController(text: widget.initial.improve);
  late final _next = TextEditingController(text: widget.initial.next);
  bool _saving = false;

  @override
  void dispose() {
    for (final c in [_score, _max, _good, _bad, _improve, _next]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    final score = num.tryParse(_score.text.trim());
    final max = num.tryParse(_max.text.trim()) ?? 100;
    if (_score.text.trim().isNotEmpty && score == null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('点数は数字で入れてください')));
      return;
    }
    setState(() => _saving = true);
    try {
      await ReviewRepository(uid: FirebaseAuth.instance.currentUser!.uid)
          .saveTestReview(
            widget.reviewKey,
            TestReview(
              score: score,
              maxScore: max,
              good: _good.text,
              bad: _bad.text,
              improve: _improve.text,
              next: _next.text,
            ),
            testId: widget.testId,
            targetScore: widget.targetScore,
          );
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('カルテを保存しました')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('保存できませんでした：$e')));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Widget _field(TextEditingController c, String label, String hint) => Padding(
    padding: const EdgeInsets.only(top: 12),
    child: TextField(
      controller: c,
      minLines: 2,
      maxLines: 6,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        border: const OutlineInputBorder(),
      ),
    ),
  );

  @override
  Widget build(BuildContext context) {
    return InfoCard(
      title: 'ふり返り',
      icon: Icons.rate_review_outlined,
      children: [
        const Faint('① 点数 → ② 勉強時間と ③ 目標を上で確かめて → ④ ふり返り → ⑤ 次の目標'),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _score,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: const InputDecoration(
                  labelText: '① 点数',
                  border: OutlineInputBorder(),
                ),
              ),
            ),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 8),
              child: Text('/'),
            ),
            SizedBox(
              width: 96,
              child: TextField(
                controller: _max,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: '満点',
                  border: OutlineInputBorder(),
                ),
              ),
            ),
          ],
        ),
        _field(_good, '④ できたこと', '例：計算問題はミスなくできた'),
        _field(_bad, '④ できなかったこと', '例：証明問題で時間が足りなかった'),
        _field(_improve, '④ 次に直すこと', '例：証明は1日1問ずつ練習する'),
        _field(_next, '⑤ 次の目標', '例：次は80点以上'),
        const SizedBox(height: 12),
        Align(
          alignment: Alignment.centerRight,
          child: FilledButton.icon(
            onPressed: _saving ? null : _save,
            icon: const Icon(Icons.save_outlined),
            label: const Text('保存'),
          ),
        ),
      ],
    );
  }
}
