/// 学校の「時間枠」の定義
///
/// 時限の時刻・5限がある曜日・日課ごとの時程は、
/// アプリ全体でこのファイルだけを参照する。
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

  /// 何時間目か
  final int number;
  final ClockTime start;
  final ClockTime end;

  /// 「1限」のような表示用の名前
  String get label => '$number限';

  /// 授業の長さ（分）
  int get durationMinutes => end.totalMinutes - start.totalMinutes;
}

/// 日課（その日の時程の種類）
enum DaySchedule {
  regular('通常日課'),
  shortened('短縮日課'),
  exam('試験日課');

  const DaySchedule(this.label);

  /// 画面表示用の名前
  final String label;

  /// 昼休みがあるか
  bool get hasLunch => this == DaySchedule.regular;

  /// Ⅰ週/Ⅱ週の通常時間割を使うか（試験日課は使わない）
  bool get usesRegularTimetable => this != DaySchedule.exam;
}

/// 学校の時間枠（このクラスはインスタンスを作らずに使う）
class SchoolPeriods {
  SchoolPeriods._();

  // ------------------------------------------------------------
  // 通常日課（70分授業）
  // ------------------------------------------------------------

  /// 全時限の標準時刻（70分授業）
  static const List<SchoolPeriod> all = [
    SchoolPeriod(number: 1, start: ClockTime(8, 50), end: ClockTime(10, 0)),
    SchoolPeriod(number: 2, start: ClockTime(10, 10), end: ClockTime(11, 20)),
    SchoolPeriod(number: 3, start: ClockTime(11, 30), end: ClockTime(12, 40)),
    SchoolPeriod(number: 4, start: ClockTime(13, 30), end: ClockTime(14, 40)),
    SchoolPeriod(number: 5, start: ClockTime(14, 50), end: ClockTime(16, 0)),
  ];

  /// 昼休み（通常日課のみ）
  static const ClockTime lunchStart = ClockTime(12, 40);
  static const ClockTime lunchEnd = ClockTime(13, 25);

  /// 昼休みは何時間目のあとか
  static const int lunchAfterPeriod = 3;

  // ------------------------------------------------------------
  // 短縮日課
  // ------------------------------------------------------------

  /// 通常5コマの曜日の短縮日課（40分 × 5）
  static const List<SchoolPeriod> shortenedFivePeriodDay = [
    SchoolPeriod(number: 1, start: ClockTime(8, 50), end: ClockTime(9, 30)),
    SchoolPeriod(number: 2, start: ClockTime(9, 40), end: ClockTime(10, 20)),
    SchoolPeriod(number: 3, start: ClockTime(10, 30), end: ClockTime(11, 10)),
    SchoolPeriod(number: 4, start: ClockTime(11, 20), end: ClockTime(12, 0)),
    SchoolPeriod(number: 5, start: ClockTime(12, 10), end: ClockTime(12, 50)),
  ];

  /// 通常4コマの曜日の短縮日課（50分 × 4）
  static const List<SchoolPeriod> shortenedFourPeriodDay = [
    SchoolPeriod(number: 1, start: ClockTime(8, 50), end: ClockTime(9, 40)),
    SchoolPeriod(number: 2, start: ClockTime(9, 50), end: ClockTime(10, 40)),
    SchoolPeriod(number: 3, start: ClockTime(10, 50), end: ClockTime(11, 40)),
    SchoolPeriod(number: 4, start: ClockTime(11, 50), end: ClockTime(12, 40)),
  ];

  // ------------------------------------------------------------
  // 試験日課
  // ------------------------------------------------------------

  /// 定期試験の日の時程（3コマ）
  static const List<SchoolPeriod> examPeriods = [
    SchoolPeriod(number: 1, start: ClockTime(9, 0), end: ClockTime(10, 0)),
    SchoolPeriod(number: 2, start: ClockTime(10, 15), end: ClockTime(11, 15)),
    SchoolPeriod(number: 3, start: ClockTime(11, 30), end: ClockTime(12, 30)),
  ];

  // ------------------------------------------------------------
  // 曜日
  // ------------------------------------------------------------

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

  /// その曜日の通常日課の時限一覧
  static List<SchoolPeriod> periodsFor(int weekday) {
    return all.take(periodCountFor(weekday)).toList();
  }

  /// 日課と曜日から、その日の時限一覧を決める
  static List<SchoolPeriod> periodsForSchedule(
    DaySchedule schedule,
    int weekday,
  ) {
    switch (schedule) {
      case DaySchedule.regular:
        return periodsFor(weekday);
      case DaySchedule.shortened:
        // 通常のコマ数によって、40分×5 か 50分×4 かが決まる
        final count = periodCountFor(weekday);
        if (count == 5) return shortenedFivePeriodDay;
        if (count == 4) return shortenedFourPeriodDay;
        return const [];
      case DaySchedule.exam:
        return examPeriods;
    }
  }

  /// その曜日に、その時限が「通常の授業」として存在するか
  /// （例：水曜の5限 → false）
  static bool isRegularPeriod(int weekday, int periodNumber) {
    return periodNumber >= 1 && periodNumber <= periodCountFor(weekday);
  }

  /// 時限の番号から通常日課の標準時刻を取り出す（1〜5以外はエラー）
  static SchoolPeriod byNumber(int periodNumber) {
    return all.firstWhere(
      (p) => p.number == periodNumber,
      orElse: () => throw ArgumentError('存在しない時限です: $periodNumber'),
    );
  }
}
