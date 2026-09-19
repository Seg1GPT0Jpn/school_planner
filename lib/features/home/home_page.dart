import 'package:firebase_auth/firebase_auth.dart';
import 'package:material_ui/material_ui.dart';

import '../goals/goal.dart';
import '../goals/goal_repository.dart';
import '../goals/goals_page.dart';
import '../settings/settings_page.dart';
import '../recurring/recurring_repository.dart';
import '../recurring/recurring_schedule.dart';
import '../recurring/recurring_test_rule.dart';
import '../school_tests/school_test_edit_page.dart';
import '../school_tests/school_test_repository.dart';
import '../school_tests/upcoming_tests.dart';
import '../school_tests/upcoming_tests_card.dart';
import '../timetable/day_timetable_card.dart';
import '../timetable/day_timetable_resolver.dart';
import '../timetable/timetable_repository.dart';
import '../todo/todo.dart';
import '../todo/todo_page.dart';
import '../todo/todo_repository.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  late final String _uid = FirebaseAuth.instance.currentUser!.uid;
  late final _timetableStream = TimetableRepository(uid: _uid).watch();
  late final _recurringStream = RecurringRepository(uid: _uid).watch();
  late final _todoStream = TodoRepository(uid: _uid).watch();
  late final _goalStream = GoalRepository(uid: _uid).watchGoals();
  late final _testRepository = SchoolTestRepository(uid: _uid);

  static const int _upcomingDays = 14;

  Future<void> _confirmSignOut() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('ログアウトしますか？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(c).pop(false),
            child: const Text('キャンセル'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(c).pop(true),
            child: const Text('ログアウト'),
          ),
        ],
      ),
    );
    if (ok == true) await FirebaseAuth.instance.signOut();
  }

  DayTimetable? _findNextSchoolDay(DayTimetableResolver r, DateTime from) {
    for (var i = 1; i <= 30; i++) {
      final day = r.resolve(from.add(Duration(days: i)));
      if (day.status == DayStatus.school) return day;
    }
    return null;
  }

  void _push(Widget page) => Navigator.of(
    context,
    rootNavigator: true,
  ).push(MaterialPageRoute<void>(fullscreenDialog: true, builder: (_) => page));

  @override
  Widget build(BuildContext context) {
    final name = FirebaseAuth.instance.currentUser?.displayName ?? '';

    return Scaffold(
      appBar: AppBar(
        title: const Text('ホーム'),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            tooltip: '設定',
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(builder: (_) => const SettingsPage()),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'ログアウト',
            onPressed: _confirmSignOut,
          ),
        ],
      ),
      body: StreamBuilder<TimetableData>(
        stream: _timetableStream,
        builder: (context, ts) {
          if (ts.hasError) {
            return Center(child: Text('読み込みに失敗しました\n${ts.error}'));
          }
          if (!ts.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final data = ts.data!;

          return StreamBuilder<List<RecurringSchedule>>(
            stream: _recurringStream,
            builder: (context, rs) => StreamBuilder<List<Todo>>(
              stream: _todoStream,
              builder: (context, tds) => StreamBuilder<List<Goal>>(
                stream: _goalStream,
                builder: (context, gs) {
                  final now = DateTime.now();
                  final resolver = data.resolver;
                  final today = resolver.resolve(now);
                  final cards = <Widget>[];

                  if (!data.isSeeded) {
                    cards.add(const Text('時間割タブから、基本時間割を登録してください。'));
                  } else {
                    // 今日の時間割（授業がなければ次の授業日も）
                    cards.add(DayTimetableCard(title: '今日の時間割', day: today));
                    if (today.status != DayStatus.school) {
                      final next = _findNextSchoolDay(resolver, now);
                      if (next != null) {
                        cards.add(const SizedBox(height: 12));
                        cards.add(DayTimetableCard(title: '次の授業日', day: next));
                      }
                    }

                    // 今日までの ToDo
                    final todos = sortTodos(
                      mergeTodos(tds.data ?? const [], data.schoolTests),
                    );
                    final due = [
                      for (final t in todos)
                        if (!t.done &&
                            t.dueDate != null &&
                            !DateTime(
                              t.dueDate!.year,
                              t.dueDate!.month,
                              t.dueDate!.day,
                            ).isAfter(DateTime(now.year, now.month, now.day)))
                          t,
                    ];
                    cards.add(const SizedBox(height: 12));
                    cards.add(
                      _TodoCard(
                        todos: due,
                        onTap: (t) => _push(
                          TodoEditPage(todo: t, subjects: data.subjects),
                        ),
                      ),
                    );

                    // これからのテスト・提出物
                    final upcoming = [
                      ...collectUpcoming(
                        from: now,
                        days: _upcomingDays,
                        resolver: data.baseResolver,
                        rules: data.activeRules,
                        schoolTests: data.schoolTests,
                      ),
                      ...upcomingRecurringTests(
                        rs.data ?? const [],
                        now,
                        _upcomingDays,
                      ),
                    ]..sort((a, b) => a.date.compareTo(b.date));
                    cards.add(const SizedBox(height: 12));
                    cards.add(
                      UpcomingTestsCard(
                        items: upcoming,
                        today: now,
                        days: _upcomingDays,
                        onTapItem: (item) {
                          if (item.source == null) return;
                          _push(
                            SchoolTestEditPage(
                              repository: _testRepository,
                              subjects: data.subjects,
                              test: item.source,
                            ),
                          );
                        },
                      ),
                    );

                    // 目標（短期・未達成・期限が近い順に3つ）
                    final goals = [
                      for (final g in sortGoals(gs.data ?? const []))
                        if (!g.achieved && g.term == GoalTerm.short) g,
                    ].take(3).toList();
                    if (goals.isNotEmpty) {
                      cards.add(const SizedBox(height: 12));
                      cards.add(
                        _GoalCard(
                          goals: goals,
                          onTap: (g) => _push(GoalEditPage(goal: g)),
                        ),
                      );
                    }
                  }

                  return Align(
                    alignment: Alignment.topCenter,
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 560),
                      child: ListView(
                        padding: const EdgeInsets.all(16),
                        children: [
                          Text(
                            'ようこそ、$name さん',
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                          const SizedBox(height: 16),
                          ...cards,
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          );
        },
      ),
    );
  }
}

/// 今日までの ToDo
class _TodoCard extends StatelessWidget {
  const _TodoCard({required this.todos, required this.onTap});

  final List<Todo> todos;
  final ValueChanged<Todo> onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final now = DateTime.now();
    final repo = TodoRepository(uid: FirebaseAuth.instance.currentUser!.uid);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('今日までの ToDo', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 4),
            if (todos.isEmpty)
              Text('今日までのやることはありません 🎉', style: TextStyle(color: cs.outline))
            else
              for (final t in todos)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                  leading: Checkbox(
                    value: t.done,
                    onChanged: (v) => repo.save(t.copyWith(done: v ?? false)),
                  ),
                  title: Text(t.title),
                  subtitle: Text(
                    [
                      dueText(t.dueDate!, now),
                      if (t.progressText != null) '✓ ${t.progressText}',
                    ].join('　'),
                    style: t.isOverdue(now) ? TextStyle(color: cs.error) : null,
                  ),
                  onTap: () => onTap(t),
                ),
          ],
        ),
      ),
    );
  }
}

/// 目標の進み具合
class _GoalCard extends StatelessWidget {
  const _GoalCard({required this.goals, required this.onTap});

  final List<Goal> goals;
  final ValueChanged<Goal> onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('目標', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            for (final g in goals)
              InkWell(
                onTap: () => onTap(g),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        g.subject == null
                            ? g.title
                            : '【${g.subject}】${g.title}',
                      ),
                      if (g.type != GoalProgressType.none) ...[
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Expanded(
                              child: LinearProgressIndicator(
                                value: g.progress,
                                minHeight: 6,
                                borderRadius: BorderRadius.circular(3),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              g.progressText,
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
