/// 目標
library;

enum GoalTerm {
  short('短期'),
  long('長期');

  const GoalTerm(this.label);
  final String label;
}

enum GoalProgressType {
  number('数値'),
  checklist('チェックリスト'),
  none('なし');

  const GoalProgressType(this.label);
  final String label;
}

class Milestone {
  const Milestone(this.title, {this.done = false});
  final String title;
  final bool done;
}

class Goal {
  const Goal({
    this.id,
    required this.title,
    this.term = GoalTerm.short,
    this.dueDate,
    this.type = GoalProgressType.number,
    this.current = 0,
    this.target = 100,
    this.unit = '',
    this.milestones = const [],
    this.achieved = false,
    this.memo,
    this.subject,
  });

  final String? id;
  final String title;
  final GoalTerm term;
  final DateTime? dueDate;
  final GoalProgressType type;
  final num current;
  final num target;
  final String unit;
  final List<Milestone> milestones;
  final bool achieved;
  final String? memo;

  /// 科目（なければ null）
  final String? subject;

  /// 進み具合（0.0〜1.0）
  double get progress {
    if (achieved) return 1;
    switch (type) {
      case GoalProgressType.number:
        if (target <= 0) return 0;
        return (current / target).clamp(0, 1).toDouble();
      case GoalProgressType.checklist:
        if (milestones.isEmpty) return 0;
        return milestones.where((m) => m.done).length / milestones.length;
      case GoalProgressType.none:
        return 0;
    }
  }

  /// 進み具合の文字（例：1300/2000語、2/5）
  String get progressText => switch (type) {
    GoalProgressType.number => '${_n(current)}/${_n(target)}$unit',
    GoalProgressType.checklist =>
      '${milestones.where((m) => m.done).length}/${milestones.length}',
    GoalProgressType.none => achieved ? '達成' : '',
  };

  static String _n(num v) => v == v.roundToDouble() ? '${v.toInt()}' : '$v';
}

/// 並べる順：短期 → 長期、その中は期限が近い順（期限なしは最後）
List<Goal> sortGoals(List<Goal> goals) => [...goals]
  ..sort((a, b) {
    if (a.term != b.term) return a.term == GoalTerm.short ? -1 : 1;
    if (a.dueDate == null && b.dueDate == null)
      return a.title.compareTo(b.title);
    if (a.dueDate == null) return 1;
    if (b.dueDate == null) return -1;
    return a.dueDate!.compareTo(b.dueDate!);
  });
