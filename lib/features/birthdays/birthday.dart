/// 誕生日のデータ
library;

/// 誕生日1件（名前・月日。年は任意）
class Birthday {
  const Birthday({
    this.id,
    required this.name,
    required this.month,
    required this.day,
    this.year,
    this.memo,
  });

  /// Firestore の ID（まだ保存していないものは null）
  final String? id;

  final String name;

  /// 1〜12
  final int month;

  /// 1〜31
  final int day;

  /// 生まれた年（わからない・入れたくないときは null）
  final int? year;

  final String? memo;

  Birthday copyWith({
    String? name,
    int? month,
    int? day,
    int? year,
    bool clearYear = false,
    String? memo,
  }) {
    return Birthday(
      id: id,
      name: name ?? this.name,
      month: month ?? this.month,
      day: day ?? this.day,
      year: clearYear ? null : (year ?? this.year),
      memo: memo ?? this.memo,
    );
  }

  /// 入力内容の確認（問題がなければ null、あればメッセージ）
  String? validate() {
    if (name.trim().isEmpty) return '名前を入力してください';
    if (month < 1 || month > 12) return '月が正しくありません';
    if (day < 1 || day > 31) return '日が正しくありません';
    // 2月30日のような存在しない日付を弾く（うるう年は考慮せず29日まで許可）
    const maxDay = [31, 29, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31];
    if (day > maxDay[month - 1]) return 'その月にその日はありません';
    return null;
  }

  /// [from] 以降でいちばん近い誕生日（今日なら今日を返す）
  DateTime nextOccurrence(DateTime from) {
    final today = DateTime(from.year, from.month, from.day);
    var next = DateTime(today.year, month, day);
    if (next.isBefore(today)) {
      next = DateTime(today.year + 1, month, day);
    }
    return next;
  }

  /// [from] から次の誕生日までの日数（今日なら 0）
  int daysUntilNext(DateTime from) {
    final today = DateTime(from.year, from.month, from.day);
    return nextOccurrence(from).difference(today).inDays;
  }

  /// [on] の時点での満年齢（生まれた年が未入力なら null）
  int? ageOn(DateTime on) {
    if (year == null) return null;
    var age = on.year - year!;
    final hadBirthdayThisYear =
        on.month > month || (on.month == month && on.day >= day);
    if (!hadBirthdayThisYear) age -= 1;
    return age;
  }
}
