/// つづりのデータが変わったら、ホーム画面ウィジェットの中身を作り直す（Android のみ）
library;

import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:home_widget/home_widget.dart';
import 'package:material_ui/material_ui.dart';

import '../events/calendar_event.dart';
import '../events/event_repository.dart';
import '../recurring/recurring_repository.dart';
import '../recurring/recurring_schedule.dart';
import '../recurring/recurring_test_rule.dart';
import '../timetable/subject_colors.dart';
import '../timetable/timetable_repository.dart';
import 'widget_text.dart';

/// ウィジェットに入れておく日数（アプリを開かなくても、この日数分は正しく出る）
const int widgetDays = 7;

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
    final from = DateTime(now.year, now.month, now.day);
    final to = DateTime(now.year, now.month, now.day + widgetDays);
    final events = [
      ..._events,
      ...expandRecurringWithTests(_recurring, from, to),
    ];
    final colors = {
      for (final s in data.subjects)
        s.name: _custom[s.category] ?? categoryColor(s.category).toARGB32(),
    };
    final resolver = data.resolver;

    try {
      for (var i = 0; i < widgetDays; i++) {
        final d = DateTime(now.year, now.month, now.day + i);
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
      await HomeWidget.updateWidget(androidName: 'TsuzuriWidgetProvider');
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
