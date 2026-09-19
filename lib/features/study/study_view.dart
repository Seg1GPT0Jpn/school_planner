import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/date_format.dart';
import '../timetable/subject_colors.dart';
import '../timetable/timetable_repository.dart';
import 'study.dart';
import 'study_repository.dart';

/// 目標タブの「勉強時間」
class StudyView extends StatefulWidget {
  const StudyView({super.key});

  @override
  State<StudyView> createState() => _StudyViewState();
}

class _StudyViewState extends State<StudyView> {
  late final String _uid = FirebaseAuth.instance.currentUser!.uid;
  late final _repo = StudyRepository(uid: _uid);
  late final _sessions = _repo.watchSessions();
  late final _timer = _repo.watchTimer();
  late final _timetable = TimetableRepository(uid: _uid).watch();

  String? _subject;
  bool _month = false;
  Timer? _tick;

  @override
  void initState() {
    super.initState();
    // 動いているタイマーの表示を1秒ごとに更新
    _tick = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _tick?.cancel();
    super.dispose();
  }

  Future<void> _addManual(List<String> subjects) async {
    String? subject = _subject;
    DateTime date = DateTime.now();
    final minutes = TextEditingController(text: '30');
    final memo = TextEditingController();

    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => StatefulBuilder(
        builder: (c, set) => AlertDialog(
          title: const Text('勉強時間を記録'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _SubjectDropdown(
                subjects: subjects,
                value: subject,
                onChanged: (v) => set(() => subject = v),
              ),
              TextButton(
                onPressed: () async {
                  final d = await showDatePicker(
                    context: c,
                    initialDate: date,
                    firstDate: DateTime(2020),
                    lastDate: DateTime.now(),
                  );
                  if (d != null) set(() => date = d);
                },
                child: Text(formatDateJa(date)),
              ),
              TextField(
                controller: minutes,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: '時間（分）'),
              ),
              TextField(
                controller: memo,
                decoration: const InputDecoration(
                  labelText: 'メモ（例：問題集 p.20〜35）',
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(c).pop(false),
              child: const Text('キャンセル'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(c).pop(true),
              child: const Text('記録'),
            ),
          ],
        ),
      ),
    );
    final m = int.tryParse(minutes.text) ?? 0;
    if (ok == true && m > 0) {
      await _repo.add(
        StudySession(
          subject: subject,
          start: DateTime(date.year, date.month, date.day),
          minutes: m,
          memo: memo.text,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final tomorrow = DateTime(now.year, now.month, now.day + 1);
    final week = weekStart(now);
    final month = DateTime(now.year, now.month, 1);

    return StreamBuilder<TimetableData>(
      stream: _timetable,
      builder: (context, ts) => StreamBuilder<List<StudySession>>(
        stream: _sessions,
        builder: (context, ss) => StreamBuilder<RunningTimer?>(
          stream: _timer,
          builder: (context, tm) {
            final data = ts.data;
            final list = ss.data ?? const <StudySession>[];
            final running = tm.data;

            // 科目の選択肢は、今の時間割にある科目
            final subjects = data == null
                ? <String>[]
                : ({for (final s in data.slotsForDate(now)) s.subject}.toList()
                    ..sort());
            final categoryOf = {
              for (final s in data?.subjects ?? const []) s.name: s.category,
            };
            Color colorOf(String subject) =>
                subjectColorOf(context, categoryOf[subject]);

            final from = _month ? month : week;
            final bySubject = minutesBySubject(list, from, tomorrow);
            final maxSubject = bySubject.isEmpty ? 0 : bySubject.first.value;
            final daily = dailyMinutes(list, today, 7);
            final maxDaily = daily.fold(0, (a, b) => a > b ? a : b);

            return ListView(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
              children: [
                // ---------------- タイマー ----------------
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: running == null
                        ? Column(
                            children: [
                              _SubjectDropdown(
                                subjects: subjects,
                                value: _subject,
                                onChanged: (v) => setState(() => _subject = v),
                              ),
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  Expanded(
                                    child: FilledButton.icon(
                                      onPressed: () =>
                                          _repo.startTimer(_subject),
                                      icon: const Icon(Icons.play_arrow),
                                      label: const Text('スタート'),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  OutlinedButton.icon(
                                    onPressed: () => _addManual(subjects),
                                    icon: const Icon(Icons.edit),
                                    label: const Text('手で入力'),
                                  ),
                                ],
                              ),
                            ],
                          )
                        : Column(
                            children: [
                              Text(
                                running.subject ?? '（科目なし）',
                                style: Theme.of(context).textTheme.titleMedium,
                              ),
                              Text(
                                _elapsed(now.difference(running.startedAt)),
                                style: Theme.of(context).textTheme.displaySmall,
                              ),
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  Expanded(
                                    child: FilledButton.icon(
                                      onPressed: () => _repo.stopTimer(running),
                                      icon: const Icon(Icons.stop),
                                      label: const Text('ストップして記録'),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  TextButton(
                                    onPressed: _repo.cancelTimer,
                                    child: const Text('取り消し'),
                                  ),
                                ],
                              ),
                            ],
                          ),
                  ),
                ),

                // ---------------- 合計 ----------------
                const SizedBox(height: 8),
                Row(
                  children: [
                    for (final (label, m) in [
                      ('今日', totalMinutes(list, today, tomorrow)),
                      ('今週', totalMinutes(list, week, tomorrow)),
                      ('今月', totalMinutes(list, month, tomorrow)),
                    ])
                      Expanded(
                        child: Card(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            child: Column(
                              children: [
                                Text(
                                  label,
                                  style: TextStyle(color: cs.outline),
                                ),
                                Text(
                                  formatMinutes(m),
                                  style: Theme.of(context)
                                      .textTheme
                                      .titleMedium,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                  ],
                ),

                // ---------------- 科目ごと ----------------
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        '科目ごと',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    ),
                    SegmentedButton<bool>(
                      segments: const [
                        ButtonSegment(value: false, label: Text('今週')),
                        ButtonSegment(value: true, label: Text('今月')),
                      ],
                      selected: {_month},
                      showSelectedIcon: false,
                      onSelectionChanged: (s) =>
                          setState(() => _month = s.first),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                if (bySubject.isEmpty)
                  Text('まだ記録がありません', style: TextStyle(color: cs.outline)),
                for (final e in bySubject)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 3),
                    child: Row(
                      children: [
                        SizedBox(
                          width: 88,
                          child: Text(e.key, overflow: TextOverflow.ellipsis),
                        ),
                        Expanded(
                          child: FractionallySizedBox(
                            alignment: Alignment.centerLeft,
                            widthFactor: maxSubject == 0
                                ? 0
                                : e.value / maxSubject,
                            child: Container(
                              height: 14,
                              decoration: BoxDecoration(
                                color: colorOf(e.key),
                                borderRadius: BorderRadius.circular(4),
                              ),
                            ),
                          ),
                        ),
                        SizedBox(
                          width: 80,
                          child: Text(
                            formatMinutes(e.value),
                            textAlign: TextAlign.right,
                          ),
                        ),
                      ],
                    ),
                  ),

                // ---------------- 7日間 ----------------
                const SizedBox(height: 16),
                Text('この7日間', style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 8),
                SizedBox(
                  height: 140,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      for (var i = 0; i < 7; i++)
                        Expanded(
                          child: Column(
                            children: [
                              Text(
                                daily[i] == 0 ? '' : '${daily[i]}',
                                style: Theme.of(context).textTheme.labelSmall,
                              ),
                              Expanded(
                                child: Align(
                                  alignment: Alignment.bottomCenter,
                                  child: FractionallySizedBox(
                                    heightFactor: maxDaily == 0
                                        ? 0
                                        : daily[i] / maxDaily,
                                    widthFactor: 0.6,
                                    child: Container(
                                      decoration: BoxDecoration(
                                        color: cs.primary,
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              Text(
                                weekdayLabel(
                                  DateTime(
                                    today.year,
                                    today.month,
                                    today.day - 6 + i,
                                  ).weekday,
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
                Text(
                  '（数字は分）',
                  style: TextStyle(color: cs.outline, fontSize: 11),
                ),

                // ---------------- 最近の記録 ----------------
                const SizedBox(height: 16),
                Text('最近の記録', style: Theme.of(context).textTheme.titleMedium),
                for (final s in list.take(20))
                  Dismissible(
                    key: ValueKey(s.id),
                    background: Container(color: cs.errorContainer),
                    onDismissed: (_) => _repo.delete(s.id!),
                    child: ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(
                        '${s.subject ?? '（科目なし）'}　${formatMinutes(s.minutes)}',
                      ),
                      subtitle: Text(
                        '${formatDateJa(s.start)}${s.memo == null ? '' : '　${s.memo}'}',
                      ),
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }

  static String _elapsed(Duration d) {
    String two(int n) => n.toString().padLeft(2, '0');
    return '${d.inHours}:${two(d.inMinutes % 60)}:${two(d.inSeconds % 60)}';
  }
}

class _SubjectDropdown extends StatelessWidget {
  const _SubjectDropdown({
    required this.subjects,
    required this.value,
    required this.onChanged,
  });

  final List<String> subjects;
  final String? value;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    final names = [...subjects];
    if (value != null && !names.contains(value)) names.add(value!);
    return DropdownButton<String?>(
      isExpanded: true,
      value: value,
      hint: const Text('科目を選ぶ'),
      items: [
        const DropdownMenuItem<String?>(value: null, child: Text('（科目なし）')),
        for (final n in names)
          DropdownMenuItem<String?>(value: n, child: Text(n)),
      ],
      onChanged: onChanged,
    );
  }
}
