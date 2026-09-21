/// 学校イベント（行事）に関係するものを集める（画面に依存しない計算だけ）
///
/// 新しい結びつけ用のデータは作らず、「言葉」と「日付」で既存の予定・ToDo・目標・
/// ふり返りを探す。言葉はイベントごとに自分で足せる。
library;

import '../events/calendar_event.dart';
import '../goals/goal.dart';
import '../goals/goal_repository.dart';
import '../todo/todo.dart';

/// 何日前から関係するものを探すか
const int eventLookbackDays = 45;

class EventRelated {
  const EventRelated({
    required this.events,
    required this.todos,
    required this.goals,
    required this.reflections,
  });

  final List<CalendarEvent> events;
  final List<Todo> todos;
  final List<Goal> goals;
  final List<Reflection> reflections;

  bool get isEmpty =>
      events.isEmpty && todos.isEmpty && goals.isEmpty && reflections.isEmpty;
}

/// イベントの名前から、はじめの言葉を作る（例：「第3回 合唱コンクール」→ 合唱コンクール）
List<String> defaultKeywords(String title) {
  final words = title
      .replaceAll(RegExp(r'[（）()「」【】\[\]]'), ' ')
      .split(RegExp(r'[\s　・,、]+'))
      .where((w) => w.length >= 2 && !RegExp(r'^第?\d+回?$').hasMatch(w))
      .toList();
  return words.isEmpty ? [title.trim()] : words;
}

/// 「合唱 朝練」のような入力を言葉の一覧にする
List<String> parseKeywords(String text) => [
  for (final w in text.split(RegExp(r'[\s　,、]+')))
    if (w.trim().isNotEmpty) w.trim(),
];

bool _hit(String? text, List<String> keywords) {
  if (text == null || text.isEmpty) return false;
  final t = text.toLowerCase();
  return keywords.any((k) => t.contains(k.toLowerCase()));
}

/// 関係するものを集める
///
/// - 予定：イベントの日までの [lookbackDays] 日と当日のうち、言葉を含むもの
/// - ToDo・目標：言葉を含むもの（日付は問わない）
/// - ふり返り：同じ期間で、言葉を含むもの
EventRelated gatherRelated({
  required DateTime date,
  required List<String> keywords,
  List<CalendarEvent> events = const [],
  List<Todo> todos = const [],
  List<Goal> goals = const [],
  List<Reflection> reflections = const [],
  int lookbackDays = eventLookbackDays,
  CalendarEvent? self,
}) {
  final day = DateTime(date.year, date.month, date.day);
  final from = DateTime(day.year, day.month, day.day - lookbackDays);
  final to = DateTime(day.year, day.month, day.day + 1);
  bool inWindow(DateTime d) => !d.isBefore(from) && d.isBefore(to);

  if (keywords.isEmpty) {
    return const EventRelated(
      events: [],
      todos: [],
      goals: [],
      reflections: [],
    );
  }

  return EventRelated(
    events: [
      for (final e in events)
        if (!identical(e, self) &&
            (self?.id == null || e.id != self!.id) &&
            e.start.isBefore(to) &&
            !e.end.isBefore(from) &&
            (_hit(e.title, keywords) || _hit(e.memo, keywords)))
          e,
    ]..sort((a, b) => a.start.compareTo(b.start)),
    todos:
        [
          for (final t in todos)
            if (_hit(t.title, keywords) || _hit(t.memo, keywords)) t,
        ]..sort((a, b) {
          if (a.done != b.done) return a.done ? 1 : -1;
          return (a.dueDate ?? DateTime(9999)).compareTo(
            b.dueDate ?? DateTime(9999),
          );
        }),
    goals: [
      for (final g in goals)
        if (_hit(g.title, keywords) || _hit(g.memo, keywords)) g,
    ],
    reflections: [
      for (final r in reflections)
        if (inWindow(r.date) && _hit(r.text, keywords)) r,
    ]..sort((a, b) => a.date.compareTo(b.date)),
  );
}
