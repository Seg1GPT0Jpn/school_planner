import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/date_format.dart';
import '../events/calendar_event.dart';
import '../events/event_category.dart';
import '../events/event_category_repository.dart';
import '../events/event_edit_page.dart';
import '../events/event_repository.dart';
import '../recurring/recurring_pages.dart';
import '../recurring/recurring_repository.dart';
import '../recurring/recurring_schedule.dart';
import '../recurring/recurring_test_rule.dart';
import '../school_tests/school_test.dart';
import '../school_tests/school_test_edit_page.dart';
import '../school_tests/school_test_repository.dart';
import '../timetable/day_timetable_resolver.dart';
import '../timetable/lesson_change_dialog.dart';
import '../timetable/timetable_models.dart';
import '../timetable/timetable_repository.dart';
import 'month_view.dart';
import 'time_grid.dart';

enum CalendarMode {
  month('月'),
  week('週'),
  day('日');

  const CalendarMode(this.label);
  final String label;
}

class _ViewState {
  const _ViewState(this.mode, this.focused);
  final CalendarMode mode;
  final DateTime focused;
}

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
  late final Stream<List<RecurringSchedule>> _recurringStream;

  TimetableData? _latestData;

  CalendarMode _mode = CalendarMode.month;
  DateTime _focused = _today();

  final List<_ViewState> _backHistory = [];
  final List<_ViewState> _forwardHistory = [];
  static const int _maxHistory = 50;

  static DateTime _today() {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day);
  }

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
    _recurringStream = RecurringRepository(uid: uid).watch();

    _categoryRepository.ensureDefaults();
    _testRepository.ensureDefaultRules();
  }

  // ---------------- 表示の切り替えと履歴 ----------------

  void _changeView(CalendarMode mode, DateTime focused) {
    if (mode == _mode && focused == _focused) return;
    setState(() {
      _backHistory.add(_ViewState(_mode, _focused));
      if (_backHistory.length > _maxHistory) _backHistory.removeAt(0);
      _forwardHistory.clear();
      _mode = mode;
      _focused = focused;
    });
  }

  void _goBack() {
    if (_backHistory.isEmpty) return;
    setState(() {
      _forwardHistory.add(_ViewState(_mode, _focused));
      final p = _backHistory.removeLast();
      _mode = p.mode;
      _focused = p.focused;
    });
  }

  void _goForward() {
    if (_forwardHistory.isEmpty) return;
    setState(() {
      _backHistory.add(_ViewState(_mode, _focused));
      final n = _forwardHistory.removeLast();
      _mode = n.mode;
      _focused = n.focused;
    });
  }

  void _move(int delta) {
    final f = _focused;
    _changeView(_mode, switch (_mode) {
      CalendarMode.month => DateTime(f.year, f.month + delta, 1),
      CalendarMode.week => DateTime(f.year, f.month, f.day + 7 * delta),
      CalendarMode.day => DateTime(f.year, f.month, f.day + delta),
    });
  }

  void _goToday() => _changeView(_mode, _today());
  void _openDay(DateTime date) => _changeView(CalendarMode.day, date);

  // ---------------- 予定・小テスト・時間割の変更 ----------------

  void _openEditor({CalendarEvent? event, DateTime? start}) {
    // 定期の予定から作られたものは、専用のメニューを出す
    if (event != null && isRecurringInstance(event)) {
      showRecurringInstanceSheet(context, event);
      return;
    }
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

  void _showAddMenu() {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) {
        void close(VoidCallback action) {
          Navigator.of(sheetContext).pop();
          action();
        }

        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.event),
                title: const Text('予定を追加'),
                onTap: () => close(_createEvent),
              ),
              ListTile(
                leading: const Icon(Icons.edit_note),
                title: const Text('小テスト・学校イベントを追加'),
                onTap: () => close(() => _openTestEditor(date: _focused)),
              ),
              ListTile(
                leading: const Icon(Icons.repeat),
                title: const Text('塾・部活などの定期の予定'),
                onTap: () => close(() => openRecurringList(context)),
              ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  }

  void _createEvent() {
    final isToday = _focused == _today();
    final now = DateTime.now();
    _openEditor(
      start: isToday
          ? DateTime(now.year, now.month, now.day, now.hour + 1)
          : DateTime(_focused.year, _focused.month, _focused.day, 9),
    );
  }

  // ---------------- 表示用 ----------------

  List<DateTime> get _weekDays {
    final sunday = _sundayOf(_focused);
    return [
      for (var i = 0; i < 7; i++)
        DateTime(sunday.year, sunday.month, sunday.day + i),
    ];
  }

  String get _heading {
    final f = _focused;
    switch (_mode) {
      case CalendarMode.month:
        return '${f.year}年${f.month}月';
      case CalendarMode.week:
        final d = _weekDays;
        return '${d.first.month}/${d.first.day} 〜 ${d.last.month}/${d.last.day}';
      case CalendarMode.day:
        return formatDateJa(f);
    }
  }

  String get _unitLabel => _mode.label;

  void _onHorizontalSwipe(DragEndDetails details) {
    final v = details.primaryVelocity ?? 0;
    if (v < -300) {
      _move(1);
    } else if (v > 300) {
      _move(-1);
    }
  }

  @override
  Widget build(BuildContext context) {
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
            leading: IconButton(
              icon: const Icon(Icons.arrow_back),
              tooltip: '前の表示に戻る（Ctrl+Z）',
              onPressed: _backHistory.isEmpty ? null : _goBack,
            ),
            title: const Text('カレンダー'),
            actions: [
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
            builder: (context, ts) {
              if (ts.hasError) {
                return Center(child: Text('読み込みに失敗しました\n${ts.error}'));
              }
              if (!ts.hasData) {
                return const Center(child: CircularProgressIndicator());
              }
              final data = ts.data!;
              _latestData = data;

              return StreamBuilder<List<CalendarEvent>>(
                stream: _eventStream,
                builder: (context, es) {
                  return StreamBuilder<List<EventCategory>>(
                    stream: _categoryStream,
                    builder: (context, cs) {
                      return StreamBuilder<List<RecurringSchedule>>(
                        stream: _recurringStream,
                        builder: (context, rs) {
                          final categories = cs.data ?? defaultEventCategories;
                          Color colorOf(CalendarEvent e) => Color(
                            findCategory(categories, e.categoryId).colorValue,
                          );

                          // 予定＋定期の予定（表示している月の前後を展開）
                          final events = [
                            ...?es.data,
                            ...expandRecurringWithTests(
                              rs.data ?? const [],
                              DateTime(_focused.year, _focused.month - 1, 1),
                              DateTime(_focused.year, _focused.month + 2, 1),
                            ),
                          ];

                          return _buildBody(context, data, events, colorOf);
                        },
                      );
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
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: SegmentedButton<CalendarMode>(
            segments: [
              for (final m in CalendarMode.values)
                ButtonSegment(value: m, label: Text(m.label)),
            ],
            selected: {_mode},
            showSelectedIcon: false,
            onSelectionChanged: (s) => _changeView(s.first, _focused),
          ),
        ),
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
              CalendarMode.week || CalendarMode.day => TimeGridView(
                data: data,
                days: _mode == CalendarMode.week ? _weekDays : [_focused],
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
