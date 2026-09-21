/// 「AIアドバイス」機能
///
/// 外部のAI（有料API）は一切使わず、このアプリがすでに持っている記録
/// （ToDo・忙しさ・がんばり・気分・テスト予定）だけを見て、ルールベースで
/// 一言アドバイスを組み立てる。新しいFirestoreコレクションも増やさない。
library;

import '../gamification/gamification.dart';
import '../todo/todo.dart';
import '../workload/workload.dart';

/// アドバイスの種類（アイコン・色を出しわけるのに使う）
enum AdvisorKind { workload, examSoon, todoOverdue, streak, streakBroken, mood, allGood }

/// アドバイスの調子（前向き・注意・ふつう）
enum AdvisorTone { praise, notice, tip }

class AdvisorTip {
  const AdvisorTip({
    required this.kind,
    required this.tone,
    required this.message,
  });

  final AdvisorKind kind;
  final AdvisorTone tone;
  final String message;
}

DateTime _day(DateTime d) => DateTime(d.year, d.month, d.day);

/// いまの状況から、アドバイスの一覧を作る（優先度が高い順）
///
/// [recentMoods] は直近7日ぶんの気分の絵文字（記録がない日は含めなくてよい）。
/// [testsWithin3Days] は、3日以内に予定されているテスト・小テストの数。
List<AdvisorTip> computeAdvisorTips({
  required DateTime now,
  required List<Todo> todos,
  required List<DayLoad> weekLoad,
  required GamificationStats gamification,
  List<String> recentMoods = const [],
  int testsWithin3Days = 0,
}) {
  final today = _day(now);
  final tips = <AdvisorTip>[];

  // ① 詰め込みすぎ（忙しさ予測）
  final loadWarning = weekLoadWarning(weekLoad);
  if (loadWarning != null) {
    tips.add(
      AdvisorTip(
        kind: AdvisorKind.workload,
        tone: AdvisorTone.notice,
        message: loadWarning,
      ),
    );
  }

  // ② 直前のテスト
  if (testsWithin3Days >= 2) {
    tips.add(
      AdvisorTip(
        kind: AdvisorKind.examSoon,
        tone: AdvisorTone.notice,
        message:
            '3日以内にテストが$testsWithin3Days件あります。'
            '前日にまとめてやるより、今日から少しずつ進めたほうが楽になります。',
      ),
    );
  } else if (testsWithin3Days == 1) {
    tips.add(
      const AdvisorTip(
        kind: AdvisorKind.examSoon,
        tone: AdvisorTone.tip,
        message: '3日以内にテストが1件あります。範囲の確認だけでも早めにすませておきましょう。',
      ),
    );
  }

  // ③ 期限切れの ToDo
  final overdue = todos.where((t) => t.isOverdue(today)).length;
  if (overdue > 0) {
    tips.add(
      AdvisorTip(
        kind: AdvisorKind.todoOverdue,
        tone: AdvisorTone.notice,
        message: '期限が過ぎた ToDo が$overdue件あります。今日のうちに1つだけでも片づけてみませんか。',
      ),
    );
  }

  // ④ 連続記録（がんばりの様子）
  if (gamification.currentStreak >= 3) {
    tips.add(
      AdvisorTip(
        kind: AdvisorKind.streak,
        tone: AdvisorTone.praise,
        message: '${gamification.currentStreak}日連続で ToDo を達成しています。いい調子です！',
      ),
    );
  } else if (gamification.currentStreak == 0 && gamification.bestStreak >= 3) {
    tips.add(
      AdvisorTip(
        kind: AdvisorKind.streakBroken,
        tone: AdvisorTone.tip,
        message: '以前は${gamification.bestStreak}日連続で続けられていました。今日からまた積み上げてみましょう。',
      ),
    );
  }

  // ⑤ 気分の記録（つらそうな日が続いていないか）
  final negativeMoods = recentMoods
      .where((m) => m == '😣' || m == '😫')
      .length;
  if (negativeMoods >= 3) {
    tips.add(
      const AdvisorTip(
        kind: AdvisorKind.mood,
        tone: AdvisorTone.notice,
        message: 'ここ数日、しんどそうな気分の記録が続いています。無理せず、休める時間もつくってくださいね。',
      ),
    );
  }

  if (tips.isEmpty) {
    tips.add(
      const AdvisorTip(
        kind: AdvisorKind.allGood,
        tone: AdvisorTone.praise,
        message: '今のところ、特に気になる点はありません。この調子でいきましょう。',
      ),
    );
  }

  return tips;
}
