/// つづりクエスト（勉強RPG）との連携
///
/// - つづり → クエスト：`users/{uid}/quest_link/upcoming`（これからのテスト・提出物）
/// - クエスト → つづり：`users/{uid}/study_sessions/quest_…`（勉強時間。メモは「つづりクエスト」）と
///   `users/{uid}/quest_link/results`（解いた問題数・正答率・苦手な単元）
///
/// クエストは、つづりと同じ Google アカウントでつづりの Firebase にログインして、
/// 本人の場所（users/{uid}/）だけを読み書きする。
library;

import 'package:cloud_firestore/cloud_firestore.dart';

import '../school_tests/upcoming_tests.dart';
import '../timetable/week_cycle.dart';

/// つづりクエストの Web 版
const questUrl = 'https://tsuzuri-quest-v2.web.app';

/// クエストから届いた勉強記録の目印（勉強記録のメモ）
const questSessionMemo = 'つづりクエスト';

/// クエストへ渡す、これからのテスト・提出物（日付順）
List<Map<String, Object?>> questUpcomingItems(List<UpcomingItem> items) => [
  for (final i in [...items]..sort((a, b) => a.date.compareTo(b.date)))
    {
      'date': dateKey(i.date),
      'title': i.title,
      'kind': i.kindLabel,
      'isTest': i.isTest,
      'subject': i.subject,
      'detail': i.detail,
      'period': i.period,
    },
];

/// 1日（または1週間）ぶんのクエストの成果
class QuestSum {
  const QuestSum({this.minutes = 0, this.answered = 0, this.correct = 0});

  final int minutes;
  final int answered;
  final int correct;

  /// 正答率（0〜100。答えていなければ null）
  int? get accuracy =>
      answered == 0 ? null : (correct * 100 / answered).round();

  static QuestSum fromMap(Object? m) {
    if (m is! Map) return const QuestSum();
    int v(String k) => (m[k] as num?)?.toInt() ?? 0;
    return QuestSum(
      minutes: v('minutes'),
      answered: v('answered'),
      correct: v('correct'),
    );
  }
}

/// クエストの苦手な単元
class QuestWeakUnit {
  const QuestWeakUnit(this.unit, this.accuracy);
  final String unit;
  final int accuracy;
}

/// クエストから届いた成果
class QuestResults {
  const QuestResults({
    required this.today,
    required this.week,
    required this.weak,
    this.updatedAt,
  });

  final QuestSum today;
  final QuestSum week;
  final List<QuestWeakUnit> weak;

  /// クエストが最後に送った時刻
  final DateTime? updatedAt;

  /// 届いた日がきょうでなければ、きょうの分は 0 として扱う
  QuestSum todayAt(DateTime now) {
    final u = updatedAt;
    if (u == null) return today;
    return u.year == now.year && u.month == now.month && u.day == now.day
        ? today
        : const QuestSum();
  }

  static QuestResults? fromMap(Map<String, dynamic>? m) {
    if (m == null) return null;
    final at = m['updatedAt'];
    return QuestResults(
      today: QuestSum.fromMap(m['today']),
      week: QuestSum.fromMap(m['week']),
      weak: [
        for (final w in (m['weak'] as List?) ?? const [])
          if (w is Map && w['unit'] is String)
            QuestWeakUnit(
              w['unit'] as String,
              (w['accuracy'] as num?)?.toInt() ?? 0,
            ),
      ],
      updatedAt: at is Timestamp ? at.toDate() : null,
    );
  }
}

class QuestLinkRepository {
  QuestLinkRepository({required this.uid, FirebaseFirestore? firestore})
    : _db = firestore ?? FirebaseFirestore.instance;

  final String uid;
  final FirebaseFirestore _db;

  DocumentReference<Map<String, dynamic>> get _doc =>
      _db.collection('users').doc(uid).collection('quest_link').doc('upcoming');

  /// 前回書いた内容（同じなら書かない）
  static String? _lastSent;

  /// これからのテスト・提出物をクエストへ渡す（変わったときだけ書く）
  Future<void> exportUpcoming(List<UpcomingItem> items) async {
    final list = questUpcomingItems(items);
    final key = '$uid|$list';
    if (_lastSent == key) return;
    _lastSent = key;
    await _doc.set({
      'v': 1,
      'items': list,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  /// クエストから届いた成果（まだなければ null）
  Stream<QuestResults?> watchResults() => _db
      .collection('users')
      .doc(uid)
      .collection('quest_link')
      .doc('results')
      .snapshots()
      .map((s) => QuestResults.fromMap(s.data()));
}
