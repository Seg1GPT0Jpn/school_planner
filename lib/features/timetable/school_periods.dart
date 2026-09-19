/// 学校の「標準時間枠」の定義
///
/// 時限の時刻・5限がある曜日は、アプリ全体でこのファイルだけを参照する。
/// 時刻が変わったときは、このファイルだけを直せばよい。
library;

/// 時刻（時・分）を表すクラス
class ClockTime implements Comparable<ClockTime> {
  const ClockTime(this.hour, this.minute);

  final int hour;
  final int minute;

  /// 0:00 からの経過分数（比較や計算に使う）
  int get totalMinutes => hour * 60 + minute;

  @override
  int compareTo(ClockTime other) => totalMinutes.compareTo(other.totalMinutes);

  @override
  bool operator ==(Object other) =>
      other is ClockTime && other.hour == hour && other.minute == minute;

  @override
  int get hashCode => Object.hash(hour, minute);

  /// 「08:50」のような表示用の文字列
  @override
  String toString() {
    final h = hour.toString().padLeft(2, '0');
    final m = minute.toString().padLeft(2, '0');
    return '$h:$m';
  }
}

/// 1コマ分の授業時間（何時間目か・開始時刻・終了時刻）
class SchoolPeriod {
  const SchoolPeriod({
    required this.number,
    required this.start,
    required this.end,
  });

  /// 何時間目か（1〜5）
  final int number;
  final ClockTime start;
  final ClockTime end;

  /// 「1限」のような表示用の名前
  String get label => '$number限';

  /// 授業の長さ（分）
  int get durationMinutes => end.totalMinutes - start.totalMinutes;
}

/// 学校の標準時間枠（このクラスはインスタンスを作らずに使う）
class SchoolPeriods {
  SchoolPeriods._();

  /// 全時限の標準時刻（70分授業）
  static const List<SchoolPeriod> all = [
    SchoolPeriod(number: 1, start: ClockTime(8, 50), end: ClockTime(10, 0)),
    SchoolPeriod(number: 2, start: ClockTime(10, 10), end: ClockTime(11, 20)),
    SchoolPeriod(number: 3, start: ClockTime(11, 30), end: ClockTime(12, 40)),
    SchoolPeriod(number: 4, start: ClockTime(13, 30), end: ClockTime(14, 40)),
    SchoolPeriod(number: 5, start: ClockTime(14, 50), end: ClockTime(16, 0)),
  ];

  /// 昼休み
  static const ClockTime lunchStart = ClockTime(12, 40);
  static const ClockTime lunchEnd = ClockTime(13, 25);

  /// 昼休みは何時間目のあとか
  static const int lunchAfterPeriod = 3;

  /// 授業がある曜日（月〜金）
  static const Set<int> schoolWeekdays = {
    DateTime.monday,
    DateTime.tuesday,
    DateTime.wednesday,
    DateTime.thursday,
    DateTime.friday,
  };

  /// 5限がある曜日（月・火・木）
  static const Set<int> weekdaysWithFifthPeriod = {
    DateTime.monday,
    DateTime.tuesday,
    DateTime.thursday,
  };

  /// その曜日の通常の授業数（月火木=5、水金=4、土日=0）
  static int periodCountFor(int weekday) {
    if (!schoolWeekdays.contains(weekday)) return 0;
    return weekdaysWithFifthPeriod.contains(weekday) ? 5 : 4;
  }

  /// その曜日の通常の時限一覧
  static List<SchoolPeriod> periodsFor(int weekday) {
    return all.take(periodCountFor(weekday)).toList();
  }

  /// その曜日に、その時限が「通常の授業」として存在するか
  /// （例：水曜の5限 → false）
  static bool isRegularPeriod(int weekday, int periodNumber) {
    return periodNumber >= 1 && periodNumber <= periodCountFor(weekday);
  }

  /// 時限の番号から標準時刻を取り出す（1〜5以外はエラー）
  static SchoolPeriod byNumber(int periodNumber) {
    return all.firstWhere(
      (p) => p.number == periodNumber,
      orElse: () => throw ArgumentError('存在しない時限です: $periodNumber'),
    );
  }
}
