import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:material_ui/material_ui.dart';

import '../events/calendar_event.dart';
import '../events/event_repository.dart';
import '../belongings/belongings.dart';
import '../belongings/belongings_repository.dart';
import '../recurring/recurring_repository.dart';
import '../recurring/recurring_schedule.dart';
import '../recurring/recurring_test_rule.dart';
import '../school_tests/upcoming_tests.dart';
import '../settings/app_settings.dart';
import '../settings/settings_scope.dart';
import '../timetable/timetable_repository.dart';
import '../todo/todo.dart';
import '../todo/todo_repository.dart';
import 'notification_planner.dart';
import 'notification_service.dart';

class NotificationSync extends StatefulWidget {
  const NotificationSync({super.key, required this.child});
  final Widget child;

  @override
  State<NotificationSync> createState() => _NotificationSyncState();
}

class _NotificationSyncState extends State<NotificationSync> {
  StreamSubscription<User?>? _auth;
  final List<StreamSubscription<dynamic>> _subs = [];
  Timer? _debounce;

  TimetableData? _data;
  List<CalendarEvent> _events = const [];
  List<RecurringSchedule> _recurring = const [];
  List<Todo> _todos = const [];
  BelongingSettings _belongings = const BelongingSettings();
  AppSettings _settings = const AppSettings();

  @override
  void initState() {
    super.initState();
    if (kIsWeb) return;
    _auth = FirebaseAuth.instance.authStateChanges().listen(_onUser);
  }

  /// 設定が変わったら、通知も予約し直す
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (kIsWeb) return;
    final next = SettingsScope.of(context);
    if (!mapEquals(next.toMap(), _settings.toMap())) {
      _settings = next;
      _debounce?.cancel();
      _debounce = Timer(const Duration(seconds: 2), _reschedule);
    }
  }

  Future<void> _onUser(User? user) async {
    for (final s in _subs) {
      await s.cancel();
    }
    _subs.clear();
    if (user == null) {
      await NotificationService.instance.cancelAll();
      return;
    }
    final uid = user.uid;
    _subs.addAll([
      TimetableRepository(uid: uid)
          .watch()
          .listen((d) => _set(() => _data = d)),
      EventRepository(uid: uid)
          .watchAll()
          .listen((e) => _set(() => _events = e)),
      RecurringRepository(uid: uid)
          .watch()
          .listen((r) => _set(() => _recurring = r)),
      TodoRepository(uid: uid).watch().listen((t) => _set(() => _todos = t)),
      BelongingsRepository(uid: uid)
          .watchSettings()
          .listen((b) => _set(() => _belongings = b)),
    ]);
  }

  /// 変化があったら、2秒待ってからまとめて予約し直す
  void _set(VoidCallback update) {
    update();
    _debounce?.cancel();
    _debounce = Timer(const Duration(seconds: 2), _reschedule);
  }

  Future<void> _reschedule() async {
    final data = _data;
    if (data == null || !data.isSeeded) return;
    final now = DateTime.now();
    const days = 14;
    final plan = planNotifications(
      now: now,
      days: days,
      resolver: data.resolver,
      upcoming: [
        ...collectUpcoming(
          from: now,
          days: days + 1,
          resolver: data.baseResolver,
          rules: data.activeRules,
          schoolTests: data.schoolTests,
        ),
        ...upcomingRecurringTests(_recurring, now, days + 1),
      ],
      events: [
        ..._events,
        ...expandRecurringWithTests(
          _recurring,
          now,
          DateTime(now.year, now.month, now.day + days + 1),
        ),
      ],
      settings: _settings,
      todos: mergeTodos(_todos, data.schoolTests),
      belongingsOn: (d) => belongingsFor(
        day: data.resolver.resolve(d),
        recurring: _recurring,
        settings: _belongings,
        events: _events,
      ),
    );
    await NotificationService.instance.setTimeZone(_settings.timeZone);
    await NotificationService.instance.replaceAll(
      plan,
      sound: _settings.notificationSound,
    );
  }

  @override
  void dispose() {
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
