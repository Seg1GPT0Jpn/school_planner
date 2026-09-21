/// 週・月・学期のレビューの集計（画面に依存しない計算だけ）
library;

import '../events/calendar_event.dart';
import '../goals/goal.dart';
import '../goals/goal_repository.dart';
import '../grades/grade.dart';
import '../school_tests/upcoming_tests.dart';
import '../study/study.dart';
import '../todo/todo.dart';
import 'period.dart';
import 'review_models.dart';

/// レビューに出す点数1つ
class ReviewScore {
  const ReviewScore({
    required this.title,
    required this.date,
    required this.score,
    required this.max,
    this.subject,
    this.fromGrades = false,
  });

  final String title;
  final DateTime date;
  final num score;
  final num max;
  final String? subject;

  /// 「成績」に記録したものか（false ならテストカルテで入れたもの）
  final bool fromGrades;

  double get percent => max <= 0 ? 0 : score / max * 100;
}

class ReviewSummary {
  const ReviewSummary({
    required this.period,
    required this.studyMinutes,
    required this.previousStudyMinutes,
    required this.studyBySubject,
    required this.dailyStudy,
    required this.todosDone,
    required this.todosLeft,
    required this.tests,
    required this.scores,
    required this.goals,
    required this.goalsAchieved,
    required this.events,
    required this.reflections,
    required this.nextTests,
    required this.nextTodos,
    required this.nextEvents,
  });

  final ReviewPeriod period;

  // 勉強
  final int studyMinutes;
  final int previousStudyMinutes;
  final List<MapEntry<String, int>> studyBySubject;

  /// 期間の毎日の合計（古い順）
  final List<int> dailyStudy;

  // ToDo（期限がこの期間のもの）
  final List<Todo> todosDone;
  final List<Todo> todosLeft;

  // テストと点数
  final List<UpcomingItem> tests;
  final List<ReviewScore> scores;

  // 目標（期限がこの期間のもの）
  final List<Goal> goals;
  final int goalsAchieved;

  // 予定
  final List<CalendarEvent> events;

  // 毎日のふり返り
  final List<Reflection> reflections;

  // 次の期間
  final List<UpcomingItem> nextTests;
  final List<Todo> nextTodos;
  final List<CalendarEvent> nextEvents;

  /// 前の期間との差（分）
  int get studyDiff => studyMinutes - previousStudyMinutes;
}

bool _eventIn(CalendarEvent e, ReviewPeriod p) {
  for (
    var d = p.start;
    d.isBefore(p.end);
    d = DateTime(d.year, d.month, d.day + 1)
  ) {
    if (e.occursOn(d)) return true;
  }
  return false;
}

/// 同じテストが「成績」にも入っているか（科目が同じで、日付が10日以内）
bool _coveredByGrades(UpcomingItem t, List<ReviewScore> grades) => grades.any(
  (g) =>
      g.subject != null &&
      g.subject == t.subject &&
      g.date.difference(t.date).inDays.abs() <= 10,
);

/// レビューを作る
///
/// [upcoming] は、この期間と次の期間のテスト（collectUpcoming などで集めたもの）。
/// [events] は、この期間と次の期間の予定（定期の予定を広げたものも含めて）。
ReviewSummary buildReview({
  required ReviewPeriod period,
  List<StudySession> sessions = const [],
  List<Todo> todos = const [],
  List<UpcomingItem> upcoming = const [],
  List<Exam> exams = const [],
  Map<String, TestReview> testReviews = const {},
  List<Goal> goals = const [],
  List<CalendarEvent> events = const [],
  List<Reflection> reflections = const [],
}) {
  final prev = period.previous;
  final next = period.next;

  final byDue = [
    for (final t in todos)
      if (t.dueDate != null && period.contains(t.dueDate!)) t,
  ];

  final tests = [
    for (final x in upcoming)
      if (x.isTest && period.contains(x.date)) x,
  ]..sort((a, b) => a.date.compareTo(b.date));

  // 点数：まず「成績」、次にテストカルテ（成績と重なるものは除く）
  final gradeScores = <ReviewScore>[
    for (final ex in exams)
      if (period.contains(ex.date))
        for (final e in ex.entries)
          ReviewScore(
            title: '${ex.title} ${e.subject}',
            date: ex.date,
            score: e.score,
            max: e.max,
            subject: e.subject,
            fromGrades: true,
          ),
  ];
  final karteScores = <ReviewScore>[
    for (final t in tests)
      if (testReviews[testKeyOf(t)]?.score != null &&
          !_coveredByGrades(t, gradeScores))
        ReviewScore(
          title: t.title,
          date: t.date,
          score: testReviews[testKeyOf(t)]!.score!,
          max: testReviews[testKeyOf(t)]!.maxScore,
          subject: t.subject,
        ),
  ];
  final scores = [...gradeScores, ...karteScores]
    ..sort((a, b) => a.date.compareTo(b.date));

  final dueGoals = [
    for (final g in goals)
      if (g.dueDate != null && period.contains(g.dueDate!)) g,
  ];

  return ReviewSummary(
    period: period,
    studyMinutes: totalMinutes(sessions, period.start, period.end),
    previousStudyMinutes: totalMinutes(sessions, prev.start, prev.end),
    studyBySubject: minutesBySubject(sessions, period.start, period.end),
    dailyStudy: dailyMinutes(sessions, period.lastDay, period.days),
    todosDone: [
      for (final t in byDue)
        if (t.done) t,
    ],
    todosLeft: [
      for (final t in byDue)
        if (!t.done) t,
    ],
    tests: tests,
    scores: scores,
    goals: dueGoals,
    goalsAchieved: dueGoals.where((g) => g.achieved || g.progress >= 1).length,
    events: [
      for (final e in events)
        if (_eventIn(e, period)) e,
    ],
    reflections: [
      for (final r in reflections)
        if (period.contains(r.date)) r,
    ]..sort((a, b) => a.date.compareTo(b.date)),
    nextTests: [
      for (final x in upcoming)
        if (x.isTest && next.contains(x.date)) x,
    ]..sort((a, b) => a.date.compareTo(b.date)),
    nextTodos: [
      for (final t in todos)
        if (!t.done && t.dueDate != null && next.contains(t.dueDate!)) t,
    ],
    nextEvents: [
      for (final e in events)
        if (_eventIn(e, next)) e,
    ],
  );
}
