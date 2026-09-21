/// 時程の設定（時限の時刻・曜日ごとのコマ数・昼休み・短縮/試験日課・Ⅰ・Ⅱ週）
library;

import 'package:firebase_auth/firebase_auth.dart';
import 'package:material_ui/material_ui.dart';

import 'school_periods.dart';
import 'timetable_repository.dart';

const _wd = ['月', '火', '水', '木', '金', '土', '日'];

/// 1限の始まり・授業の長さ・休み時間から、時限の一覧を作る
List<SchoolPeriod> generatePeriods({
  required ClockTime firstStart,
  required int count,
  required int lessonMinutes,
  required int breakMinutes,
  int lunchAfter = 0,
  int lunchMinutes = 0,
}) {
  final out = <SchoolPeriod>[];
  var t = firstStart.totalMinutes;
  for (var n = 1; n <= count; n++) {
    out.add(
      SchoolPeriod(
        number: n,
        start: ClockTime.fromMinutes(t),
        end: ClockTime.fromMinutes(t + lessonMinutes),
      ),
    );
    t += lessonMinutes;
    t += (lunchAfter > 0 && n == lunchAfter) ? lunchMinutes : breakMinutes;
  }
  return out;
}

class ScheduleConfigPage extends StatefulWidget {
  const ScheduleConfigPage({super.key});

  @override
  State<ScheduleConfigPage> createState() => _ScheduleConfigPageState();
}

class _ScheduleConfigPageState extends State<ScheduleConfigPage> {
  late final _repo = TimetableRepository(
    uid: FirebaseAuth.instance.currentUser!.uid,
  );
  late final _stream = _repo.watch();

  /// 編集中の時程（はじめて読めたときに入れる）
  ScheduleConfig? _c;
  bool _changed = false;
  bool _saving = false;

  void _set(ScheduleConfig c) => setState(() {
    _c = c;
    _changed = true;
  });

  Future<void> _save() async {
    final c = _c!;
    final problems = c.problems();
    if (problems.isNotEmpty) {
      await showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('直してほしいところがあります'),
          content: Text(problems.join('\n')),
          actions: [
            FilledButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('OK'),
            ),
          ],
        ),
      );
      return;
    }
    setState(() => _saving = true);
    await _repo.saveScheduleConfig(c);
    if (!mounted) return;
    setState(() {
      _saving = false;
      _changed = false;
    });
    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text('時程を保存しました')));
  }

  Future<void> _reset() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('はじめの時程にもどしますか？'),
        content: const Text('70分授業・月火木5コマ・水金4コマ・Ⅰ・Ⅱ週あり の時程にもどります。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('キャンセル'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('もどす'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    await _repo.resetScheduleConfig();
    setState(() {
      _c = ScheduleConfig.standard;
      _changed = false;
    });
  }

  /// 授業の長さなどから、まとめて作る
  Future<List<SchoolPeriod>?> _generate({
    required String title,
    required List<SchoolPeriod> current,
    bool withLunch = false,
  }) async {
    final first = current.isEmpty
        ? const ClockTime(8, 50)
        : current.first.start;
    final count = TextEditingController(
      text: '${current.isEmpty ? 5 : current.length}',
    );
    final len = TextEditingController(
      text: '${current.isEmpty ? 50 : current.first.durationMinutes}',
    );
    final brk = TextEditingController(
      text: current.length < 2
          ? '10'
          : '${current[1].start.totalMinutes - current[0].end.totalMinutes}',
    );
    final lunchAfter = TextEditingController(
      text: withLunch ? '${_c!.lunchAfterPeriod}' : '0',
    );
    final lunchLen = TextEditingController(
      text: '${_c!.lunchEnd.totalMinutes - _c!.lunchStart.totalMinutes + 5}',
    );
    var start = first;

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) {
          Widget field(TextEditingController c, String label) => TextField(
            controller: c,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(labelText: label),
          );
          return AlertDialog(
            title: Text(title),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('1限の始まり'),
                    trailing: Text('$start'),
                    onTap: () async {
                      final t = await showTimePicker(
                        context: ctx,
                        initialTime: TimeOfDay(
                          hour: start.hour,
                          minute: start.minute,
                        ),
                      );
                      if (t != null) {
                        setLocal(() => start = ClockTime(t.hour, t.minute));
                      }
                    },
                  ),
                  field(count, '時限の数'),
                  field(len, '授業の長さ（分）'),
                  field(brk, '休み時間（分）'),
                  if (withLunch) ...[
                    field(lunchAfter, '昼休みは何限のあと（0 ならなし）'),
                    field(lunchLen, '昼休みの長さ（分・休み時間をふくむ）'),
                  ],
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('キャンセル'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('作る'),
              ),
            ],
          );
        },
      ),
    );
    if (ok != true) return null;
    final n = (int.tryParse(count.text) ?? 0).clamp(1, 12);
    final la = withLunch ? (int.tryParse(lunchAfter.text) ?? 0).clamp(0, n) : 0;
    final list = generatePeriods(
      firstStart: start,
      count: n,
      lessonMinutes: (int.tryParse(len.text) ?? 50).clamp(5, 240),
      breakMinutes: (int.tryParse(brk.text) ?? 10).clamp(0, 120),
      lunchAfter: la,
      lunchMinutes: (int.tryParse(lunchLen.text) ?? 45).clamp(0, 180),
    );
    if (withLunch) {
      // 昼休みの時刻も合わせる
      final lunch = la > 0 && la < list.length
          ? (start: list[la - 1].end, end: list[la].start.addMinutes(-5))
          : null;
      _set(
        _c!.copyWith(
          periods: list,
          lunchAfterPeriod: la,
          lunchStart: lunch?.start,
          lunchEnd: lunch?.end,
        ),
      );
      return null;
    }
    return list;
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_changed,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        final leave = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('保存していない変更があります'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('保存しないで戻る'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('編集を続ける'),
              ),
            ],
          ),
        );
        if (leave == true && context.mounted) Navigator.of(context).pop();
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('時程の設定'),
          actions: [
            TextButton(
              onPressed: _c == null || !_changed || _saving ? null : _save,
              child: const Text('保存'),
            ),
          ],
        ),
        body: StreamBuilder<TimetableData>(
          stream: _stream,
          builder: (context, snap) {
            if (_c == null && snap.hasData) _c = snap.data!.config;
            final c = _c;
            if (c == null) {
              return const Center(child: CircularProgressIndicator());
            }
            return _body(context, c);
          },
        ),
      ),
    );
  }

  Widget _body(BuildContext context, ScheduleConfig c) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    Widget header(String t, [String? note]) => Padding(
      padding: const EdgeInsets.fromLTRB(4, 20, 4, 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(t, style: tt.titleMedium),
          if (note != null)
            Text(note, style: tt.bodySmall?.copyWith(color: cs.outline)),
        ],
      ),
    );

    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 640),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 40),
          children: [
            // ── Ⅰ・Ⅱ週 ──
            header('週の時間割'),
            Card(
              child: SwitchListTile(
                title: const Text('Ⅰ週・Ⅱ週で時間割が変わる'),
                subtitle: Text(
                  c.useWeekCycle
                      ? '2週間で1回りの時間割（Ⅰ週とⅡ週をそれぞれ入れます）'
                      : '毎週同じ時間割（Ⅰ週の時間割を毎週使います）',
                ),
                value: c.useWeekCycle,
                onChanged: (v) => _set(c.copyWith(useWeekCycle: v)),
              ),
            ),

            // ── 曜日ごとのコマ数 ──
            header('曜日ごとのコマ数', '0 にすると、その曜日は授業なしになります'),
            Card(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                child: Wrap(
                  spacing: 12,
                  runSpacing: 4,
                  children: [
                    for (var w = 1; w <= 7; w++)
                      SizedBox(
                        width: 84,
                        child: Row(
                          children: [
                            Text(
                              _wd[w - 1],
                              style: TextStyle(
                                color: w == 7
                                    ? cs.error
                                    : (w == 6 ? Colors.blue.shade700 : null),
                              ),
                            ),
                            const SizedBox(width: 6),
                            DropdownButton<int>(
                              value: c.periodCountFor(w),
                              items: [
                                for (var n = 0; n <= c.periods.length; n++)
                                  DropdownMenuItem(value: n, child: Text('$n')),
                              ],
                              onChanged: (n) {
                                if (n == null) return;
                                _set(
                                  c.copyWith(
                                    periodCounts: {...c.periodCounts, w: n},
                                  ),
                                );
                              },
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ),

            // ── 通常日課 ──
            header('通常日課の時限', 'いちばんコマ数が多い日のぶんまで入れます'),
            _PeriodListEditor(
              periods: c.periods,
              onChanged: (list) {
                // 時限を減らしたら、コマ数も合わせる
                final counts = {
                  for (final e in c.periodCounts.entries)
                    e.key: e.value > list.length ? list.length : e.value,
                };
                _set(
                  c.copyWith(
                    periods: list,
                    periodCounts: counts,
                    lunchAfterPeriod: c.lunchAfterPeriod >= list.length
                        ? 0
                        : c.lunchAfterPeriod,
                  ),
                );
              },
              onGenerate: () => _generate(
                title: '通常日課をまとめて作る',
                current: c.periods,
                withLunch: true,
              ),
            ),

            // ── 昼休み ──
            header('昼休み'),
            Card(
              child: Column(
                children: [
                  ListTile(
                    title: const Text('何限のあと'),
                    trailing: DropdownButton<int>(
                      value: c.lunchAfterPeriod.clamp(0, c.periods.length - 1),
                      items: [
                        const DropdownMenuItem(value: 0, child: Text('なし')),
                        for (var n = 1; n < c.periods.length; n++)
                          DropdownMenuItem(value: n, child: Text('$n限のあと')),
                      ],
                      onChanged: (n) {
                        if (n == null) return;
                        _set(
                          c.copyWith(
                            lunchAfterPeriod: n,
                            lunchStart: n == 0 ? null : c.periods[n - 1].end,
                            lunchEnd: n == 0
                                ? null
                                : c.periods[n].start.addMinutes(-5),
                          ),
                        );
                      },
                    ),
                  ),
                  if (c.lunchAfterPeriod > 0) ...[
                    _TimeTile(
                      label: '始まり',
                      time: c.lunchStart,
                      onChanged: (t) => _set(c.copyWith(lunchStart: t)),
                    ),
                    _TimeTile(
                      label: '終わり',
                      time: c.lunchEnd,
                      onChanged: (t) => _set(c.copyWith(lunchEnd: t)),
                    ),
                  ],
                ],
              ),
            ),

            // ── 短縮日課 ──
            header(
              '短縮日課',
              '「学校の設定」で短縮日課にした日に使います。'
                  'ふだんのコマ数ごとに決められます',
            ),
            for (final n in c.distinctCounts) ...[
              Padding(
                padding: const EdgeInsets.fromLTRB(4, 4, 4, 4),
                child: Text(
                  'ふだん$nコマの日'
                  '（${[for (var w = 1; w <= 7; w++)
                    if (c.periodCountFor(w) == n) _wd[w - 1]].join('・')}）',
                  style: tt.labelLarge,
                ),
              ),
              _PeriodListEditor(
                periods: c.shortenedFor(n),
                onChanged: (list) =>
                    _set(c.copyWith(shortened: {...c.shortened, n: list})),
                onGenerate: () async {
                  final list = await _generate(
                    title: 'ふだん$nコマの日の短縮日課',
                    current: c.shortenedFor(n),
                  );
                  if (list != null) {
                    _set(_c!.copyWith(shortened: {..._c!.shortened, n: list}));
                  }
                },
              ),
              const SizedBox(height: 8),
            ],

            // ── 試験日課 ──
            header('試験日課', '「学校の設定」で試験日課にした日に使います'),
            _PeriodListEditor(
              periods: c.examPeriods,
              onChanged: (list) => _set(c.copyWith(examPeriods: list)),
              onGenerate: () async {
                final list = await _generate(
                  title: '試験日課をまとめて作る',
                  current: c.examPeriods,
                );
                if (list != null) _set(_c!.copyWith(examPeriods: list));
              },
            ),

            const SizedBox(height: 24),
            OutlinedButton.icon(
              onPressed: _reset,
              icon: const Icon(Icons.restore),
              label: const Text('はじめの時程にもどす'),
            ),
            const SizedBox(height: 8),
            Text(
              '時程を変えても、入れた時間割（科目）はそのまま残ります。'
              'コマ数を減らした曜日の、はみ出したコマは表示されなくなります。',
              style: tt.bodySmall?.copyWith(color: cs.outline),
            ),
          ],
        ),
      ),
    );
  }
}

/// 時刻を1つ選ぶ行
class _TimeTile extends StatelessWidget {
  const _TimeTile({
    required this.label,
    required this.time,
    required this.onChanged,
  });

  final String label;
  final ClockTime time;
  final ValueChanged<ClockTime> onChanged;

  @override
  Widget build(BuildContext context) => ListTile(
    title: Text(label),
    trailing: Text('$time', style: Theme.of(context).textTheme.titleMedium),
    onTap: () async {
      final t = await showTimePicker(
        context: context,
        initialTime: TimeOfDay(hour: time.hour, minute: time.minute),
      );
      if (t != null) onChanged(ClockTime(t.hour, t.minute));
    },
  );
}

/// 時限の一覧を編集する（時刻をタップで変更・追加・最後を削除・まとめて作る）
class _PeriodListEditor extends StatelessWidget {
  const _PeriodListEditor({
    required this.periods,
    required this.onChanged,
    required this.onGenerate,
  });

  final List<SchoolPeriod> periods;
  final ValueChanged<List<SchoolPeriod>> onChanged;
  final VoidCallback onGenerate;

  Future<ClockTime?> _pick(BuildContext context, ClockTime t) async {
    final r = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: t.hour, minute: t.minute),
    );
    return r == null ? null : ClockTime(r.hour, r.minute);
  }

  void _replace(int i, SchoolPeriod p) => onChanged([...periods]..[i] = p);

  void _add() {
    if (periods.isEmpty) {
      onChanged(const [
        SchoolPeriod(number: 1, start: ClockTime(8, 50), end: ClockTime(9, 40)),
      ]);
      return;
    }
    final last = periods.last;
    final gap = periods.length >= 2
        ? periods[periods.length - 1].start.totalMinutes -
              periods[periods.length - 2].end.totalMinutes
        : 10;
    final start = last.end.addMinutes(gap);
    onChanged([
      ...periods,
      SchoolPeriod(
        number: last.number + 1,
        start: start,
        end: start.addMinutes(last.durationMinutes),
      ),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    return Card(
      child: Column(
        children: [
          for (var i = 0; i < periods.length; i++)
            ListTile(
              dense: true,
              leading: CircleAvatar(
                radius: 14,
                child: Text('${periods[i].number}', style: tt.labelMedium),
              ),
              title: Row(
                children: [
                  TextButton(
                    onPressed: () async {
                      final t = await _pick(context, periods[i].start);
                      if (t != null) {
                        _replace(
                          i,
                          SchoolPeriod(
                            number: periods[i].number,
                            start: t,
                            end: periods[i].end,
                          ),
                        );
                      }
                    },
                    child: Text('${periods[i].start}'),
                  ),
                  const Text('〜'),
                  TextButton(
                    onPressed: () async {
                      final t = await _pick(context, periods[i].end);
                      if (t != null) {
                        _replace(
                          i,
                          SchoolPeriod(
                            number: periods[i].number,
                            start: periods[i].start,
                            end: t,
                          ),
                        );
                      }
                    },
                    child: Text('${periods[i].end}'),
                  ),
                ],
              ),
              trailing: Text(
                '${periods[i].durationMinutes}分',
                style: tt.bodySmall?.copyWith(
                  color: periods[i].durationMinutes <= 0
                      ? cs.error
                      : cs.outline,
                ),
              ),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
            child: Wrap(
              spacing: 8,
              children: [
                TextButton.icon(
                  onPressed: _add,
                  icon: const Icon(Icons.add),
                  label: const Text('時限を足す'),
                ),
                if (periods.length > 1)
                  TextButton.icon(
                    onPressed: () =>
                        onChanged(periods.sublist(0, periods.length - 1)),
                    icon: const Icon(Icons.remove),
                    label: Text('${periods.last.number}限を消す'),
                  ),
                TextButton.icon(
                  onPressed: onGenerate,
                  icon: const Icon(Icons.auto_fix_high),
                  label: const Text('まとめて作る'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
