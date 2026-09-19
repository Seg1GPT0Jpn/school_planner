/// 定期の予定の保存・読み込み
library;

import 'package:cloud_firestore/cloud_firestore.dart';

import '../events/event_category.dart';
import '../timetable/school_periods.dart';
import '../timetable/week_cycle.dart';
import 'recurring_schedule.dart';

class RecurringRepository {
  RecurringRepository({required this.uid, FirebaseFirestore? firestore})
    : _db = firestore ?? FirebaseFirestore.instance;

  final String uid;
  final FirebaseFirestore _db;

  CollectionReference<Map<String, dynamic>> get _col =>
      _db.collection('users').doc(uid).collection('recurring_schedules');

  Stream<List<RecurringSchedule>> watch() => _col.snapshots().map(
    (s) => [for (final d in s.docs) fromMap(d.id, d.data())],
  );

  Future<void> save(RecurringSchedule r) async {
    if (r.id == null) {
      await _col.add(toMap(r));
    } else {
      await _col.doc(r.id).set(toMap(r));
    }
  }

  Future<void> delete(String id) => _col.doc(id).delete();

  Future<void> setSkipped(String id, DateTime date, bool skipped) {
    final key = dateKey(date);
    return _col.doc(id).update({
      'skippedDates': skipped
          ? FieldValue.arrayUnion([key])
          : FieldValue.arrayRemove([key]),
    });
  }

  static DateTime? _date(Object? v) {
    if (v is! String) return null;
    final p = v.split('-').map(int.parse).toList();
    return DateTime(p[0], p[1], p[2]);
  }

  static ClockTime _time(Object? v) {
    final p = (v as String).split(':').map(int.parse).toList();
    return ClockTime(p[0], p[1]);
  }

  static Map<String, dynamic>? _testToMap(RecurringTestConfig? t) => t == null
      ? null
      : {
          'title': t.title.trim(),
          'baseDate': t.baseDate == null ? null : dateKey(t.baseDate!),
          'baseStart': t.baseStart,
          'step': t.step,
          'withReview': t.withReview,
        };

  static RecurringTestConfig? _testFromMap(Object? v) {
    if (v is! Map) return null;
    final m = Map<String, dynamic>.from(v);
    return RecurringTestConfig(
      title: m['title'] as String? ?? '',
      baseDate: _date(m['baseDate']),
      baseStart: (m['baseStart'] as num?)?.toInt(),
      step: (m['step'] as num?)?.toInt() ?? 50,
      withReview: m['withReview'] as bool? ?? false,
    );
  }

  static Map<String, dynamic> toMap(RecurringSchedule r) => {
    'title': r.title.trim(),
    'weekdays': r.weekdays.toList()..sort(),
    'start': r.start.toString(),
    'end': r.end.toString(),
    'validFrom': r.validFrom == null ? null : dateKey(r.validFrom!),
    'validUntil': r.validUntil == null ? null : dateKey(r.validUntil!),
    'categoryId': r.categoryId,
    'location': (r.location?.trim().isEmpty ?? true)
        ? null
        : r.location!.trim(),
    'skippedDates': r.skippedDates.toList()..sort(),
    'test': _testToMap(r.test),
  };

  static RecurringSchedule fromMap(String id, Map<String, dynamic> m) {
    return RecurringSchedule(
      id: id,
      title: m['title'] as String? ?? '',
      // 新しい形（weekdays）→ 古い形（weekday 1つ）の順に読む
      weekdays: m['weekdays'] is List
          ? {for (final w in m['weekdays'] as List) (w as num).toInt()}
          : {(m['weekday'] as num).toInt()},
      start: _time(m['start']),
      end: _time(m['end']),
      validFrom: _date(m['validFrom']),
      validUntil: _date(m['validUntil']),
      categoryId: m['categoryId'] as String? ?? EventCategory.otherId,
      location: m['location'] as String?,
      skippedDates: {
        for (final s in (m['skippedDates'] as List<dynamic>? ?? const []))
          s as String,
      },
      test: _testFromMap(m['test']),
    );
  }
}
