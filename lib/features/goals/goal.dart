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
  studyTime('勉強時間'),
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
    this.startDate,
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

  /// 勉強時間の目標で、数え始める日
  final DateTime? startDate;

  final GoalProgressType type;

  /// 数値の今（勉強時間の目標では「時間」。自動で計算される）
  final num current;
  final num target;
  final String unit;
  final List<Milestone> milestones;
  final bool achieved;
  final String? memo;
  final String? subject;

  double get progress {
    if (achieved) return 1;
    switch (type) {
      case GoalProgressType.number:
      case GoalProgressType.studyTime:
        if (target <= 0) return 0;
        return (current / target).clamp(0, 1).toDouble();
      case GoalProgressType.checklist:
        if (milestones.isEmpty) return 0;
        return milestones.where((m) => m.done).length / milestones.length;
      case GoalProgressType.none:
        return 0;
    }
  }

  String get progressText => switch (type) {
    GoalProgressType.number => '${_n(current)}/${_n(target)}$unit',
    GoalProgressType.studyTime => '${_n(current)}/${_n(target)}時間',
    GoalProgressType.checklist =>
      '${milestones.where((m) => m.done).length}/${milestones.length}',
    GoalProgressType.none => achieved ? '達成' : '',
  };

  static String _n(num v) => v == v.roundToDouble() ? '${v.toInt()}' : '$v';
}

List<Goal> sortGoals(List<Goal> goals) => [...goals]
  ..sort((a, b) {
    if (a.term != b.term) return a.term == GoalTerm.short ? -1 : 1;
    if (a.dueDate == null && b.dueDate == null) {
      return a.title.compareTo(b.title);
    }
    if (a.dueDate == null) return 1;
    if (b.dueDate == null) return -1;
    return a.dueDate!.compareTo(b.dueDate!);
  });
