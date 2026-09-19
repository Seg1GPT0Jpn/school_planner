import 'package:firebase_auth/firebase_auth.dart';
import 'package:material_ui/material_ui.dart';

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

/// ホーム画面
class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  late final Stream<TimetableData> _timetableStream;
  late final Stream<List<RecurringSchedule>> _recurringStream;
  late final SchoolTestRepository _testRepository;

  static const int _upcomingDays = 14;

  @override
  void initState() {
    super.initState();
    final uid = FirebaseAuth.instance.currentUser!.uid;
    _timetableStream = TimetableRepository(uid: uid).watch();
    _recurringStream = RecurringRepository(uid: uid).watch();
    _testRepository = SchoolTestRepository(uid: uid);
  }

  Future<void> _confirmSignOut(BuildContext context) async {
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

  void _openTestEditor(TimetableData data, UpcomingItem item) {
    final test = item.source;
    if (test == null) return;
    Navigator.of(context, rootNavigator: true).push(
      MaterialPageRoute<void>(
        fullscreenDialog: true,
        builder: (_) => SchoolTestEditPage(
          repository: _testRepository,
          subjects: data.subjects,
          test: test,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final name = FirebaseAuth.instance.currentUser?.displayName ?? '';

    return Scaffold(
      appBar: AppBar(
        title: const Text('ホーム'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'ログアウト',
            onPressed: () => _confirmSignOut(context),
          ),
        ],
      ),
      body: StreamBuilder<TimetableData>(
        stream: _timetableStream,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text('読み込みに失敗しました\n${snapshot.error}'));
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final data = snapshot.data!;

          return StreamBuilder<List<RecurringSchedule>>(
            stream: _recurringStream,
            builder: (context, rs) {
              final now = DateTime.now();
              final resolver = data.resolver;
              final today = resolver.resolve(now);

              final cards = <Widget>[];
              if (!data.isSeeded) {
                cards.add(const Text('時間割タブから、基本時間割を登録してください。'));
              } else {
                cards.add(DayTimetableCard(title: '今日の時間割', day: today));
                if (today.status != DayStatus.school) {
                  final next = _findNextSchoolDay(resolver, now);
                  if (next != null) {
                    cards.add(const SizedBox(height: 12));
                    cards.add(DayTimetableCard(title: '次の授業日', day: next));
                  }
                }

                // 学校のテスト＋塾のテスト（EEVI など）を日付順に
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
                    onTapItem: (item) => _openTestEditor(data, item),
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
          );
        },
      ),
    );
  }
}
