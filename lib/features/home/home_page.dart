import 'package:firebase_auth/firebase_auth.dart';
import 'package:material_ui/material_ui.dart';

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

  @override
  void initState() {
    super.initState();
    _timetableStream = TimetableRepository(
      uid: FirebaseAuth.instance.currentUser!.uid,
    ).watch();
  }

  /// 確認してからログアウトする
  Future<void> _confirmSignOut(BuildContext context) async {
    final shouldSignOut = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('ログアウトしますか？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('キャンセル'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('ログアウト'),
          ),
        ],
      ),
    );

    if (shouldSignOut == true) {
      await FirebaseAuth.instance.signOut();
    }
  }

  /// 今日より後で、最初に授業がある日を探す（最大30日先まで）
  DayTimetable? _findNextSchoolDay(
    DayTimetableResolver resolver,
    DateTime from,
  ) {
    for (var i = 1; i <= 30; i++) {
      final day = resolver.resolve(from.add(Duration(days: i)));
      if (day.status == DayStatus.school) return day;
    }
    return null;
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
    );
  }
}
