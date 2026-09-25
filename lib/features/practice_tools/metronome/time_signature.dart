/// 拍子（拍数・音価・グループ構造）
///
/// 「5拍子は2+3か3+2」のような特別扱いをやめて、どの拍子でも
/// 任意のグループ分け（例：7拍子＝2+2+3、3+2+2、2+3+2 …）を持てるようにする。
library;

/// 拍子。[beats] は1小節の拍数、[denominator] は音価（4分音符＝4、8分音符＝8）。
/// [grouping] は拍のまとまり方（合計が [beats] になるリスト）。
class TimeSignature {
  const TimeSignature({
    required this.beats,
    required this.denominator,
    required this.grouping,
    this.label,
  });

  final int beats;
  final int denominator;

  /// 拍のグループ分け（例：7拍子[2,2,3]なら「1-2 / 3-4 / 5-6-7」）
  final List<int> grouping;

  final String? label;

  String get display => label ?? '$beats/$denominator';

  /// 拍index（0始まり）が、あるグループの先頭かどうか
  bool isGroupStart(int beatIndex) {
    if (beatIndex == 0) return true;
    var acc = 0;
    for (final g in grouping) {
      if (acc == beatIndex) return true;
      acc += g;
      if (acc > beatIndex) return false;
    }
    return false;
  }

  TimeSignature copyWith({List<int>? grouping}) => TimeSignature(
    beats: beats,
    denominator: denominator,
    grouping: grouping ?? this.grouping,
    label: null,
  );

  static List<int> evenGrouping(int beats) => [beats];

  @override
  bool operator ==(Object other) =>
      other is TimeSignature &&
      other.beats == beats &&
      other.denominator == denominator &&
      _listEq(other.grouping, grouping);

  @override
  int get hashCode => Object.hash(beats, denominator, Object.hashAll(grouping));
}

bool _listEq(List<int> a, List<int> b) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}

/// よく使う拍子と、代表的なグループ分けのプリセット
const List<TimeSignature> commonTimeSignatures = [
  TimeSignature(beats: 2, denominator: 4, grouping: [2]),
  TimeSignature(beats: 3, denominator: 4, grouping: [3]),
  TimeSignature(beats: 4, denominator: 4, grouping: [4]),
  TimeSignature(beats: 5, denominator: 4, grouping: [2, 3], label: '5/4（2+3）'),
  TimeSignature(beats: 5, denominator: 4, grouping: [3, 2], label: '5/4（3+2）'),
  TimeSignature(beats: 6, denominator: 4, grouping: [3, 3]),
  TimeSignature(beats: 6, denominator: 8, grouping: [3, 3]),
  TimeSignature(beats: 7, denominator: 8, grouping: [2, 2, 3], label: '7/8（2+2+3）'),
  TimeSignature(beats: 7, denominator: 8, grouping: [3, 2, 2], label: '7/8（3+2+2）'),
  TimeSignature(beats: 7, denominator: 8, grouping: [2, 3, 2], label: '7/8（2+3+2）'),
  TimeSignature(beats: 8, denominator: 8, grouping: [3, 3, 2], label: '8/8（3+3+2）'),
  TimeSignature(beats: 9, denominator: 8, grouping: [2, 2, 2, 3], label: '9/8（2+2+2+3）'),
  TimeSignature(beats: 9, denominator: 8, grouping: [3, 3, 3], label: '9/8（3+3+3）'),
  TimeSignature(beats: 10, denominator: 8, grouping: [3, 3, 2, 2], label: '10/8（3+3+2+2）'),
  TimeSignature(beats: 11, denominator: 8, grouping: [3, 3, 3, 2], label: '11/8（3+3+3+2）'),
  TimeSignature(beats: 12, denominator: 8, grouping: [3, 3, 3, 3]),
];
