/// 個人の所要時間の学習（すべて端末内・ルールベース、外部AIは使わない）
///
/// ToDoを完了したときに「実際どれくらいかかったか」を軽く（任意で）聞き、
/// 見積もりに対する倍率をカテゴリごとに少しずつ学習していく。
/// データが少ないうち（3件未満）は学習を反映せず、元の見積もりのまま。
library;

import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';

import '../todo/todo.dart';
import 'today_plan.dart';

/// 見積もりの元になる ToDo の種類
enum TimingBucket { subtasks, linked, plain }

TimingBucket bucketFor(Todo t) {
  if (t.subtasks.isNotEmpty) return TimingBucket.subtasks;
  if (t.isLinked) return TimingBucket.linked;
  return TimingBucket.plain;
}

/// 学習した倍率（カテゴリごと）
class TimingStats {
  const TimingStats({
    this.subtasksRatio = 1.0,
    this.linkedRatio = 1.0,
    this.plainRatio = 1.0,
    this.subtasksCount = 0,
    this.linkedCount = 0,
    this.plainCount = 0,
  });

  final double subtasksRatio;
  final double linkedRatio;
  final double plainRatio;
  final int subtasksCount;
  final int linkedCount;
  final int plainCount;

  double ratioFor(TimingBucket b) => switch (b) {
    TimingBucket.subtasks => subtasksRatio,
    TimingBucket.linked => linkedRatio,
    TimingBucket.plain => plainRatio,
  };

  int countFor(TimingBucket b) => switch (b) {
    TimingBucket.subtasks => subtasksCount,
    TimingBucket.linked => linkedCount,
    TimingBucket.plain => plainCount,
  };

  static TimingStats fromMap(Map<String, dynamic>? m) {
    if (m == null) return const TimingStats();
    double d(String k) => (m[k] as num?)?.toDouble() ?? 1.0;
    int i(String k) => (m[k] as num?)?.toInt() ?? 0;
    return TimingStats(
      subtasksRatio: d('subtasksRatio'),
      linkedRatio: d('linkedRatio'),
      plainRatio: d('plainRatio'),
      subtasksCount: i('subtasksCount'),
      linkedCount: i('linkedCount'),
      plainCount: i('plainCount'),
    );
  }
}

/// 学習した倍率を反映した見積もり分数
/// （データがまだ少ないカテゴリは、元の [estimateMinutes] のまま）
int estimateMinutesLearned(Todo t, TimingStats stats) {
  final base = estimateMinutes(t);
  final bucket = bucketFor(t);
  if (stats.countFor(bucket) < 3) return base;
  final adjusted = (base * stats.ratioFor(bucket)).round();
  return adjusted.clamp(5, 240);
}

class TimingLearningRepository {
  TimingLearningRepository({required this.uid, FirebaseFirestore? firestore})
    : _db = firestore ?? FirebaseFirestore.instance;

  final String uid;
  final FirebaseFirestore _db;

  DocumentReference<Map<String, dynamic>> get _doc => _db
      .collection('users')
      .doc(uid)
      .collection('settings')
      .doc('timing_learning');

  Stream<TimingStats> watch() =>
      _doc.snapshots().map((s) => TimingStats.fromMap(s.data()));

  Future<TimingStats> fetch() async {
    final s = await _doc.get();
    return TimingStats.fromMap(s.data());
  }

  /// 完了時の「実際どれくらいかかったか」を記録し、倍率を少しずつ更新する
  /// （最初の1件は素直に反映、以降は急に変わりすぎないよう緩やかな移動平均）
  Future<void> record(Todo t, int actualMinutes) async {
    final base = estimateMinutes(t);
    if (base <= 0 || actualMinutes <= 0) return;
    final bucket = bucketFor(t);
    final sampleRatio = (actualMinutes / base).clamp(0.2, 5.0);

    final stats = await fetch();
    final prevRatio = stats.ratioFor(bucket);
    final prevCount = stats.countFor(bucket);
    final newRatio = prevCount == 0
        ? sampleRatio
        : (prevRatio * 0.7 + sampleRatio * 0.3);

    final field = switch (bucket) {
      TimingBucket.subtasks => 'subtasks',
      TimingBucket.linked => 'linked',
      TimingBucket.plain => 'plain',
    };
    await _doc.set({
      '${field}Ratio': newRatio,
      '${field}Count': prevCount + 1,
    }, SetOptions(merge: true));
  }
}
