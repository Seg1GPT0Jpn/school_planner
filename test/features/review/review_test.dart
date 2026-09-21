import 'package:flutter_test/flutter_test.dart';
import 'package:school_planner/features/events/calendar_event.dart';
import 'package:school_planner/features/goals/goal.dart';
import 'package:school_planner/features/goals/goal_repository.dart';
import 'package:school_planner/features/grades/grade.dart';
import 'package:school_planner/features/review/period.dart';
import 'package:school_planner/features/review/review_models.dart';
import 'package:school_planner/features/review/review_summary.dart';
import 'package:school_planner/features/review/school_event.dart';
import 'package:school_planner/features/review/test_karte.dart';
import 'package:school_planner/features/school_tests/upcoming_tests.dart';
import 'package:school_planner/features/study/study.dart';
import 'package:school_planner/features/todo/todo.dart';

StudySession _s(DateTime d, int m, [String? subject]) =>
    StudySession(start: d, minutes: m, subject: subject);

UpcomingItem _t(
  DateTime d,
  String title, {
  bool isTest = true,
  String? subject,
}) => UpcomingItem(
  date: d,
  title: title,
  kindLabel: isTest ? '小テスト' : '提出物',
  isTest: isTest,
  subject: subject,
);

void main() {
  final monday = DateTime(2026, 9, 21);

  // ───────────── 期間 ─────────────
  group('期間', () {
    test('週（日曜はじまり・月曜はじまり）', () {
      final w = ReviewPeriod.of(ReviewKind.week, monday);
      expect(w.start, DateTime(2026, 9, 20));
      expect(w.end, DateTime(2026, 9, 27));
      expect(w.days, 7);
      expect(w.label, '9/20〜9/26');
      expect(w.key, 'week_2026-09-20');
      expect(w.previous.start, DateTime(2026, 9, 13));
      expect(w.next.start, DateTime(2026, 9, 27));

      final m = ReviewPeriod.of(
        ReviewKind.week,
        monday,
        weekStart: DateTime.monday,
      );
      expect(m.start, monday);
      expect(m.next.start, DateTime(2026, 9, 28));
    });

    test('月', () {
      final p = ReviewPeriod.of(ReviewKind.month, monday);
      expect(p.start, DateTime(2026, 9, 1));
      expect(p.end, DateTime(2026, 10, 1));
      expect(p.days, 30);
      expect(p.label, '2026年9月');
      expect(p.key, 'month_2026-09');
      expect(p.previous.label, '2026年8月');
      expect(p.next.label, '2026年10月');
    });

    test('学期（前期・後期）', () {
      final p = ReviewPeriod.of(ReviewKind.term, monday);
      expect(p.start, DateTime(2026, 4, 1));
      expect(p.end, DateTime(2026, 10, 1));
      expect(p.days, 183);
      expect(p.label, '2026年度 前期');
      expect(p.key, 'term_2026_1');
      expect(p.next.label, '2026年度 後期');
      expect(p.next.key, 'term_2026_2');
      expect(p.previous.label, '2025年度 後期');

      // 1月は、前の年度の後期
      final jan = ReviewPeriod.of(ReviewKind.term, DateTime(2027, 1, 15));
      expect(jan.label, '2026年度 後期');
      expect(jan.end, DateTime(2027, 4, 1));
    });
  });

  // ───────────── レビューの集計 ─────────────
  group('レビュー', () {
    final period = ReviewPeriod.of(ReviewKind.week, monday); // 9/20〜9/26
    final quiz = _t(DateTime(2026, 9, 24), '数学 小テスト', subject: '数学');
    final exam = _t(DateTime(2026, 9, 25), '前期期末 英語', subject: '英語');

    final s = buildReview(
      period: period,
      sessions: [
        _s(DateTime(2026, 9, 21, 19), 60, '数学'),
        _s(DateTime(2026, 9, 22, 20), 30, '英語'),
        _s(DateTime(2026, 9, 15, 20), 45, '数学'), // 前の週
        _s(DateTime(2026, 9, 27, 20), 10, '数学'), // 次の週
      ],
      todos: [
        Todo(title: 'A', dueDate: DateTime(2026, 9, 22), done: true),
        Todo(title: 'B', dueDate: DateTime(2026, 9, 25)),
        Todo(title: 'C', dueDate: DateTime(2026, 9, 29)),
        const Todo(title: '期限なし'),
      ],
      upcoming: [
        quiz,
        exam,
        _t(DateTime(2026, 9, 23), '提出物', isTest: false),
        _t(DateTime(2026, 9, 30), '英語 LEAP'),
      ],
      exams: [
        Exam(
          title: '前期期末',
          date: DateTime(2026, 9, 25),
          entries: const [GradeEntry(subject: '英語', score: 70)],
        ),
      ],
      testReviews: {
        testKeyOf(quiz): const TestReview(score: 8, maxScore: 10),
        // 成績にも入っているので、こちらは出さない
        testKeyOf(exam): const TestReview(score: 71),
      },
      goals: [
        Goal(title: 'g1', dueDate: DateTime(2026, 9, 23), achieved: true),
        Goal(title: 'g2', dueDate: DateTime(2026, 9, 24)),
        Goal(title: 'g3', dueDate: DateTime(2026, 10, 10)),
      ],
      events: [
        CalendarEvent(
          title: '面談',
          start: DateTime(2026, 9, 21, 10),
          end: DateTime(2026, 9, 21, 11),
        ),
        CalendarEvent(
          title: '体育祭',
          start: DateTime(2026, 9, 26),
          end: DateTime(2026, 9, 26),
          isAllDay: true,
        ),
        CalendarEvent(
          title: '模試',
          start: DateTime(2026, 9, 28, 9),
          end: DateTime(2026, 9, 28, 15),
        ),
      ],
      reflections: [
        Reflection(DateTime(2026, 9, 21), 'がんばった'),
        Reflection(DateTime(2026, 9, 19), '前の週'),
      ],
    );

    test('勉強時間（合計・前の週・科目・毎日）', () {
      expect(s.studyMinutes, 90);
      expect(s.previousStudyMinutes, 45);
      expect(s.studyDiff, 45);
      expect(s.studyBySubject.map((e) => e.key).toList(), ['数学', '英語']);
      expect(s.dailyStudy, [0, 60, 30, 0, 0, 0, 0]);
    });

    test('ToDo は期限がこの週のもの', () {
      expect(s.todosDone.map((t) => t.title), ['A']);
      expect(s.todosLeft.map((t) => t.title), ['B']);
      expect(s.nextTodos.map((t) => t.title), ['C']);
    });

    test('テストと点数（成績とカルテ、重なりは成績を使う）', () {
      expect(s.tests.map((t) => t.title), ['数学 小テスト', '前期期末 英語']);
      expect(s.scores.map((x) => x.title).toList(), ['数学 小テスト', '前期期末 英語']);
      expect(s.scores.first.fromGrades, isFalse);
      expect(s.scores.first.percent, 80);
      expect(s.scores.last.fromGrades, isTrue);
      expect(s.scores.last.score, 70);
      expect(s.nextTests.map((t) => t.title), ['英語 LEAP']);
    });

    test('目標・予定・ふり返り', () {
      expect(s.goals.map((g) => g.title), ['g1', 'g2']);
      expect(s.goalsAchieved, 1);
      expect(s.events.map((e) => e.title), ['面談', '体育祭']);
      expect(s.nextEvents.map((e) => e.title), ['模試']);
      expect(s.reflections.map((r) => r.text), ['がんばった']);
    });
  });

  // ───────────── テストカルテ ─────────────
  group('テストカルテ', () {
    final date = DateTime(2026, 10, 10);
    final sessions = [
      _s(DateTime(2026, 9, 27, 20), 30, '数学'), // 数え始めの日
      _s(DateTime(2026, 10, 9, 20), 60, '数学'),
      _s(DateTime(2026, 9, 26, 20), 100, '数学'), // 期間の前
      _s(DateTime(2026, 10, 1, 20), 40, '英語'),
    ];
    final exams = [
      Exam(
        title: '前期中間',
        date: DateTime(2026, 6, 1),
        entries: const [GradeEntry(subject: '数学', score: 60)],
      ),
      Exam(
        title: '前期期末',
        date: DateTime(2026, 10, 8),
        entries: const [GradeEntry(subject: '数学', score: 80, average: 65)],
      ),
    ];

    test('試験前14日の勉強時間', () {
      final k = buildKarte(date: date, subject: '数学', sessions: sessions);
      expect(k.windowStart, DateTime(2026, 9, 27));
      expect(k.subjectMinutes, 90);
      expect(k.allMinutes, 130);
      expect(k.daily.length, 14);
      expect(k.daily.first, 30);
      expect(k.daily[12], 60);
      expect(k.daily.last, 0);
    });

    test('成績から結果と前回をさがす', () {
      final k = buildKarte(date: date, subject: '数学', exams: exams);
      expect(k.grade!.$1.title, '前期期末');
      expect(k.previous!.$1.title, '前期中間');
      expect(k.score, 80);
      expect(k.max, 100);
      expect(k.diff, 20);
    });

    test('カルテで入れた点数を優先する', () {
      final k = buildKarte(
        date: date,
        subject: '数学',
        exams: exams,
        review: const TestReview(score: 85),
      );
      expect(k.score, 85);
      expect(k.diff, 25);
    });

    test('近くに成績がないとき', () {
      final k = buildKarte(
        date: DateTime(2026, 12, 1),
        subject: '数学',
        exams: exams,
      );
      expect(k.grade, isNull);
      expect(k.previous!.$1.title, '前期期末');
      expect(k.score, isNull);
      expect(k.diff, isNull);
    });

    test('科目がわからないテスト', () {
      final k = buildKarte(date: date, sessions: sessions);
      expect(k.subjectMinutes, 0);
      expect(k.allMinutes, 130);
    });
  });

  // ───────────── 学校イベント ─────────────
  group('学校イベント', () {
    test('はじめの言葉', () {
      expect(defaultKeywords('第3回 合唱コンクール'), ['合唱コンクール']);
      expect(defaultKeywords('体育祭'), ['体育祭']);
      expect(parseKeywords('合唱 朝練、伴奏'), ['合唱', '朝練', '伴奏']);
    });

    test('言葉と日付で関係するものを集める', () {
      final r = gatherRelated(
        date: DateTime(2026, 10, 15),
        keywords: const ['合唱', '朝練'],
        events: [
          CalendarEvent(
            title: '合唱コンクール 本番',
            start: DateTime(2026, 10, 15, 13),
            end: DateTime(2026, 10, 15, 16),
          ),
          CalendarEvent(
            title: '朝練',
            start: DateTime(2026, 10, 10, 7, 30),
            end: DateTime(2026, 10, 10, 8, 10),
          ),
          CalendarEvent(
            title: '塾',
            start: DateTime(2026, 10, 10, 19),
            end: DateTime(2026, 10, 10, 21),
          ),
          CalendarEvent(
            title: '合唱 リハ',
            start: DateTime(2026, 8, 1, 10),
            end: DateTime(2026, 8, 1, 11),
          ), // 45日より前
        ],
        todos: const [
          Todo(title: '衣装確認 合唱', done: true),
          Todo(title: '楽譜確認', memo: '合唱の楽譜'),
          Todo(title: '数学ワーク'),
        ],
        goals: const [
          Goal(title: '伴奏を成功させる', memo: '合唱コンクール'),
          Goal(title: '英語80点'),
        ],
        reflections: [
          Reflection(DateTime(2026, 10, 1), '合唱の練習をした'),
          Reflection(DateTime(2026, 7, 1), '合唱'),
        ],
      );
      expect(r.events.map((e) => e.title).toList(), ['朝練', '合唱コンクール 本番']);
      expect(r.todos.map((t) => t.title).toList(), ['楽譜確認', '衣装確認 合唱']);
      expect(r.goals.single.title, '伴奏を成功させる');
      expect(r.reflections.single.text, '合唱の練習をした');
    });

    test('言葉がなければ何も集めない', () {
      final r = gatherRelated(
        date: DateTime(2026, 10, 15),
        keywords: const [],
        todos: const [Todo(title: '合唱')],
      );
      expect(r.isEmpty, isTrue);
    });
  });
}
