/// 時間が重なる予定を、横に並べるための計算
library;

import 'dart:math' as math;

/// 時間の範囲（その日の 0:00 からの分数）
class TimeRange {
  const TimeRange(this.start, this.end);

  final int start;
  final int end;
}

/// 並べ方の結果：何列中の何列目に置くか
class LayoutSlot {
  const LayoutSlot(this.column, this.columnCount);

  /// 0 から数えた列の番号
  final int column;

  /// そのまとまりの列の数（幅を何等分するか）
  final int columnCount;

  @override
  bool operator ==(Object other) =>
      other is LayoutSlot &&
      other.column == column &&
      other.columnCount == columnCount;

  @override
  int get hashCode => Object.hash(column, columnCount);

  @override
  String toString() => '($column/$columnCount)';
}

/// 重なりを考えて、それぞれの予定の列を決める
///
/// 1. 開始が早い順に並べる
/// 2. 空いている一番左の列に置く
/// 3. 重なりが続いているまとまりごとに、列の数を決める
List<LayoutSlot> layoutOverlaps(List<TimeRange> ranges) {
  final order = List<int>.generate(ranges.length, (i) => i)
    ..sort((a, b) {
      final byStart = ranges[a].start.compareTo(ranges[b].start);
      if (byStart != 0) return byStart;
      return ranges[b].end.compareTo(ranges[a].end); // 長い方を先に
    });

  final result = List<LayoutSlot?>.filled(ranges.length, null);
  final columnOf = <int, int>{};

  var cluster = <int>[];
  var columnEnds = <int>[]; // 各列で、最後に置いた予定の終わりの時刻
  var clusterEnd = -1;

  void finishCluster() {
    for (final i in cluster) {
      result[i] = LayoutSlot(columnOf[i]!, columnEnds.length);
    }
    cluster = [];
    columnEnds = [];
    clusterEnd = -1;
  }

  for (final i in order) {
    final range = ranges[i];

    // 今のまとまりのどれとも重ならなければ、まとまりを区切る
    if (cluster.isNotEmpty && range.start >= clusterEnd) {
      finishCluster();
    }

    // 空いている一番左の列を探す（なければ新しい列）
    var column = columnEnds.indexWhere((end) => end <= range.start);
    if (column == -1) {
      column = columnEnds.length;
      columnEnds.add(range.end);
    } else {
      columnEnds[column] = range.end;
    }

    columnOf[i] = column;
    cluster.add(i);
    clusterEnd = math.max(clusterEnd, range.end);
  }
  finishCluster();

  return result.cast<LayoutSlot>();
}
