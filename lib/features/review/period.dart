/// レビューの期間（週・月・学期）
library;

enum ReviewKind {
  week('週'),
  month('月'),
  term('学期');

  const ReviewKind(this.label);
  final String label;
}

/// 期間（start から end の前日まで。end は含まない）
class ReviewPeriod {
  const ReviewPeriod(
    this.kind,
    this.start,
    this.end, {
    this.weekStart = DateTime.sunday,
  });

  final ReviewKind kind;
  final DateTime start;
  final DateTime end;

  /// 週の始まり（週のときだけ使う）
  final int weekStart;

  /// d を含む期間
  ///
  /// 学期は前期（4/1〜9/30）・後期（10/1〜3/31）。
  factory ReviewPeriod.of(
    ReviewKind kind,
    DateTime d, {
    int weekStart = DateTime.sunday,
  }) {
    final day = DateTime(d.year, d.month, d.day);
    switch (kind) {
      case ReviewKind.week:
        final offset = (day.weekday - weekStart + 7) % 7;
        final s = DateTime(day.year, day.month, day.day - offset);
        return ReviewPeriod(
          kind,
          s,
          DateTime(s.year, s.month, s.day + 7),
          weekStart: weekStart,
        );
      case ReviewKind.month:
        return ReviewPeriod(
          kind,
          DateTime(day.year, day.month, 1),
          DateTime(day.year, day.month + 1, 1),
        );
      case ReviewKind.term:
        final schoolYear = day.month >= 4 ? day.year : day.year - 1;
        final first = day.month >= 4 && day.month <= 9;
        return first
            ? ReviewPeriod(
                kind,
                DateTime(schoolYear, 4, 1),
                DateTime(schoolYear, 10, 1),
              )
            : ReviewPeriod(
                kind,
                DateTime(schoolYear, 10, 1),
                DateTime(schoolYear + 1, 4, 1),
              );
    }
  }

  /// 前の期間
  ReviewPeriod get previous => ReviewPeriod.of(
    kind,
    DateTime(start.year, start.month, start.day - 1),
    weekStart: weekStart,
  );

  /// 次の期間
  ReviewPeriod get next => ReviewPeriod.of(kind, end, weekStart: weekStart);

  /// 日数
  int get days => DateTime.utc(
    end.year,
    end.month,
    end.day,
  ).difference(DateTime.utc(start.year, start.month, start.day)).inDays;

  /// 最後の日
  DateTime get lastDay => DateTime(end.year, end.month, end.day - 1);

  bool contains(DateTime d) {
    final x = DateTime(d.year, d.month, d.day);
    return !x.isBefore(start) && x.isBefore(end);
  }

  /// 学校の年度（4月はじまり）
  int get schoolYear => start.month >= 4 ? start.year : start.year - 1;

  /// 画面に出す名前
  String get label => switch (kind) {
    ReviewKind.week =>
      '${start.month}/${start.day}〜${lastDay.month}/${lastDay.day}',
    ReviewKind.month => '${start.year}年${start.month}月',
    ReviewKind.term => '$schoolYear年度 ${start.month == 4 ? '前期' : '後期'}',
  };

  /// 保存するときの名前（ふり返りのメモなど）
  String get key {
    String two(int n) => n.toString().padLeft(2, '0');
    return switch (kind) {
      ReviewKind.week =>
        'week_${start.year}-${two(start.month)}-${two(start.day)}',
      ReviewKind.month => 'month_${start.year}-${two(start.month)}',
      ReviewKind.term => 'term_${schoolYear}_${start.month == 4 ? 1 : 2}',
    };
  }
}
