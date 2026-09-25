/// 拍子記号
library;

/// 拍子記号（例：4/4、3/4、6/8）
class TimeSignature {
  const TimeSignature(this.numerator, this.denominator);

  /// 分子（1小節にいくつ入るか）
  final int numerator;

  /// 分母（何分音符を1拍とするか。4・8・2・16 など）
  final int denominator;

  /// 1小節分の長さ（4分音符を1拍とした長さ）
  double get beatsPerMeasure => numerator * (4.0 / denominator);

  /// 「4/4」のような表示
  String get label => '$numerator/$denominator';

  Map<String, dynamic> toMap() => {
    'numerator': numerator,
    'denominator': denominator,
  };

  static TimeSignature fromMap(Map<String, dynamic> m) => TimeSignature(
    (m['numerator'] as num?)?.toInt() ?? 4,
    (m['denominator'] as num?)?.toInt() ?? 4,
  );

  @override
  bool operator ==(Object other) =>
      other is TimeSignature &&
      other.numerator == numerator &&
      other.denominator == denominator;

  @override
  int get hashCode => Object.hash(numerator, denominator);

  @override
  String toString() => label;
}

/// よく使う拍子記号
const List<TimeSignature> commonTimeSignatures = [
  TimeSignature(4, 4),
  TimeSignature(3, 4),
  TimeSignature(2, 4),
  TimeSignature(6, 8),
  TimeSignature(9, 8),
  TimeSignature(12, 8),
  TimeSignature(2, 2),
  TimeSignature(5, 4),
];
