/// Ⅰ週・Ⅱ週の判定
library;

/// 週の種類
enum WeekType {
  one('Ⅰ週'),
  two('Ⅱ週');

  const WeekType(this.label);

  /// 画面表示用の名前
  final String label;

  /// 反対の週（Ⅰ週 ⇔ Ⅱ週）
  WeekType get other => this == WeekType.one ? WeekType.two : WeekType.one;
}

/// 時刻を切り捨てて「日付だけ」にする
///
/// 日数の計算がずれないように、UTC（世界標準時）として扱う。
/// ※ 年・月・日の数字はそのまま使うので、日本の日付として正しく扱える。
DateTime dateOnly(DateTime date) =>
    DateTime.utc(date.year, date.month, date.day);

/// その日を含む週の「月曜日」
DateTime mondayOf(DateTime date) {
  final day = dateOnly(date);
  return day.subtract(Duration(days: day.weekday - DateTime.monday));
}

/// 「2026-09-21」のような文字列（データ保存のキーに使う）
String dateKey(DateTime date) {
  final y = date.year.toString().padLeft(4, '0');
  final m = date.month.toString().padLeft(2, '0');
  final d = date.day.toString().padLeft(2, '0');
  return '$y-$m-$d';
}

/// 基準日：「この日の週は Ⅰ週（またはⅡ週）」という設定
///
/// 学期・長期休暇明けなど、以後のサイクルそのものを決め直すときに使う。
class WeekAnchor {
  const WeekAnchor({required this.date, required this.weekType});

  final DateTime date;
  final WeekType weekType;
}

/// Ⅰ週・Ⅱ週を判定する計算機
class WeekCycleCalculator {
  WeekCycleCalculator({
    required List<WeekAnchor> anchors,
    this._weekOverrides = const {},
    this.enabled = true,
  }) : _anchors = [...anchors]
         ..sort((a, b) => mondayOf(a.date).compareTo(mondayOf(b.date)));

  /// Ⅰ週・Ⅱ週を使うか（false なら毎週同じ時間割。週の種類は null になる）
  final bool enabled;

  /// 基準日（古い順に並べ替え済み）
  final List<WeekAnchor> _anchors;

  /// 週単位の例外（キー：その週の月曜日の dateKey）
  final Map<String, WeekType> _weekOverrides;

  /// その日が Ⅰ週かⅡ週か（週単位override を優先）
  ///
  /// 判定できない場合（基準日が未設定など）は null を返す。
  WeekType? weekTypeFor(DateTime date) {
    if (!enabled) return null;
    final override = _weekOverrides[dateKey(mondayOf(date))];
    if (override != null) return override;
    return autoWeekTypeFor(date);
  }

  /// その週に週単位override が設定されているか
  bool isOverridden(DateTime date) {
    if (!enabled) return false;
    return _weekOverrides.containsKey(dateKey(mondayOf(date)));
  }

  /// 基準日だけを使った自動判定（週単位override は無視）
  WeekType? autoWeekTypeFor(DateTime date) {
    final targetMonday = mondayOf(date);

    // 対象の週より前（同じ週を含む）で、一番新しい基準日を探す
    WeekAnchor? anchor;
    for (final candidate in _anchors) {
      if (mondayOf(candidate.date).isAfter(targetMonday)) break;
      anchor = candidate;
    }
    if (anchor == null) return null;

    // 基準日の週から何週たったか
    final weeksPassed =
        targetMonday.difference(mondayOf(anchor.date)).inDays ~/ 7;

    // 偶数週なら基準日と同じ、奇数週なら反対
    return weeksPassed.isEven ? anchor.weekType : anchor.weekType.other;
  }
}
