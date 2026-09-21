/// 電車の運行情報（遅延情報）のデータ
library;

/// 1路線ぶんの運行状況
class TrainStatus {
  const TrainStatus({
    required this.railwayId,
    required this.status,
    required this.text,
    this.time,
  });

  /// ODPT の路線ID
  final String railwayId;

  /// 状況（例：遅延、運転見合わせ、平常運転）
  final String status;

  /// 詳しい説明文
  final String text;

  final DateTime? time;

  /// 平常運転とみなせるか（情報が無いときも平常運転として扱う）
  bool get isNormal =>
      status.isEmpty || status.contains('平常') || status.contains('通常');

  factory TrainStatus.fromJson(Map<String, dynamic> j) {
    DateTime? time;
    final t = j['time'];
    if (t is String) {
      try {
        time = DateTime.parse(t);
      } catch (_) {}
    }
    return TrainStatus(
      railwayId: j['railwayId'] as String? ?? '',
      status: j['status'] as String? ?? '',
      text: j['text'] as String? ?? '',
      time: time,
    );
  }
}

/// 呼び出し結果
class TrainStatusBundle {
  const TrainStatusBundle({
    required this.fetchedAt,
    required this.statuses,
    this.error,
    this.source = 'odpt',
  });

  final DateTime fetchedAt;
  final Map<String, TrainStatus> statuses;
  final String? error;

  /// どこから取ってきたか：'odpt'（いつもの情報源）／'free'（無料の代わりの情報源）
  final String source;
}
