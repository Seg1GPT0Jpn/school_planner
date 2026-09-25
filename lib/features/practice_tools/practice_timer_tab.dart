/// 練習時間の記録（既存の「勉強タイマー」のしくみをそのまま使う）
///
/// 教科の代わりに「個人練習」「基礎合奏」などを選ぶだけで、記録先は
/// 勉強時間の記録（study_sessions）と同じ。生活分析にもそのまま反映される。
library;

import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:material_ui/material_ui.dart';

import '../study/study.dart';
import '../study/study_repository.dart';
import 'practice/practice_history_repository.dart';

const _practiceKinds = ['個人練習', '基礎合奏', 'パート練習', '本番'];

/// 日付ごとに、その日のロングトーン記録をまとめたもの（練習の「質」の振り返り用）
class _DayQuality {
  _DayQuality(this.day);
  final DateTime day;
  final List<LongToneSessionRecord> records = [];

  double get avgStability =>
      records.map((r) => r.stabilityPercent).reduce((a, b) => a + b) / records.length;

  double get avgAbsCents =>
      records.map((r) => r.meanCents.abs()).reduce((a, b) => a + b) / records.length;
}

List<_DayQuality> _groupByDay(List<LongToneSessionRecord> records) {
  final map = <DateTime, _DayQuality>{};
  for (final r in records) {
    final day = DateTime(r.date.year, r.date.month, r.date.day);
    map.putIfAbsent(day, () => _DayQuality(day)).records.add(r);
  }
  final list = map.values.toList()..sort((a, b) => b.day.compareTo(a.day));
  return list;
}

class PracticeTimerTab extends StatefulWidget {
  const PracticeTimerTab({super.key});

  @override
  State<PracticeTimerTab> createState() => _PracticeTimerTabState();
}

class _PracticeTimerTabState extends State<PracticeTimerTab> {
  late final String _uid = FirebaseAuth.instance.currentUser!.uid;
  late final _repo = StudyRepository(uid: _uid);
  String _kind = _practiceKinds.first;
  Timer? _tick;

  @override
  void initState() {
    super.initState();
    _tick = Timer.periodic(const Duration(seconds: 1), (_) => setState(() {}));
  }

  @override
  void dispose() {
    _tick?.cancel();
    super.dispose();
  }

  String _fmt(Duration d) {
    final h = d.inHours;
    final m = d.inMinutes % 60;
    final s = d.inSeconds % 60;
    final mm = m.toString().padLeft(2, '0');
    final ss = s.toString().padLeft(2, '0');
    return h > 0 ? '$h:$mm:$ss' : '$mm:$ss';
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return StreamBuilder<RunningTimer?>(
      stream: _repo.watchTimer(),
      builder: (context, timerSnap) {
        final running = timerSnap.data;
        final isPractice = running != null && _practiceKinds.contains(running.subject);

        return StreamBuilder<List<StudySession>>(
          stream: _repo.watchSessions(),
          builder: (context, sessSnap) {
            final all = sessSnap.data ?? const <StudySession>[];
            final practiceLog = [
              for (final s in all)
                if (_practiceKinds.contains(s.subject)) s,
            ].take(20).toList();

            return ListView(
              padding: const EdgeInsets.all(20),
              children: [
                const Text('練習の種類を選んで、練習前後に記録できます。'),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  children: [
                    for (final k in _practiceKinds)
                      ChoiceChip(
                        label: Text(k),
                        selected: _kind == k,
                        onSelected: running != null
                            ? null
                            : (_) => setState(() => _kind = k),
                      ),
                  ],
                ),
                const SizedBox(height: 24),
                if (isPractice) ...[
                  Center(
                    child: Text(
                      _fmt(DateTime.now().difference(running.startedAt)),
                      style: Theme.of(context).textTheme.displayMedium
                          ?.copyWith(fontWeight: FontWeight.bold),
                    ),
                  ),
                  Center(
                    child: Text(
                      running.subject ?? '',
                      style: TextStyle(color: cs.outline),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Center(
                    child: FilledButton.icon(
                      onPressed: () => _repo.stopTimer(running),
                      icon: const Icon(Icons.stop),
                      label: const Text('止めて記録する'),
                    ),
                  ),
                ] else if (running != null) ...[
                  Text(
                    '今は「${running.subject ?? '勉強'}」のタイマーが動いています。'
                    '練習を記録するには、そちらを先に止めてください。',
                    style: TextStyle(color: cs.outline),
                  ),
                ] else
                  Center(
                    child: FilledButton.icon(
                      onPressed: () => _repo.startTimer(_kind),
                      icon: const Icon(Icons.play_arrow),
                      label: const Text('練習を始める'),
                    ),
                  ),
                const SizedBox(height: 28),
                Text('練習ログ（最近20件）', style: Theme.of(context).textTheme.titleSmall),
                const SizedBox(height: 8),
                if (practiceLog.isEmpty)
                  Text('まだ記録がありません', style: TextStyle(color: cs.outline))
                else
                  Column(
                    children: [
                      for (final s in practiceLog)
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          dense: true,
                          leading: const Icon(Icons.music_note, size: 20),
                          title: Text('${s.subject}　${formatMinutes(s.minutes)}'),
                          subtitle: Text(
                            '${s.start.month}/${s.start.day} '
                            '${s.start.hour.toString().padLeft(2, '0')}:'
                            '${s.start.minute.toString().padLeft(2, '0')}',
                          ),
                        ),
                    ],
                  ),
                const SizedBox(height: 28),
                Text('練習の質（ロングトーンの記録より）', style: Theme.of(context).textTheme.titleSmall),
                const SizedBox(height: 4),
                Text(
                  '「ロングトーン分析」タブで記録した結果を、日ごとにまとめたものです。'
                  '安定度が上がってきているか、音程のズレが小さくなってきているかの振り返りに使えます。',
                  style: TextStyle(color: cs.outline, fontSize: 12),
                ),
                const SizedBox(height: 8),
                StreamBuilder<List<LongToneSessionRecord>>(
                  stream: PracticeHistoryRepository(uid: _uid).watchRecent(limit: 100),
                  builder: (context, ltSnap) {
                    final byDay = _groupByDay(ltSnap.data ?? const []);
                    if (byDay.isEmpty) {
                      return Text('まだ記録がありません', style: TextStyle(color: cs.outline));
                    }
                    return Column(
                      children: [
                        for (final d in byDay.take(14))
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 3),
                            child: Row(
                              children: [
                                SizedBox(
                                  width: 72,
                                  child: Text(
                                    '${d.day.month}/${d.day.day}',
                                    style: TextStyle(color: cs.outline, fontSize: 12),
                                  ),
                                ),
                                Expanded(
                                  child: Text(
                                    '安定度 平均${d.avgStability.round()}%　'
                                    '音程のズレ 平均${d.avgAbsCents.toStringAsFixed(1)}¢'
                                    '（${d.records.length}回）',
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                    );
                  },
                ),
              ],
            );
          },
        );
      },
    );
  }
}
