import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/date_format.dart';
import '../events/calendar_event.dart';
import '../events/event_category.dart';
import '../events/event_category_repository.dart';
import '../events/event_edit_page.dart';
import '../events/event_repository.dart';
import '../school_tests/school_test.dart';
import '../school_tests/school_test_edit_page.dart';
import '../school_tests/school_test_repository.dart';
import '../timetable/day_timetable_resolver.dart';
import '../timetable/lesson_change_dialog.dart';
import '../timetable/timetable_models.dart';
import '../timetable/timetable_repository.dart';
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

/// 表示の状態（どの表示で、どの日を見ているか）
class _ViewState {
  const _ViewState(this.mode, this.focused);

  final CalendarMode mode;
  final DateTime focused;
}

/// カレンダータブ
class CalendarPage extends StatefulWidget {
  const CalendarPage({super.key});

  @override
  State<CalendarPage> createState() => _CalendarPageState();
}

class _CalendarPageState extends State<CalendarPage> {
  late final TimetableRepository _timetableRepository;
  late final EventRepository _eventRepository;
  late final EventCategoryRepository _categoryRepository;
  late final SchoolTestRepository _testRepository;

  late final Stream<TimetableData> _timetableStream;
  late final Stream<List<CalendarEvent>> _eventStream;
  late final Stream<List<EventCategory>> _categoryStream;

  /// 最後に読み込んだ時間割データ（科目一覧に使う）
  TimetableData? _latestData;

  CalendarMode _mode = CalendarMode.month;

  /// 今見ている日（月表示ではその月、週表示ではその週を表す）
  DateTime _focused = _today();

  /// 表示の履歴（戻る・進む）
  final List<_ViewState> _backHistory = [];
  final List<_ViewState> _forwardHistory = [];

  /// 履歴を残す最大の数
  static const int _maxHistory = 50;

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
    final uid = FirebaseAuth.instance.currentUser!.uid;

    _timetableRepository = TimetableRepository(uid: uid);
    _eventRepository = EventRepository(uid: uid);
    _categoryRepository = EventCategoryRepository(uid: uid);
    _testRepository = SchoolTestRepository(uid: uid);

    _timetableStream = _timetableRepository.watch();
    _eventStream = _eventRepository.watchAll();
    _categoryStream = _categoryRepository.watch();

    // 初期値がまだなければ登録しておく
    _categoryRepository.ensureDefaults();
    _testRepository.ensureDefaultRules();
  }

  // ------------------------------------------------------------
  // 表示の切り替えと履歴
  // ------------------------------------------------------------

  /// 表示を切り替える（今の表示を「戻る」の履歴に残す）
  void _changeView(CalendarMode mode, DateTime focused) {
    if (mode == _mode && focused == _focused) return;

    setState(() {
      _backHistory.add(_ViewState(_mode, _focused));
      if (_backHistory.length > _maxHistory) _backHistory.removeAt(0);
      _forwardHistory.clear(); // 新しく動いたら「進む」の履歴は消える
      _mode = mode;
      _focused = focused;
    });
  }

  /// ← 前の表示に戻る
  void _goBack() {
    if (_backHistory.isEmpty) return;
    setState(() {
      _forwardHistory.add(_ViewState(_mode, _focused));
      final previous = _backHistory.removeLast();
      _mode = previous.mode;
      _focused = previous.focused;
    });
  }

  /// → 次の表示へ進む（戻る前の表示にやり直す）
  void _goForward() {
    if (_forwardHistory.isEmpty) return;
    setState(() {
      _backHistory.add(_ViewState(_mode, _focused));
      final next = _forwardHistory.removeLast();
      _mode = next.mode;
      _focused = next.focused;
    });
  }

  /// ‹ 前へ（-1）・› 次へ（+1）：前後の月・週・日へ
  void _move(int delta) {
    final f = _focused;
    final target = switch (_mode) {
      CalendarMode.month => DateTime(f.year, f.month + delta, 1),
      CalendarMode.week => DateTime(f.year, f.month, f.day + 7 * delta),
      CalendarMode.day => DateTime(f.year, f.month, f.day + delta),
    };
    _changeView(_mode, target);
  }

  void _goToday() => _changeView(_mode, _today());

  /// 月表示で日付をタップしたら、その日の日表示へ
  void _openDay(DateTime date) => _changeView(CalendarMode.day, date);

  // ------------------------------------------------------------
  // 予定・小テスト・時間割の変更
  // ------------------------------------------------------------

  /// 予定の入力画面を開く（event があれば編集、なければ追加）
  void _openEditor({CalendarEvent? event, DateTime? start}) {
    Navigator.of(context, rootNavigator: true).push(
      MaterialPageRoute<void>(
        fullscreenDialog: true,
        builder: (_) => EventEditPage(
          repository: _eventRepository,
          categoryRepository: _categoryRepository,
          event: event,
          initialStart: start,
        ),
      ),
    );
  }

  /// 小テスト・学校イベントの入力画面を開く
  void _openTestEditor({
    SchoolTest? test,
    DateTime? date,
    String? subject,
    int? period,
  }) {
    Navigator.of(context, rootNavigator: true).push(
      MaterialPageRoute<void>(
        fullscreenDialog: true,
        builder: (_) => SchoolTestEditPage(
          repository: _testRepository,
          subjects: _latestData?.subjects ?? const [],
          test: test,
          initialDate: date,
          initialSubject: subject,
          initialPeriod: period,
        ),
      ),
    );
  }

  /// この日だけ科目を変える・休講にする・元に戻す（試験日課の日は試験科目）
  Future<void> _changeLesson(
    DateTime date,
    ResolvedLesson lesson,
    bool isExamDay,
  ) async {
    final result = await showDialog<LessonChangeResult>(
      context: context,
      builder: (_) => LessonChangeDialog(
        subjects: _latestData?.subjects ?? const [],
        lesson: lesson,
        isExamDay: isExamDay,
      ),
    );
    if (result == null) return;

    switch (result.action) {
      case LessonChangeAction.setSubject:
        await _timetableRepository.setPeriodChange(
          date,
          PeriodChange.replace(period: lesson.period, subject: result.subject),
        );
      case LessonChangeAction.cancel:
        await _timetableRepository.setPeriodChange(
          date,
          PeriodChange.cancel(period: lesson.period),
        );
      case LessonChangeAction.reset:
        await _timetableRepository.clearPeriodChange(date, lesson.period);
    }
  }

  /// 週・日表示に渡す、授業に関する操作
  LessonTestActions get _testActions => LessonTestActions(
    onAdd: (date, lesson) => _openTestEditor(
      date: date,
      subject: lesson.subject,
      period: lesson.period,
    ),
    onEdit: (test) => _openTestEditor(test: test),
    onSetWeekSkipped: (rule, date, skipped) =>
        _testRepository.setWeekSkipped(rule.id, date, skipped),
    onChangeLesson: _changeLesson,
  );

  /// ＋ボタン：予定か、小テスト・学校イベントかを選ぶ
  void _showAddMenu() {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.event),
                title: const Text('予定を追加'),
                onTap: () {
                  Navigator.of(sheetContext).pop();
                  _createEvent();
                },
              ),
              ListTile(
                leading: const Icon(Icons.edit_note),
                title: const Text('小テスト・学校イベントを追加'),
                onTap: () {
                  Navigator.of(sheetContext).pop();
                  _openTestEditor(date: _focused);
                },
              ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  }

  /// 予定を追加
  ///   今日を見ているときは次の正時（例：16:40 → 17:00）、
  ///   それ以外の日は 9:00 から始まる予定を用意する
  void _createEvent() {
    final isToday = _focused == _today();
    final now = DateTime.now();
    final start = isToday
        ? DateTime(now.year, now.month, now.day, now.hour + 1)
        : DateTime(_focused.year, _focused.month, _focused.day, 9);
    _openEditor(start: start);
  }

  // ------------------------------------------------------------
  // 表示用
  // ------------------------------------------------------------

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

  /// ‹ › の説明（「前の月へ」など）
  String get _unitLabel => switch (_mode) {
    CalendarMode.month => '月',
    CalendarMode.week => '週',
    CalendarMode.day => '日',
  };

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
    // キーボードの操作（Ctrl+Z / Ctrl+Y、Alt+← / Alt+→）
    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.keyZ, control: true): _goBack,
        const SingleActivator(LogicalKeyboardKey.keyY, control: true):
            _goForward,
        const SingleActivator(LogicalKeyboardKey.arrowLeft, alt: true): _goBack,
        const SingleActivator(LogicalKeyboardKey.arrowRight, alt: true):
            _goForward,
      },
      child: Focus(
        autofocus: true,
        child: Scaffold(
          floatingActionButton: FloatingActionButton(
            tooltip: '追加',
            onPressed: _showAddMenu,
            child: const Icon(Icons.add),
          ),
          appBar: AppBar(
            // ← 前の表示に戻る
            leading: IconButton(
              icon: const Icon(Icons.arrow_back),
              tooltip: '前の表示に戻る（Ctrl+Z）',
              onPressed: _backHistory.isEmpty ? null : _goBack,
            ),
            title: const Text('カレンダー'),
            actions: [
              // → 次の表示へ進む
              IconButton(
                icon: const Icon(Icons.arrow_forward),
                tooltip: '次の表示へ進む（Ctrl+Y）',
                onPressed: _forwardHistory.isEmpty ? null : _goForward,
              ),
              TextButton(onPressed: _goToday, child: const Text('今日')),
              const SizedBox(width: 8),
            ],
          ),
          body: StreamBuilder<TimetableData>(
            stream: _timetableStream,
            builder: (context, timetableSnapshot) {
              if (timetableSnapshot.hasError) {
                return Center(
                  child: Text('読み込みに失敗しました\n${timetableSnapshot.error}'),
                );
              }
              if (!timetableSnapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }
              final data = timetableSnapshot.data!;
              _latestData = data;

              return StreamBuilder<List<CalendarEvent>>(
                stream: _eventStream,
                builder: (context, eventSnapshot) {
                  final events = eventSnapshot.data ?? const <CalendarEvent>[];

                  return StreamBuilder<List<EventCategory>>(
                    stream: _categoryStream,
                    builder: (context, categorySnapshot) {
                      final categories =
                          categorySnapshot.data ?? defaultEventCategories;

                      Color colorOf(CalendarEvent e) => Color(
                        findCategory(categories, e.categoryId).colorValue,
                      );

                      return _buildBody(context, data, events, colorOf);
                    },
                  );
                },
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildBody(
    BuildContext context,
    TimetableData data,
    List<CalendarEvent> events,
    Color Function(CalendarEvent) colorOf,
  ) {
    final today = _today();

    return Column(
      children: [
        // ‹ 前の月・週・日 ／ 見出し ／ 次の月・週・日 ›
        Padding(
          padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
          child: Row(
            children: [
              IconButton(
                icon: const Icon(Icons.chevron_left),
                tooltip: '前の$_unitLabelへ',
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
                tooltip: '次の$_unitLabelへ',
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
              _changeView(selection.first, _focused);
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
                events: events,
                colorOf: colorOf,
                onDayTap: _openDay,
              ),
              CalendarMode.week => TimeGridView(
                data: data,
                days: _weekDays,
                today: today,
                events: events,
                colorOf: colorOf,
                onCreateAt: (start) => _openEditor(start: start),
                onEventTap: (event) => _openEditor(event: event),
                testActions: _testActions,
              ),
              CalendarMode.day => TimeGridView(
                data: data,
                days: [_focused],
                today: today,
                events: events,
                colorOf: colorOf,
                onCreateAt: (start) => _openEditor(start: start),
                onEventTap: (event) => _openEditor(event: event),
                testActions: _testActions,
              ),
            },
          ),
        ),
      ],
    );
  }
}
