/// 勉強時間の記録と集計
library;

class StudySession {
  const StudySession({
    this.id,
    this.subject,
    required this.start,
    required this.minutes,
    this.memo,
  });

  final String? id;
  final String? subject;

  /// 勉強を始めた日時（手で入力したときはその日の 0:00）
  final DateTime start;
  final int minutes;
  final String? memo;
}

DateTime _day(DateTime d) => DateTime(d.year, d.month, d.day);

/// その週の日曜日
DateTime weekStart(DateTime d) =>
    DateTime(d.year, d.month, d.day - (d.weekday % 7));

bool _inRange(StudySession s, DateTime from, DateTime to) =>
    !s.start.isBefore(from) && s.start.isBefore(to);

/// from 〜 to（to は含まない）の合計（分）
int totalMinutes(List<StudySession> list, DateTime from, DateTime to) => list
    .where((s) => _inRange(s, from, to))
    .fold(0, (sum, s) => sum + s.minutes);

/// from 〜 to の科目ごとの合計（多い順）
List<MapEntry<String, int>> minutesBySubject(
  List<StudySession> list,
  DateTime from,
  DateTime to,
) {
  final map = <String, int>{};
  for (final s in list.where((s) => _inRange(s, from, to))) {
    final key = s.subject ?? 'その他';
    map[key] = (map[key] ?? 0) + s.minutes;
  }
  return map.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
}

/// lastDay までの days 日分の毎日の合計（古い順）
List<int> dailyMinutes(List<StudySession> list, DateTime lastDay, int days) {
  final last = _day(lastDay);
  return [
    for (var i = days - 1; i >= 0; i--)
      totalMinutes(
        list,
        DateTime(last.year, last.month, last.day - i),
        DateTime(last.year, last.month, last.day - i + 1),
      ),
  ];
}

/// 「1時間30分」「45分」の形
String formatMinutes(int m) {
  if (m < 60) return '$m分';
  final rest = m % 60;
  return rest == 0 ? '${m ~/ 60}時間' : '${m ~/ 60}時間$rest分';
}
