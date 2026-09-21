import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:material_ui/material_ui.dart';

import '../belongings/belongings_pages.dart';
import '../events/calendar_event.dart';
import '../events/event_repository.dart';
import '../goals/goal.dart';
import '../goals/goal_repository.dart';
import '../goals/goals_page.dart';
import '../recurring/recurring_repository.dart';
import '../recurring/recurring_schedule.dart';
import '../recurring/recurring_test_rule.dart';
import '../review/review_page.dart';
import '../review/school_event_page.dart';
import '../review/test_karte_page.dart';
import '../school_tests/school_test.dart';
import '../school_tests/school_test_edit_page.dart';
import '../school_tests/school_test_repository.dart';
import '../school_tests/upcoming_tests.dart';
import '../school_tests/upcoming_tests_card.dart';
import '../settings/app_settings.dart';
import '../settings/settings_page.dart';
import '../settings/settings_scope.dart';
import '../study/study.dart';
import '../study/study_repository.dart';
import '../timetable/day_timetable_card.dart';
import '../timetable/day_timetable_resolver.dart';
import '../timetable/school_periods.dart';
import '../timetable/timetable_repository.dart';
import '../todo/todo.dart';
import '../todo/todo_page.dart';
import '../todo/todo_repository.dart';
import '../weather/weather_home_card.dart';
import 'home_brief.dart';

/// ホーム ― 開いた瞬間に「今日は何をすればいい？」が分かる画面
class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  late final String _uid = FirebaseAuth.instance.currentUser!.uid;
  late final _testRepository = SchoolTestRepository(uid: _uid);
  late final _todoRepository = TodoRepository(uid: _uid);

  final _subs = <StreamSubscription<dynamic>>[];
  Timer? _clock;

  TimetableData? _data;
  Object? _error;
  List<RecurringSchedule> _recurring = const [];
  List<Todo> _todos = const [];
  List<Goal> _goals = const [];
  List<CalendarEvent> _events = const [];
  List<StudySession> _sessions = const [];

  static const int _upcomingDays = 14;

  @override
  void initState() {
    super.initState();
    void on<T>(Stream<T> s, void Function(T) set) => _subs.add(
      s.listen(
        (v) => setState(() => set(v)),
        onError: (Object e) => setState(() => _error = e),
      ),
    );
    on(TimetableRepository(uid: _uid).watch(), (v) => _data = v);
    on(RecurringRepository(uid: _uid).watch(), (v) => _recurring = v);
    on(_todoRepository.watch(), (v) => _todos = v);
    on(GoalRepository(uid: _uid).watchGoals(), (v) => _goals = v);
    on(EventRepository(uid: _uid).watchAll(), (v) => _events = v);
    on(StudyRepository(uid: _uid).watchSessions(), (v) => _sessions = v);

    // 「いま何限」を1分ごとに進める
    _clock = Timer.periodic(const Duration(minutes: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _clock?.cancel();
    for (final s in _subs) {
      s.cancel();
    }
    super.dispose();
  }

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

  void _openTodo(Todo t) =>
      _push(TodoEditPage(todo: t, subjects: _data?.subjects ?? const []));

  /// テストはカルテ、学校行事はイベントのまとめ、提出物などは編集画面
  void _openUpcoming(UpcomingItem item) {
    if (item.isTest) return openTestKarte(context, item);
    final source = item.source;
    if (source == null) return;
    if (source.kind == SchoolTestKind.schoolEvent) {
      return openSchoolEventFromTest(context, source);
    }
    _push(
      SchoolTestEditPage(
        repository: _testRepository,
        subjects: _data?.subjects ?? const [],
        test: item.source,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
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
      body: _buildBody(context),
    );
  }

  Widget _buildBody(BuildContext context) {
    if (_error != null && _data == null) {
      return Center(child: Text('読み込みに失敗しました\n$_error'));
    }
    final data = _data;
    if (data == null) return const Center(child: CircularProgressIndicator());
    if (!data.isSeeded) {
      return const Center(child: Text('時間割タブから、基本時間割を登録してください。'));
    }

    final settings = SettingsScope.of(context);
    final now = DateTime.now();
    final today0 = DateTime(now.year, now.month, now.day);
    final tomorrow0 = DateTime(now.year, now.month, now.day + 1);
    final resolver = data.resolver;
    final today = resolver.resolve(today0);
    final tomorrow = resolver.resolve(tomorrow0);

    // 横断して集める
    final todos = sortTodos(mergeTodos(_todos, data.schoolTests));
    final upcoming = [
      ...collectUpcoming(
        from: now,
        days: _upcomingDays,
        resolver: data.baseResolver,
        rules: data.activeRules,
        schoolTests: data.schoolTests,
      ),
      ...upcomingRecurringTests(_recurring, now, _upcomingDays),
    ]..sort((a, b) => a.date.compareTo(b.date));
    final events = [
      ..._events,
      ...expandRecurringWithTests(
        _recurring,
        today0,
        DateTime(today0.year, today0.month, today0.day + 3),
      ),
    ];

    final urgent = buildUrgent(now: now, todos: todos, upcoming: upcoming);
    final todayBrief = buildDayBrief(
      day: today,
      events: events,
      upcoming: upcoming,
      todos: todos,
    );
    final tomorrowBrief = buildDayBrief(
      day: tomorrow,
      events: events,
      upcoming: upcoming,
      todos: todos,
    );
    final studyToday = totalMinutes(_sessions, today0, tomorrow0);
    final weekFrom = settings.startOfWeek(today0);
    final studyWeek = totalMinutes(
      _sessions,
      weekFrom,
      DateTime(weekFrom.year, weekFrom.month, weekFrom.day + 7),
    );
    final goals = [
      for (final g in sortGoals(_goals))
        if (!g.achieved && g.term == GoalTerm.short) g,
    ].take(3).toList();

    const gap = SizedBox(height: 12);

    // ── 今日 ──
    final todayColumn = <Widget>[
      WeatherHomeCard(
        isSchoolDay: (d) => resolver.resolve(d).status == DayStatus.school,
      ),
      gap,
      _NowCard(now: lessonNow(today, now), settings: settings),
      gap,
      _UrgentCard(
        items: urgent,
        now: now,
        onToggle: (t, v) => _todoRepository.save(t.copyWith(done: v)),
        onTapTodo: _openTodo,
        onTapTest: _openUpcoming,
      ),
      gap,
      _SectionTitle('今日', date: settings.date(today0, weekday: true)),
      if (today.status == DayStatus.school) ...[
        DayTimetableCard(title: '今日の時間割', day: today),
        gap,
      ],
      _EventsCard(
        title: '今日の予定',
        events: todayBrief.events,
        settings: settings,
      ),
      gap,
      _StudyCard(today: studyToday, week: studyWeek),
      gap,
      Card(
        child: ListTile(
          leading: const Icon(Icons.insights),
          title: const Text('ふり返りレビュー'),
          subtitle: const Text('今週・今月・今学期のまとめ'),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => openReview(context),
        ),
      ),
    ];

    // ── 明日・近日 ──
    final laterColumn = <Widget>[
      _SectionTitle('明日', date: settings.date(tomorrow0, weekday: true)),
      _TomorrowCard(
        brief: tomorrowBrief,
        settings: settings,
        onTapTodo: _openTodo,
        onTapTest: _openUpcoming,
      ),
      gap,
      TomorrowBelongingsCard(data: data, recurring: _recurring),
      if (today.status != DayStatus.school &&
          tomorrow.status != DayStatus.school) ...[
        gap,
        if (_findNextSchoolDay(resolver, now) case final next?)
          DayTimetableCard(title: '次の授業日', day: next),
      ],
      gap,
      const _SectionTitle('近日'),
      UpcomingTestsCard(
        items: upcoming,
        today: now,
        days: _upcomingDays,
        onTapItem: _openUpcoming,
      ),
      if (goals.isNotEmpty) ...[
        gap,
        _GoalCard(
          goals: goals,
          onTap: (g) => _push(GoalEditPage(goal: g)),
        ),
      ],
    ];

    final header = _Header(now: now, today: today, settings: settings);

    return LayoutBuilder(
      builder: (context, c) {
        // パソコンの広い画面では、左に「今日」、右に「明日・近日」
        if (c.maxWidth >= 900) {
          return Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1120),
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  header,
                  const SizedBox(height: 16),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(child: Column(children: todayColumn)),
                      const SizedBox(width: 16),
                      Expanded(child: Column(children: laterColumn)),
                    ],
                  ),
                ],
              ),
            ),
          );
        }
        return Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                header,
                const SizedBox(height: 16),
                ...todayColumn,
                gap,
                ...laterColumn,
              ],
            ),
          ),
        );
      },
    );
  }
}

// ═══════════════════════════ 部品 ═══════════════════════════

/// 一番上：日付と、今日がどんな日か
class _Header extends StatelessWidget {
  const _Header({
    required this.now,
    required this.today,
    required this.settings,
  });

  final DateTime now;
  final DayTimetable today;
  final AppSettings settings;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final tags = <String>[
      if (today.status == DayStatus.school && today.weekType != null)
        today.weekType!.label,
      if (today.status == DayStatus.school &&
          today.schedule != DaySchedule.regular)
        today.schedule.label,
      if (today.holidayName != null) today.holidayName!,
      if (today.closureTitle != null) today.closureTitle!,
      if (today.status != DayStatus.school &&
          today.holidayName == null &&
          today.closureTitle == null)
        '学校はお休み',
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(settings.date(now, weekday: true), style: tt.headlineSmall),
        const SizedBox(height: 6),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            for (final t in tags)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: cs.secondaryContainer,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  t,
                  style: tt.labelMedium?.copyWith(
                    color: cs.onSecondaryContainer,
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.title, {this.date});

  final String title;
  final String? date;

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 8, 4, 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.baseline,
        textBaseline: TextBaseline.alphabetic,
        children: [
          Text(title, style: tt.titleLarge),
          if (date != null) ...[
            const SizedBox(width: 8),
            Text(
              date!,
              style: tt.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.outline,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// いま何限・次は何
class _NowCard extends StatelessWidget {
  const _NowCard({required this.now, required this.settings});

  final LessonNow now;
  final AppSettings settings;

  String _time(ClockTime t) => settings.time(t.totalMinutes);

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    String left(int m) => m >= 60 ? 'あと${m ~/ 60}時間${m % 60}分' : 'あと$m分';

    final (IconData icon, String main, String? sub) = switch (now.phase) {
      LessonPhase.noSchool => (Icons.weekend_outlined, '今日は授業がありません', null),
      LessonPhase.beforeSchool => (
        Icons.wb_twilight,
        '${now.next!.period}限 ${now.next!.subject} から',
        '${_time(now.next!.start)} 開始・${left(now.minutesLeft!)}'
            '（${now.lastPeriod}限まで）',
      ),
      LessonPhase.inLesson => (
        Icons.menu_book,
        'いま ${now.current!.period}限 ${now.current!.subject}',
        [
          '${left(now.minutesLeft!)}で終わり',
          if (now.next != null) '次は ${now.next!.period}限 ${now.next!.subject}',
        ].join('・'),
      ),
      LessonPhase.between => (
        Icons.coffee_outlined,
        '次は ${now.next!.period}限 ${now.next!.subject}',
        '${_time(now.next!.start)} 開始・${left(now.minutesLeft!)}',
      ),
      LessonPhase.afterSchool => (
        Icons.nights_stay_outlined,
        '今日の授業はおわりました',
        '${now.lastPeriod}限まででした',
      ),
    };

    final testLabel = now.current?.testLabel ?? now.next?.testLabel;

    return Card(
      color: now.phase == LessonPhase.inLesson ? cs.primaryContainer : null,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(icon, size: 32, color: cs.primary),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(main, style: tt.titleMedium),
                  if (sub != null)
                    Text(sub, style: tt.bodySmall?.copyWith(color: cs.outline)),
                  if (testLabel != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        '📝 $testLabel',
                        style: tt.bodySmall?.copyWith(color: cs.error),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 急ぎ（期限切れ・今日・明日・近日）
class _UrgentCard extends StatelessWidget {
  const _UrgentCard({
    required this.items,
    required this.now,
    required this.onToggle,
    required this.onTapTodo,
    required this.onTapTest,
  });

  final List<UrgentItem> items;
  final DateTime now;
  final void Function(Todo todo, bool done) onToggle;
  final ValueChanged<Todo> onTapTodo;
  final ValueChanged<UpcomingItem> onTapTest;

  static const int _max = 8;

  Color _chipColor(ColorScheme cs, Urgency u) => switch (u) {
    Urgency.overdue => cs.error,
    Urgency.today => cs.error,
    Urgency.tomorrow => const Color(0xFFE65100),
    Urgency.soon => cs.outline,
  };

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final shown = items.take(_max).toList();

    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.priority_high, size: 20, color: cs.error),
                const SizedBox(width: 4),
                Text('急ぎ', style: tt.titleMedium),
                const Spacer(),
                if (items.isNotEmpty)
                  Text(
                    '${items.length}件',
                    style: tt.bodySmall?.copyWith(color: cs.outline),
                  ),
              ],
            ),
            const SizedBox(height: 4),
            if (items.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Text(
                  '急ぎのことはありません 🎉',
                  style: TextStyle(color: cs.outline),
                ),
              ),
            for (final x in shown)
              ListTile(
                contentPadding: EdgeInsets.zero,
                dense: true,
                visualDensity: VisualDensity.compact,
                leading: x.todo != null
                    ? Checkbox(
                        value: x.todo!.done,
                        onChanged: (v) => onToggle(x.todo!, v ?? false),
                      )
                    : const SizedBox(
                        width: 40,
                        child: Center(child: Text('📝')),
                      ),
                title: Text(
                  x.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                subtitle: (x.detail == null || x.detail!.isEmpty)
                    ? null
                    : Text(x.detail!),
                trailing: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    border: Border.all(color: _chipColor(cs, x.urgency)),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    x.urgency == Urgency.soon
                        ? 'あと${daysBetween(now, x.date)}日'
                        : x.urgency.label,
                    style: tt.labelSmall?.copyWith(
                      color: _chipColor(cs, x.urgency),
                    ),
                  ),
                ),
                onTap: () {
                  if (x.todo != null) onTapTodo(x.todo!);
                  if (x.upcoming != null) onTapTest(x.upcoming!);
                },
              ),
            if (items.length > _max)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(
                  'ほか${items.length - _max}件は ToDo・テストの画面で',
                  style: tt.bodySmall?.copyWith(color: cs.outline),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// 予定の一覧
class _EventsCard extends StatelessWidget {
  const _EventsCard({
    required this.title,
    required this.events,
    required this.settings,
  });

  final String title;
  final List<CalendarEvent> events;
  final AppSettings settings;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: tt.titleMedium),
            const SizedBox(height: 6),
            if (events.isEmpty)
              Text('予定はありません', style: TextStyle(color: cs.outline))
            else
              for (final e in events) _EventLine(event: e, settings: settings),
          ],
        ),
      ),
    );
  }
}

class _EventLine extends StatelessWidget {
  const _EventLine({required this.event, required this.settings});

  final CalendarEvent event;
  final AppSettings settings;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final past = !event.isAllDay && event.end.isBefore(DateTime.now());
    return Opacity(
      opacity: past && settings.dimPastEvents ? 0.5 : 1,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 96,
              child: Text(
                event.isAllDay
                    ? '終日'
                    : '${settings.timeOf(event.start)}〜${settings.timeOf(event.end)}',
                style: tt.bodySmall?.copyWith(color: cs.outline),
              ),
            ),
            Expanded(
              child: Text(
                [
                  event.title,
                  if (event.location != null && event.location!.isNotEmpty)
                    '（${event.location}）',
                ].join(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 勉強時間
class _StudyCard extends StatelessWidget {
  const _StudyCard({required this.today, required this.week});

  final int today;
  final int week;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    Widget box(String label, int m) => Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: tt.bodySmall?.copyWith(color: cs.outline)),
          Text(m == 0 ? '0分' : formatMinutes(m), style: tt.titleLarge),
        ],
      ),
    );
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(Icons.timer_outlined, color: cs.primary),
            const SizedBox(width: 12),
            box('今日の勉強', today),
            box('今週の勉強', week),
          ],
        ),
      ),
    );
  }
}

/// 明日のまとめ（時間割・テスト・締切・予定）
class _TomorrowCard extends StatelessWidget {
  const _TomorrowCard({
    required this.brief,
    required this.settings,
    required this.onTapTodo,
    required this.onTapTest,
  });

  final DayBrief brief;
  final AppSettings settings;
  final ValueChanged<Todo> onTapTodo;
  final ValueChanged<UpcomingItem> onTapTest;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final day = brief.day;
    final lessons = realLessons(day);

    Widget label(String s) => Padding(
      padding: const EdgeInsets.only(top: 12, bottom: 2),
      child: Text(s, style: tt.labelLarge?.copyWith(color: cs.primary)),
    );

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 時間割
            if (day.status == DayStatus.school) ...[
              Text(
                [
                  if (day.weekType != null) day.weekType!.label,
                  if (day.schedule != DaySchedule.regular) day.schedule.label,
                  if (lessons.isNotEmpty) '${lessons.last.period}限まで',
                ].join('・'),
                style: tt.titleMedium,
              ),
              const SizedBox(height: 6),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  for (final l in lessons)
                    Chip(
                      visualDensity: VisualDensity.compact,
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      label: Text(
                        '${l.period} ${l.subject}'
                        '${l.testLabel == null ? '' : ' 📝'}',
                      ),
                    ),
                ],
              ),
            ] else
              Text(
                day.holidayName ?? day.closureTitle ?? '学校はお休み',
                style: tt.titleMedium,
              ),

            if (brief.tests.isNotEmpty) ...[
              label('テスト'),
              for (final t in brief.tests)
                InkWell(
                  onTap: () => onTapTest(t),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 3),
                    child: Text(
                      '📝 ${t.title}'
                      '${t.detail == null ? '' : '（${t.detail}）'}',
                    ),
                  ),
                ),
            ],
            if (brief.dueTodos.isNotEmpty) ...[
              label('締切'),
              for (final t in brief.dueTodos)
                InkWell(
                  onTap: () => onTapTodo(t),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 3),
                    child: Text('✅ ${t.title}'),
                  ),
                ),
            ],
            if (brief.events.isNotEmpty) ...[
              label('予定'),
              for (final e in brief.events)
                _EventLine(event: e, settings: settings),
            ],
            if (brief.tests.isEmpty &&
                brief.dueTodos.isEmpty &&
                brief.events.isEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  'テスト・締切・予定はありません',
                  style: TextStyle(color: cs.outline),
                ),
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
