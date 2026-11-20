/// 定期テスト・模試ぜんたいに向けての目標
///
/// 1回のテスト（例：後期期末試験、第2回全統模試）につき1件。
/// 教科ごとに目標点・実際の点数・やること（ワーク・単語帳など）を持てる、
/// 通常の [Goal]（1件1目標）とは別の、テスト専用の目標。
library;

import 'goal.dart' show Milestone;

/// テストの種類（定期テストか模試か）
enum ExamGoalKind {
  regularExam('定期テスト'),
  mockExam('模試');

  const ExamGoalKind(this.label);
  final String label;
}

/// 1教科ぶんの目標
class ExamSubjectGoal {
  const ExamSubjectGoal({
    required this.subject,
    this.targetScore,
    this.currentScore,
    this.materials = const [],
  });

  /// 教科名（例：数学Ⅰ）
  final String subject;

  /// 目標点数（未設定なら null）
  final num? targetScore;

  /// 実際の点数（テストが終わってから入れる。未入力なら null）
  final num? currentScore;

  /// やること（ワーク・単語帳など）のチェック項目
  final List<Milestone> materials;

  /// 目標を達成したか（両方入っていて、実際の点数が目標以上）
  bool? get achieved => (targetScore == null || currentScore == null)
      ? null
      : currentScore! >= targetScore!;

  /// やることの進み具合（0〜1）。項目がなければ 0
  double get materialsProgress => materials.isEmpty
      ? 0
      : materials.where((m) => m.done).length / materials.length;

  ExamSubjectGoal copyWith({
    String? subject,
    num? targetScore,
    bool clearTargetScore = false,
    num? currentScore,
    bool clearCurrentScore = false,
    List<Milestone>? materials,
  }) => ExamSubjectGoal(
    subject: subject ?? this.subject,
    targetScore: clearTargetScore ? null : (targetScore ?? this.targetScore),
    currentScore: clearCurrentScore
        ? null
        : (currentScore ?? this.currentScore),
    materials: materials ?? this.materials,
  );

  Map<String, dynamic> toMap() => {
    'subject': subject,
    'targetScore': targetScore,
    'currentScore': currentScore,
    'materials': [
      for (final m in materials) {'title': m.title, 'done': m.done},
    ],
  };

  factory ExamSubjectGoal.fromMap(Map<String, dynamic> m) => ExamSubjectGoal(
    subject: m['subject'] as String? ?? '',
    targetScore: m['targetScore'] as num?,
    currentScore: m['currentScore'] as num?,
    materials: [
      for (final x in (m['materials'] as List<dynamic>? ?? const []))
        Milestone(
          (x as Map)['title'] as String? ?? '',
          done: x['done'] as bool? ?? false,
        ),
    ],
  );
}

/// テストぜんたいの目標
class ExamGoal {
  const ExamGoal({
    this.id,
    required this.title,
    this.kind = ExamGoalKind.regularExam,
    this.examDate,
    this.examEndDate,
    this.subjects = const [],
    this.memo,
  });

  final String? id;

  /// テスト名（例：後期期末試験、第2回全統模試）
  final String title;
  final ExamGoalKind kind;

  /// 実施日（複数日にわたるときは初日）
  final DateTime? examDate;

  /// 最終日（1日だけのテストなら null）
  final DateTime? examEndDate;

  final List<ExamSubjectGoal> subjects;
  final String? memo;

  /// 教科数
  int get subjectCount => subjects.length;

  /// 目標点が入っている教科の、目標点の合計（合計点の目安に使う）
  num get totalTargetScore => subjects.fold<num>(
    0,
    (sum, s) => sum + (s.targetScore ?? 0),
  );

  /// 実際の点数が入っている教科の合計
  num get totalCurrentScore => subjects.fold<num>(
    0,
    (sum, s) => sum + (s.currentScore ?? 0),
  );

  /// 実際の点数が全教科入っているか（合計点を表示してよいか）
  bool get allScoresIn =>
      subjects.isNotEmpty && subjects.every((s) => s.currentScore != null);

  /// 目標を達成した教科の数（実際の点数がまだの教科は数えない）
  int get achievedSubjectCount =>
      subjects.where((s) => s.achieved == true).length;

  /// 実際の点数が入っている教科の数
  int get scoredSubjectCount =>
      subjects.where((s) => s.currentScore != null).length;

  /// やること（ワーク・単語帳など）ぜんたいの進み具合（0〜1）
  double get materialsProgress {
    final all = [for (final s in subjects) ...s.materials];
    if (all.isEmpty) return 0;
    return all.where((m) => m.done).length / all.length;
  }

  ExamGoal copyWith({
    String? title,
    ExamGoalKind? kind,
    DateTime? examDate,
    bool clearExamDate = false,
    DateTime? examEndDate,
    bool clearExamEndDate = false,
    List<ExamSubjectGoal>? subjects,
    String? memo,
  }) => ExamGoal(
    id: id,
    title: title ?? this.title,
    kind: kind ?? this.kind,
    examDate: clearExamDate ? null : (examDate ?? this.examDate),
    examEndDate: clearExamEndDate ? null : (examEndDate ?? this.examEndDate),
    subjects: subjects ?? this.subjects,
    memo: memo ?? this.memo,
  );
}

/// 実施日が近い順（実施日なしは最後）
List<ExamGoal> sortExamGoals(List<ExamGoal> goals) => [...goals]..sort((
  a,
  b,
) {
  if (a.examDate == null && b.examDate == null) {
    return a.title.compareTo(b.title);
  }
  if (a.examDate == null) return 1;
  if (b.examDate == null) return -1;
  return a.examDate!.compareTo(b.examDate!);
});
