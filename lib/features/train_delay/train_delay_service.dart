/// 電車の遅延情報を取ってくる係（5分間は同じものを使い回す）
///
/// 実際の取得は Cloud Functions（getTrainStatus）が行う。
/// ODPT（公共交通オープンデータセンター）のAPIキーはサーバー側だけに置き、
/// アプリ本体には一切含めない。
library;

import 'package:cloud_functions/cloud_functions.dart';

import 'free_delay_service.dart';
import 'train_delay_models.dart';
import 'train_lines.dart';

class TrainDelayService {
  TrainDelayService._();
  static final instance = TrainDelayService._();

  static const _keep = Duration(minutes: 5);

  TrainStatusBundle? _last;
  List<String>? _lastLineIds;
  Future<TrainStatusBundle>? _loading;

  /// 指定した路線の運行状況（5分以内・同じ路線なら前のものを返す）
  Future<TrainStatusBundle> load(
    List<String> lineIds, {
    bool force = false,
  }) {
    final last = _last;
    final sameLines =
        _lastLineIds != null &&
        _lastLineIds!.length == lineIds.length &&
        _lastLineIds!.toSet().containsAll(lineIds);
    if (!force &&
        last != null &&
        sameLines &&
        DateTime.now().difference(last.fetchedAt) < _keep) {
      return Future.value(last);
    }
    return _loading ??= _fetch(
      lineIds,
    ).whenComplete(() => _loading = null);
  }

  TrainStatusBundle? get cached => _last;

  Future<TrainStatusBundle> _fetch(List<String> lineIds) async {
    if (lineIds.isEmpty) {
      final bundle = TrainStatusBundle(
        fetchedAt: DateTime.now(),
        statuses: const {},
      );
      _last = bundle;
      _lastLineIds = lineIds;
      return bundle;
    }
    try {
      final callable = FirebaseFunctions.instanceFor(
        region: 'asia-northeast1',
      ).httpsCallable('getTrainStatus');
      final res = await callable.call<Map<String, dynamic>>({
        'lineIds': lineIds,
      });
      final data = res.data;
      final results = (data['results'] as List<dynamic>? ?? const [])
          .whereType<Map>()
          .map((e) => TrainStatus.fromJson(Map<String, dynamic>.from(e)))
          .toList();
      final statuses = {for (final s in results) s.railwayId: s};
      final bundle = TrainStatusBundle(
        fetchedAt: DateTime.now(),
        statuses: statuses,
      );
      _last = bundle;
      _lastLineIds = lineIds;
      return bundle;
    } catch (e) {
      // いつもの情報源（ODPT・Cloud Functions）が使えないときは、
      // キー不要の代わりの情報源から、実際の遅延情報を読み取って表示する
      try {
        final free = await FreeDelayService.instance.load();
        final statuses = <String, TrainStatus>{
          for (final id in lineIds)
            if (findTrainLine(id) case final line?)
              id: _statusFromFree(id, line.name, free),
        };
        final bundle = TrainStatusBundle(
          fetchedAt: DateTime.now(),
          statuses: statuses,
          source: 'free',
        );
        _last = bundle;
        _lastLineIds = lineIds;
        return bundle;
      } catch (_) {
        final bundle = TrainStatusBundle(
          fetchedAt: DateTime.now(),
          statuses: _last?.statuses ?? const {},
          error: '$e',
        );
        _last = bundle;
        _lastLineIds = lineIds;
        return bundle;
      }
    }
  }

  /// 代わりの情報源（いま遅延している路線だけの一覧）から、1路線ぶんの状況を作る
  TrainStatus _statusFromFree(
    String railwayId,
    String lineName,
    List<FreeDelayInfo> free,
  ) {
    final match = FreeDelayService.findFor(free, lineName);
    if (match == null) {
      return TrainStatus(railwayId: railwayId, status: '平常運転', text: '');
    }
    final text = match.text;
    final status = text.contains('見合わせ')
        ? '運転見合わせ'
        : text.contains('運休')
        ? '運休'
        : '遅延';
    return TrainStatus(railwayId: railwayId, status: status, text: text);
  }
}
