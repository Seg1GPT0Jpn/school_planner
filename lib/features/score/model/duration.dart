/// 音符・休符の長さ（音価）
library;

/// 基本の音価（付点なし）
enum NoteDurationBase {
  whole(4.0, '全音符'),
  half(2.0, '2分音符'),
  quarter(1.0, '4分音符'),
  eighth(0.5, '8分音符'),
  sixteenth(0.25, '16分音符'),
  thirtySecond(0.125, '32分音符');

  const NoteDurationBase(this.quarterBeats, this.label);

  /// 4分音符を1拍としたときの長さ
  final double quarterBeats;
  final String label;
}

/// 音価（基本の長さ＋付点の数）。3連符などの連符は [tupletRatio] で表す
/// （例：8分音符3つで4分音符2つ分の3連符なら tupletRatio = 2/3）
class NoteDuration {
  const NoteDuration(this.base, {this.dots = 0, this.tupletRatio = 1.0})
    : assert(dots >= 0 && dots <= 3),
      assert(tupletRatio > 0);

  final NoteDurationBase base;

  /// 付点の数（0〜3）
  final int dots;

  /// 連符による倍率（連符でなければ 1.0）
  final double tupletRatio;

  /// 4分音符を1拍としたときの、実際の長さ
  double get beats {
    var value = base.quarterBeats;
    var add = value;
    for (var i = 0; i < dots; i++) {
      add /= 2;
      value += add;
    }
    return value * tupletRatio;
  }

  /// 付点の記号（．．．）
  String get dotsSymbol => '．' * dots;

  Map<String, dynamic> toMap() => {
    'base': base.name,
    'dots': dots,
    'tupletRatio': tupletRatio,
  };

  static NoteDuration fromMap(Map<String, dynamic> m) => NoteDuration(
    NoteDurationBase.values.asNameMap()[m['base']] ?? NoteDurationBase.quarter,
    dots: (m['dots'] as num?)?.toInt() ?? 0,
    tupletRatio: (m['tupletRatio'] as num?)?.toDouble() ?? 1.0,
  );

  NoteDuration copyWith({NoteDurationBase? base, int? dots, double? tupletRatio}) =>
      NoteDuration(
        base ?? this.base,
        dots: dots ?? this.dots,
        tupletRatio: tupletRatio ?? this.tupletRatio,
      );

  @override
  bool operator ==(Object other) =>
      other is NoteDuration &&
      other.base == base &&
      other.dots == dots &&
      other.tupletRatio == tupletRatio;

  @override
  int get hashCode => Object.hash(base, dots, tupletRatio);
}
