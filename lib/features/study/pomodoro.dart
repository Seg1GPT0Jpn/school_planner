/// ポモドーロ（25分集中＋5分休憩のくり返し）の計算
library;

import 'dart:math' as math;

import '../notifications/notification_planner.dart';

const int pomodoroFocusMin = 25;
const int pomodoroBreakMin = 5;

/// ポモドーロの通知に使う番号（ほかの通知とかぶらない範囲）
const int pomodoroIdBase = 900000;

class PomodoroPhase {
  const PomodoroPhase({
    required this.focus,
    required this.round,
    required this.remaining,
  });

  /// 集中中なら true、休憩中なら false
  final bool focus;

  /// 何回目か（1から）
  final int round;

  /// 今の区切りの残り時間
  final Duration remaining;
}

/// 始めてから [elapsed] たったときの状態
PomodoroPhase pomodoroPhase(
  Duration elapsed, {
  int focusMin = pomodoroFocusMin,
  int breakMin = pomodoroBreakMin,
}) {
  final cycle = (focusMin + breakMin) * 60;
  final s = math.max(0, elapsed.inSeconds);
  final round = s ~/ cycle + 1;
  final inCycle = s % cycle;
  if (inCycle < focusMin * 60) {
    return PomodoroPhase(
      focus: true,
      round: round,
      remaining: Duration(seconds: focusMin * 60 - inCycle),
    );
  }
  return PomodoroPhase(
    focus: false,
    round: round,
    remaining: Duration(seconds: cycle - inCycle),
  );
}

/// 記録する時間（分）：休憩の時間は数えない
int pomodoroFocusMinutes(
  Duration elapsed, {
  int focusMin = pomodoroFocusMin,
  int breakMin = pomodoroBreakMin,
}) {
  final cycle = (focusMin + breakMin) * 60;
  final s = math.max(0, elapsed.inSeconds);
  final full = s ~/ cycle;
  final rest = s % cycle;
  return (full * focusMin * 60 + math.min(rest, focusMin * 60)) ~/ 60;
}

/// 区切りごとのお知らせ（[cycles] 回分）
List<PlannedNotification> pomodoroNotifications(
  DateTime startedAt, {
  int cycles = 8,
  int focusMin = pomodoroFocusMin,
  int breakMin = pomodoroBreakMin,
}) {
  final list = <PlannedNotification>[];
  for (var k = 0; k < cycles; k++) {
    final cycleStart = startedAt.add(
      Duration(minutes: k * (focusMin + breakMin)),
    );
    list.add(
      PlannedNotification(
        pomodoroIdBase + k * 2,
        cycleStart.add(Duration(minutes: focusMin)),
        '休憩しましょう（$breakMin分）',
        '${k + 1}回目の集中が終わりました',
      ),
    );
    list.add(
      PlannedNotification(
        pomodoroIdBase + k * 2 + 1,
        cycleStart.add(Duration(minutes: focusMin + breakMin)),
        '集中を再開しましょう',
        '${k + 2}回目・$focusMin分',
      ),
    );
  }
  return list;
}
