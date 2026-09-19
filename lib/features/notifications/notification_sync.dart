import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:material_ui/material_ui.dart';

import '../events/calendar_event.dart';
import '../events/event_repository.dart';
import '../recurring/recurring_repository.dart';
import '../recurring/recurring_schedule.dart';
import '../recurring/recurring_test_rule.dart';
import '../school_tests/upcoming_tests.dart';
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

  @override
  void initState() {
    super.initState();
    if (kIsWeb) return;
    _auth = FirebaseAuth.instance.authStateChanges().listen(_onUser);
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
    ]);
  }

  /// 変化があったら、2秒待ってからまとめて予約し直す
  void _set(VoidCallback update) {
    update();
    _debounce?.cancel();
    _debounce = Timer(const Duration(seconds: 2), _reschedule);
  }

  void _reschedule() {
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
      todos: mergeTodos(_todos, data.schoolTests),
    );
    NotificationService.instance.replaceAll(plan);
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
