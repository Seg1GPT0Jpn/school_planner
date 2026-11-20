/// 生活分析 ― 今月の勉強時間・部活時間・提出物・曜日のクセなどをふり返る画面
library;

import 'package:firebase_auth/firebase_auth.dart';
import 'package:material_ui/material_ui.dart';

import '../ai_advisor/gemini_advisor.dart';
import '../events/calendar_event.dart';
import '../events/event_repository.dart';
import '../settings/settings_scope.dart';
import '../study/study.dart';
import '../study/study_repository.dart';
import '../todo/todo.dart';
import '../todo/todo_repository.dart';
import 'life_analysis.dart';

class LifeAnalysisPage extends StatefulWidget {
  const LifeAnalysisPage({super.key});

  @override
  State<LifeAnalysisPage> createState() => _LifeAnalysisPageState();
}

class _LifeAnalysisPageState extends State<LifeAnalysisPage> {
  late final String _uid = FirebaseAuth.instance.currentUser!.uid;
  late final _events = EventRepository(uid: _uid).watchAll();
  late final _sessions = StudyRepository(uid: _uid).watchSessions();
  late final _todos = TodoRepository(uid: _uid).watch();

  DateTime _month = DateTime(DateTime.now().year, DateTime.now().month, 1);

  void _shiftMonth(int delta) {
    setState(() => _month = DateTime(_month.year, _month.month + delta, 1));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('生活分析')),
      body: StreamBuilder<List<CalendarEvent>>(
        stream: _events,
        builder: (context, es) => StreamBuilder<List<StudySession>>(
          stream: _sessions,
          builder: (context, ss) => StreamBuilder<List<Todo>>(
            stream: _todos,
            builder: (context, ts) {
              if (!es.hasData || !ss.hasData || !ts.hasData) {
                return const Center(child: CircularProgressIndicator());
              }
              final events = es.data!;
              final sessions = ss.data!;
              final todos = ts.data!;

              final current = computeMonthlyStats(
                month: _month,
                events: events,
                sessions: sessions,
                todos: todos,
              );
              final previous = computeMonthlyStats(
                month: DateTime(_month.year, _month.month - 1, 1),
                events: events,
                sessions: sessions,
                todos: todos,
              );

              return ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.chevron_left),
                        onPressed: () => _shiftMonth(-1),
                      ),
                      Text(
                        '${current.month.year}年${current.month.month}月',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      IconButton(
                        icon: const Icon(Icons.chevron_right),
                        onPressed: () => _shiftMonth(1),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  _SummaryCard(stats: current, previous: previous),
                  const SizedBox(height: 16),
                  _StatCard(current: current, previous: previous),
                  const SizedBox(height: 16),
                  _WeekdayCard(stats: current),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

/// 今月のまとめ文（生成AIがONならGemini、それ以外・失敗時はルールベース）
class _SummaryCard extends StatefulWidget {
  const _SummaryCard({required this.stats, required this.previous});

  final MonthlyStats stats;
  final MonthlyStats previous;

  @override
  State<_SummaryCard> createState() => _SummaryCardState();
}

class _SummaryCardState extends State<_SummaryCard> {
  Future<String?>? _aiFuture;
  bool _initialized = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_initialized) {
      _initialized = true;
      _maybeGenerate();
    }
  }

  @override
  void didUpdateWidget(covariant _SummaryCard old) {
    super.didUpdateWidget(old);
    if (old.stats.month != widget.stats.month) _maybeGenerate();
  }

  void _maybeGenerate() {
    final enabled = SettingsScope.of(context).generativeAiEnabled;
    if (!enabled) {
      setState(() => _aiFuture = null);
      return;
    }
    setState(() {
      _aiFuture = generateLifeAnalysisMessage(
        stats: widget.stats,
        previous: widget.previous,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final fallback = buildFallbackSummary(widget.stats, widget.previous);
    final cs = Theme.of(context).colorScheme;
    final future = _aiFuture;

    Widget body;
    if (future == null) {
      body = Text(fallback, style: TextStyle(color: cs.onPrimaryContainer));
    } else {
      body = FutureBuilder<String?>(
        future: future,
        builder: (context, snap) {
          final text = snap.connectionState == ConnectionState.done
              ? (snap.data ?? fallback)
              : fallback;
          return Text(text, style: TextStyle(color: cs.onPrimaryContainer));
        },
      );
    }

    return Card(
      color: cs.primaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.insights, color: cs.onPrimaryContainer, size: 20),
            const SizedBox(width: 10),
            Expanded(child: body),
          ],
        ),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({required this.current, required this.previous});

  final MonthlyStats current;
  final MonthlyStats previous;

  String _diffText(int cur, int prev) {
    final d = percentDiff(cur, prev);
    if (d == null || d == 0) return '';
    return d > 0 ? '（先月比 +$d%）' : '（先月比 $d%）';
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _StatLine(
              '勉強時間',
              '${formatMinutes(current.studyMinutes)}'
                  '${_diffText(current.studyMinutes, previous.studyMinutes)}',
            ),
            _StatLine('部活時間', formatMinutes(current.clubMinutes)),
            _StatLine(
              '提出物・課題',
              '${current.todoDone}/${current.todoTotal} 件完了',
            ),
            _StatLine('予定なしの日', '${current.noPlanDays}日'),
            _StatLine(
              '1日の平均予定数',
              '${current.avgEventsPerDay.toStringAsFixed(1)}件',
            ),
          ],
        ),
      ),
    );
  }
}

class _StatLine extends StatelessWidget {
  const _StatLine(this.label, this.value);

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label),
        Text(value, style: const TextStyle(fontWeight: FontWeight.bold)),
      ],
    ),
  );
}

class _WeekdayCard extends StatelessWidget {
  const _WeekdayCard({required this.stats});

  final MonthlyStats stats;

  static const _names = ['月', '火', '水', '木', '金', '土', '日'];

  @override
  Widget build(BuildContext context) {
    final maxCount = stats.weekdayCounts.fold<int>(
      0,
      (m, c) => c > m ? c : m,
    );
    final cs = Theme.of(context).colorScheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('曜日別の予定の多さ', style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 8),
            for (var i = 0; i < 7; i++)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Row(
                  children: [
                    SizedBox(width: 24, child: Text(_names[i])),
                    Expanded(
                      child: FractionallySizedBox(
                        alignment: Alignment.centerLeft,
                        widthFactor: maxCount == 0
                            ? 0
                            : stats.weekdayCounts[i] / maxCount,
                        child: Container(height: 12, color: cs.primary),
                      ),
                    ),
                    const SizedBox(width: 8),
                    SizedBox(width: 24, child: Text('${stats.weekdayCounts[i]}')),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}
