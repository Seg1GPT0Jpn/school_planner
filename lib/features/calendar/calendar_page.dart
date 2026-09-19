import 'package:firebase_auth/firebase_auth.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/date_format.dart';
import '../timetable/timetable_repository.dart';
import '../events/event_category_repository.dart';
import '../events/event_edit_page.dart';
import '../events/event_repository.dart';
import 'month_view.dart';
import 'time_grid.dart';

/// カレンダーの表示の種類
enum CalendarMode {
  month('月'),
  week('週'),
  day('日');

  const CalendarMode(this.label);
  final String label;
}

/// カレンダータブ
class CalendarPage extends StatefulWidget {
  const CalendarPage({super.key});

  @override
  State<CalendarPage> createState() => _CalendarPageState();
}

class _CalendarPageState extends State<CalendarPage> {
  late final Stream<TimetableData> _stream;

  CalendarMode _mode = CalendarMode.month;

  /// 今見ている日（月表示ではその月、週表示ではその週を表す）
  DateTime _focused = _today();

  static DateTime _today() {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day);
  }

  /// その日を含む週の日曜日
  static DateTime _sundayOf(DateTime date) =>
      DateTime(date.year, date.month, date.day - (date.weekday % 7));

  @override
  void initState() {
    super.initState();
    _stream = TimetableRepository(uid: FirebaseAuth.instance.currentUser!.uid)
        .watch();
    // 予定のカテゴリがまだなければ、最初の6つを登録しておく
    EventCategoryRepository(uid: FirebaseAuth.instance.currentUser!.uid)
        .ensureDefaults();
  }

  /// 前へ（-1）・次へ（+1）
  void _move(int delta) {
    setState(() {
      final f = _focused;
      _focused = switch (_mode) {
        CalendarMode.month => DateTime(f.year, f.month + delta, 1),
        CalendarMode.week => DateTime(f.year, f.month, f.day + 7 * delta),
        CalendarMode.day => DateTime(f.year, f.month, f.day + delta),
      };
    });
  }

  void _goToday() => setState(() => _focused = _today());

  /// 予定の追加画面を開く
  ///   今日を見ているときは次の正時（例：16:40 → 17:00）、
  ///   それ以外の日は 9:00 から始まる予定を用意する
  void _createEvent() {
    final today = _today();
    final isToday = _focused == today;
    final now = DateTime.now();
    final start = isToday
        ? DateTime(now.year, now.month, now.day, now.hour + 1)
        : DateTime(_focused.year, _focused.month, _focused.day, 9);

    Navigator.of(context, rootNavigator: true).push(
      MaterialPageRoute<void>(
        fullscreenDialog: true,
        builder: (_) => EventEditPage(
          repository: EventRepository(
            uid: FirebaseAuth.instance.currentUser!.uid,
          ),
          categoryRepository: EventCategoryRepository(
            uid: FirebaseAuth.instance.currentUser!.uid,
          ),
          initialStart: start,
        ),
      ),
    );
  }

  /// 月表示で日付をタップしたら、その日の日表示へ
  void _openDay(DateTime date) {
    setState(() {
      _focused = date;
      _mode = CalendarMode.day;
    });
  }

  /// 週表示で表示する7日（日〜土）
  List<DateTime> get _weekDays {
    final sunday = _sundayOf(_focused);
    return [
      for (var i = 0; i < 7; i++)
        DateTime(sunday.year, sunday.month, sunday.day + i),
    ];
  }

  /// 上部に出す見出し
  String get _heading {
    final f = _focused;
    switch (_mode) {
      case CalendarMode.month:
        return '${f.year}年${f.month}月';
      case CalendarMode.week:
        final days = _weekDays;
        final first = days.first;
        final last = days.last;
        return '${first.month}/${first.day} 〜 ${last.month}/${last.day}';
      case CalendarMode.day:
        return formatDateJa(f);
    }
  }

  /// 左右のスワイプで前後へ移動する
  void _onHorizontalSwipe(DragEndDetails details) {
    final velocity = details.primaryVelocity ?? 0;
    if (velocity < -300) {
      _move(1); // 左へスワイプ → 次へ
    } else if (velocity > 300) {
      _move(-1); // 右へスワイプ → 前へ
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      floatingActionButton: FloatingActionButton(
        tooltip: '予定を追加',
        onPressed: _createEvent,
        child: const Icon(Icons.add),
      ),
      appBar: AppBar(
        title: const Text('カレンダー'),
        actions: [
          TextButton(onPressed: _goToday, child: const Text('今日')),
          const SizedBox(width: 8),
        ],
      ),
      body: StreamBuilder<TimetableData>(
        stream: _stream,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text('読み込みに失敗しました\n${snapshot.error}'));
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final data = snapshot.data!;
          final today = _today();

          return Column(
            children: [
              // 前へ・見出し・次へ
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.chevron_left),
                      tooltip: '前へ',
                      onPressed: () => _move(-1),
                    ),
                    Expanded(
                      child: Text(
                        _heading,
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.chevron_right),
                      tooltip: '次へ',
                      onPressed: () => _move(1),
                    ),
                  ],
                ),
              ),

              // 月・週・日の切り替え
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: SegmentedButton<CalendarMode>(
                  segments: [
                    for (final mode in CalendarMode.values)
                      ButtonSegment(value: mode, label: Text(mode.label)),
                  ],
                  selected: {_mode},
                  showSelectedIcon: false,
                  onSelectionChanged: (selection) {
                    setState(() => _mode = selection.first);
                  },
                ),
              ),

              // 表示本体（左右スワイプで前後へ）
              Expanded(
                child: GestureDetector(
                  onHorizontalDragEnd: _onHorizontalSwipe,
                  child: switch (_mode) {
                    CalendarMode.month => MonthView(
                      data: data,
                      month: _focused,
                      today: today,
                      onDayTap: _openDay,
                    ),
                    CalendarMode.week => TimeGridView(
                      data: data,
                      days: _weekDays,
                      today: today,
                    ),
                    CalendarMode.day => TimeGridView(
                      data: data,
                      days: [_focused],
                      today: today,
                    ),
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
