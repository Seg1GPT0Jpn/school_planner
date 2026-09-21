/// レビュー・テストカルテ・学校イベントで使うデータを、まとめて読む係
///
/// 画面ごとに「必要なものだけ」読むので、Firestore の読み込みを増やしすぎない。
library;

import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:material_ui/material_ui.dart';

import '../belongings/belongings.dart';
import '../belongings/belongings_repository.dart';
import '../events/calendar_event.dart';
import '../events/event_repository.dart';
import '../goals/goal.dart';
import '../goals/goal_repository.dart';
import '../grades/grade.dart';
import '../grades/grade_repository.dart';
import '../recurring/recurring_repository.dart';
import '../recurring/recurring_schedule.dart';
import '../study/study.dart';
import '../study/study_repository.dart';
import '../timetable/timetable_repository.dart';
import '../todo/todo.dart';
import '../todo/todo_repository.dart';
import 'review_models.dart';
import 'review_repository.dart';

/// 読むもの
enum DataPart {
  timetable,
  recurring,
  todos,
  goals,
  reflections,
  events,
  study,
  grades,
  testReviews,
  belongings,
}

/// 読んだものの、いまの中身
class TsuzuriSnapshot {
  const TsuzuriSnapshot({
    this.timetable,
    this.recurring = const [],
    this.todos = const [],
    this.goals = const [],
    this.reflections = const [],
    this.events = const [],
    this.sessions = const [],
    this.exams = const [],
    this.testReviews = const {},
    this.belongings = const BelongingSettings(),
  });

  final TimetableData? timetable;
  final List<RecurringSchedule> recurring;

  /// 自分で作った ToDo（提出物などから作るものは [allTodos]）
  final List<Todo> todos;
  final List<Goal> goals;
  final List<Reflection> reflections;
  final List<CalendarEvent> events;
  final List<StudySession> sessions;
  final List<Exam> exams;
  final Map<String, TestReview> testReviews;
  final BelongingSettings belongings;

  /// 自分の ToDo ＋ 提出物などから作る ToDo（期限が近い順）
  List<Todo> get allTodos =>
      sortTodos(mergeTodos(todos, timetable?.schoolTests ?? const []));

  TsuzuriSnapshot copyWith({
    TimetableData? timetable,
    List<RecurringSchedule>? recurring,
    List<Todo>? todos,
    List<Goal>? goals,
    List<Reflection>? reflections,
    List<CalendarEvent>? events,
    List<StudySession>? sessions,
    List<Exam>? exams,
    Map<String, TestReview>? testReviews,
    BelongingSettings? belongings,
  }) => TsuzuriSnapshot(
    timetable: timetable ?? this.timetable,
    recurring: recurring ?? this.recurring,
    todos: todos ?? this.todos,
    goals: goals ?? this.goals,
    reflections: reflections ?? this.reflections,
    events: events ?? this.events,
    sessions: sessions ?? this.sessions,
    exams: exams ?? this.exams,
    testReviews: testReviews ?? this.testReviews,
    belongings: belongings ?? this.belongings,
  );
}

class TsuzuriDataBuilder extends StatefulWidget {
  const TsuzuriDataBuilder({
    super.key,
    required this.parts,
    required this.builder,
  });

  final Set<DataPart> parts;
  final Widget Function(BuildContext context, TsuzuriSnapshot data) builder;

  @override
  State<TsuzuriDataBuilder> createState() => _TsuzuriDataBuilderState();
}

class _TsuzuriDataBuilderState extends State<TsuzuriDataBuilder> {
  final _subs = <StreamSubscription<dynamic>>[];
  var _data = const TsuzuriSnapshot();
  Object? _error;

  @override
  void initState() {
    super.initState();
    final uid = FirebaseAuth.instance.currentUser!.uid;
    final p = widget.parts;
    void on<T>(Stream<T> s, TsuzuriSnapshot Function(T v) apply) => _subs.add(
      s.listen(
        (v) => setState(() => _data = apply(v)),
        onError: (Object e) => setState(() => _error = e),
      ),
    );

    final goals = GoalRepository(uid: uid);
    if (p.contains(DataPart.timetable)) {
      on(
        TimetableRepository(uid: uid).watch(),
        (v) => _data.copyWith(timetable: v),
      );
    }
    if (p.contains(DataPart.recurring)) {
      on(
        RecurringRepository(uid: uid).watch(),
        (v) => _data.copyWith(recurring: v),
      );
    }
    if (p.contains(DataPart.todos)) {
      on(TodoRepository(uid: uid).watch(), (v) => _data.copyWith(todos: v));
    }
    if (p.contains(DataPart.goals)) {
      on(goals.watchGoals(), (v) => _data.copyWith(goals: v));
    }
    if (p.contains(DataPart.reflections)) {
      on(goals.watchReflections(), (v) => _data.copyWith(reflections: v));
    }
    if (p.contains(DataPart.events)) {
      on(
        EventRepository(uid: uid).watchAll(),
        (v) => _data.copyWith(events: v),
      );
    }
    if (p.contains(DataPart.study)) {
      on(
        StudyRepository(uid: uid).watchSessions(),
        (v) => _data.copyWith(sessions: v),
      );
    }
    if (p.contains(DataPart.grades)) {
      on(GradeRepository(uid: uid).watch(), (v) => _data.copyWith(exams: v));
    }
    if (p.contains(DataPart.testReviews)) {
      on(
        ReviewRepository(uid: uid).watchTestReviews(),
        (v) => _data.copyWith(testReviews: v),
      );
    }
    if (p.contains(DataPart.belongings)) {
      on(
        BelongingsRepository(uid: uid).watchSettings(),
        (v) => _data.copyWith(belongings: v),
      );
    }
  }

  @override
  void dispose() {
    for (final s in _subs) {
      s.cancel();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_error != null) {
      return Center(child: Text('読み込みに失敗しました\n$_error'));
    }
    if (widget.parts.contains(DataPart.timetable) && _data.timetable == null) {
      return const Center(child: CircularProgressIndicator());
    }
    return widget.builder(context, _data);
  }
}
