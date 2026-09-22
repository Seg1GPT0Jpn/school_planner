/// 持ち物の設定とチェックの保存
library;

import 'package:cloud_firestore/cloud_firestore.dart';

import '../timetable/week_cycle.dart';
import 'belongings.dart';

class BelongingsRepository {
  BelongingsRepository({required this.uid, FirebaseFirestore? firestore})
    : _db = firestore ?? FirebaseFirestore.instance;

  final String uid;
  final FirebaseFirestore _db;

  DocumentReference<Map<String, dynamic>> get _settings =>
      _db.collection('users').doc(uid).collection('settings').doc('belongings');

  DocumentReference<Map<String, dynamic>> _checks(DateTime d) => _db
      .collection('users')
      .doc(uid)
      .collection('belonging_checks')
      .doc(dateKey(d));

  static List<String> _list(Object? v) => [
    for (final x in (v as List<dynamic>? ?? const [])) x as String,
  ];

  static Map<String, List<String>> _map(Object? v) => {
    for (final e in (v as Map<dynamic, dynamic>? ?? const {}).entries)
      e.key as String: _list(e.value),
  };

  Stream<BelongingSettings> watchSettings() => _settings.snapshots().map((s) {
    final m = s.data() ?? const <String, dynamic>{};
    return BelongingSettings(
      daily: _list(m['daily']),
      bySubject: _map(m['bySubject']),
      byRecurring: _map(m['byRecurring']),
    );
  });

  Future<void> saveSettings(BelongingSettings b) => _settings.set({
    'daily': b.daily,
    'bySubject': b.bySubject,
    'byRecurring': b.byRecurring,
  });

  /// その日にチェックした持ち物
  Stream<Set<String>> watchChecked(DateTime d) =>
      _checks(d).snapshots().map((s) => _list(s.data()?['checked']).toSet());

  Future<void> setChecked(DateTime d, String item, bool checked) =>
      _checks(d).set({
        'checked': checked
            ? FieldValue.arrayUnion([item])
            : FieldValue.arrayRemove([item]),
      }, SetOptions(merge: true));

  // ------------------------------------------------------------
  // 忘れ物探偵：持ち物ごとに「最後に持っていった日」を覚える
  // ------------------------------------------------------------

  DocumentReference<Map<String, dynamic>> get _lastBrought => _db
      .collection('users')
      .doc(uid)
      .collection('settings')
      .doc('belongings_last_brought');

  /// 持ち物ごとの「最後に持っていった日時」
  Stream<Map<String, DateTime>> watchLastBrought() =>
      _lastBrought.snapshots().map((s) {
        final raw = s.data()?['items'] as Map<String, dynamic>? ?? const {};
        return {
          for (final e in raw.entries)
            if (e.value is Timestamp)
              e.key: (e.value as Timestamp).toDate(),
        };
      });

  /// この持ち物を「今、持っていった」と記録する
  Future<void> markBrought(String item, {DateTime? when}) => _lastBrought.set(
    {
      'items': {item: Timestamp.fromDate(when ?? DateTime.now())},
    },
    SetOptions(merge: true),
  );
}
