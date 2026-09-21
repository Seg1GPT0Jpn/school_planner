/// つづりのデータが変わったら、ホーム画面ウィジェットの中身を作り直す（Android のみ）
library;

import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:home_widget/home_widget.dart';
import 'package:material_ui/material_ui.dart';

import '../calendar/schedule_items.dart';
import '../events/calendar_event.dart';
import '../events/event_category.dart';
import '../events/event_category_repository.dart';
import '../events/event_repository.dart';
import '../google_calendar/google_sync.dart';
import '../recurring/recurring_repository.dart';
import '../recurring/recurring_schedule.dart';
import '../recurring/recurring_test_rule.dart';
import '../timetable/subject_colors.dart';
import '../timetable/timetable_repository.dart';
import 'widget_text.dart';

/// 「今日の時間割」ウィジェットに入れておく日数
const int widgetDays = 7;

/// 「スケジュール」ウィジェットに入れておく日数
const int widgetScheduleDays = 45;

/// ウィジェットの種類（Android の受け取り側の名前）
const _providers = [
  'TsuzuriWidgetProvider',
  'TsuzuriScheduleWidgetProvider',
  'TsuzuriMonthWidgetProvider',
];

bool get _isAndroid =>
    !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

class WidgetSync extends StatefulWidget {
  const WidgetSync({super.key, required this.child});

  final Widget child;

  @override
  State<WidgetSync> createState() => _WidgetSyncState();
}

class _WidgetSyncState extends State<WidgetSync> with WidgetsBindingObserver {
  StreamSubscription<User?>? _auth;
  final _subs = <StreamSubscription<dynamic>>[];
  Timer? _debounce;

  TimetableData? _data;
  List<CalendarEvent> _events = const [];
  List<RecurringSchedule> _recurring = const [];
  List<EventCategory> _categories = defaultEventCategories;

  /// 自分で選んだ教科の色（教科 → 色）
  Map<String, int> _custom = const {};

  @override
  void initState() {
    super.initState();
    if (!_isAndroid) return;
    WidgetsBinding.instance.addObserver(this);
    _auth = FirebaseAuth.instance.authStateChanges().listen(_listen);
  }

  /// 教科の色が変わったときも作り直す
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_isAndroid) return;
    final custom = SubjectColorScope.customColorsOf(context);
    if (!mapEquals(custom, _custom)) {
      _custom = custom;
      _schedule();
    }
  }

  void _listen(User? user) {
    for (final s in _subs) {
      s.cancel();
    }
    _subs.clear();
    if (user == null) return;
    final uid = user.uid;
    _subs.addAll([
      TimetableRepository(uid: uid).watch().listen((d) {
        _data = d;
        _schedule();
      }),
      EventRepository(uid: uid).watchAll().listen((e) {
        _events = e;
        _schedule();
      }),
      RecurringRepository(uid: uid).watch().listen((r) {
        _recurring = r;
        _schedule();
      }),
      EventCategoryRepository(uid: uid).watch().listen((c) {
        _categories = c.isEmpty ? defaultEventCategories : c;
        _schedule();
      }),
    ]);
  }

  /// 続けて変わったときに何度も書かないよう、少し待ってからまとめて更新
  void _schedule() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(seconds: 2), _update);
  }

  Future<void> _update() async {
    final data = _data;
    if (data == null) return;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    // 月ビューは前の月の終わりのマスも出すので、少し前から作る
    final from = DateTime(today.year, today.month, 1 - 6);
    final monthEnd = DateTime(today.year, today.month, 1 + 42);
    final scheduleEnd = today.add(const Duration(days: widgetScheduleDays));
    final to = monthEnd.isAfter(scheduleEnd) ? monthEnd : scheduleEnd;

    final events = [
      ..._events,
      ...expandRecurringWithTests(_recurring, from, to),
    ];
    final colors = {
      for (final s in data.subjects)
        s.name: _custom[s.category] ?? categoryColor(s.category).toARGB32(),
    };
    int colorOf(CalendarEvent e) =>
        (googleEventColor(e) ??
                Color(findCategory(_categories, e.categoryId).colorValue))
            .toARGB32();
    final resolver = data.resolver;

    // 期間ぜんぶの「日付順の一覧」を作る（月ビューとスケジュールで使い回す）
    final all = <ScheduleDay>[];
    for (
      var d = from;
      d.isBefore(to);
      d = DateTime(d.year, d.month, d.day + 1)
    ) {
      all.add(
        buildScheduleDay(
          day: resolver.resolve(d),
          events: events,
          tests: data.testsOn(d),
          colorOf: colorOf,
        ),
      );
    }

    try {
      // ① 今日の時間割ウィジェット
      for (var i = 0; i < widgetDays; i++) {
        final d = DateTime(today.year, today.month, today.day + i);
        final w = buildWidgetDay(
          day: resolver.resolve(d),
          events: events,
          tests: data.testsOn(d),
          subjectColors: colors,
        );
        await HomeWidget.saveWidgetData('day${i}_date', w.date);
        await HomeWidget.saveWidgetData('day${i}_title', w.title);
        await HomeWidget.saveWidgetData('day${i}_message', w.message);
        await HomeWidget.saveWidgetData('day${i}_lessons', w.encodedLessons);
        await HomeWidget.saveWidgetData('day${i}_extra', w.extra);
      }

      // ② スケジュールウィジェット（今日から先だけ）
      final lines = buildWidgetSchedule(
        days: [
          for (final s in all)
            if (!s.date.isBefore(today)) s,
        ],
        today: today,
      );
      await HomeWidget.saveWidgetData('sch_count', lines.length);
      await HomeWidget.saveWidgetData('sch_lines', encodeScheduleLines(lines));

      // ③ 月ビューウィジェット
      final month = buildWidgetMonth(month: today, today: today, days: all);
      await HomeWidget.saveWidgetData('mon_title', month.title);
      await HomeWidget.saveWidgetData('mon_weekdays', month.encodedWeekdays);
      await HomeWidget.saveWidgetData('mon_cells', month.encodedCells);

      for (final name in _providers) {
        try {
          await HomeWidget.updateWidget(androidName: name);
        } catch (e) {
          debugPrint('【ウィジェット】$name の更新に失敗：$e');
        }
      }
    } catch (e) {
      debugPrint('【ウィジェット】更新に失敗：$e');
    }
  }

  /// アプリを開き直したとき（日付が変わっているかもしれない）
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _schedule();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _debounce?.cancel();
    _auth?.cancel();
    for (final s in _subs) {
      s.cancel();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
