/// 小テスト・学校イベントと、毎週のテストのルールの保存・読み込み
library;

import 'package:cloud_firestore/cloud_firestore.dart';

import '../timetable/school_periods.dart';
import '../timetable/week_cycle.dart';
import 'initial_rules.dart';
import 'school_test.dart';
import 'weekly_lesson_test.dart';

class SchoolTestRepository {
  SchoolTestRepository({required this.uid, FirebaseFirestore? firestore})
    : _db = firestore ?? FirebaseFirestore.instance;

  final String uid;
  final FirebaseFirestore _db;

  CollectionReference<Map<String, dynamic>> get _tests =>
      _db.collection('users').doc(uid).collection('school_tests');

  CollectionReference<Map<String, dynamic>> get _rules =>
      _db.collection('users').doc(uid).collection('weekly_test_rules');

  // ------------------------------------------------------------
  // 小テスト・学校イベント
  // ------------------------------------------------------------

  /// 保存する（新しいものなら追加、既存のものなら上書き）
  Future<void> save(SchoolTest test) async {
    final data = testToMap(test);
    if (test.id == null) {
      await _tests.add({
        ...data,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } else {
      await _tests.doc(test.id).update({
        ...data,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    }
  }

  /// 削除する
  Future<void> delete(String id) => _tests.doc(id).delete();

  // ------------------------------------------------------------
  // 毎週のテストのルール（LEAP など）
  // ------------------------------------------------------------

  /// ルールがまだなければ、LEAP のルールを登録する
  Future<void> ensureDefaultRules() async {
    final doc = _rules.doc(leapRule.id);
    if ((await doc.get()).exists) return;
    await doc.set(ruleToMap(leapRule));
  }

  /// その週を「なし」にする／戻す
  Future<void> setWeekSkipped(
    String ruleId,
    DateTime anyDateInWeek,
    bool skipped,
  ) {
    final key = dateKey(mondayOf(anyDateInWeek));
    return _rules.doc(ruleId).set({
      'skippedWeeks': skipped
          ? FieldValue.arrayUnion([key])
          : FieldValue.arrayRemove([key]),
    }, SetOptions(merge: true));
  }

  // ------------------------------------------------------------
  // 変換（Firestore の形 ⇔ アプリの形）
  // ------------------------------------------------------------

  static String? _emptyToNull(String? s) =>
      (s == null || s.trim().isEmpty) ? null : s.trim();

  static DateTime _parseDate(String key) {
    final parts = key.split('-').map(int.parse).toList();
    return DateTime(parts[0], parts[1], parts[2]);
  }

  static ClockTime? _parseTime(Object? value) {
    if (value is! String) return null;
    final parts = value.split(':').map(int.parse).toList();
    return ClockTime(parts[0], parts[1]);
  }

  static Map<String, dynamic> testToMap(SchoolTest t) => {
    'kind': t.kind.name,
    'title': t.title.trim(),
    'date': dateKey(t.date),
    'subject': t.subject,
    'period': t.period,
    'startTime': t.startTime?.toString(),
    'scope': _emptyToNull(t.scope),
    'memo': _emptyToNull(t.memo),
  };

  static SchoolTest testFromMap(String id, Map<String, dynamic> m) {
    return SchoolTest(
      id: id,
      kind: SchoolTestKind.values.asNameMap()[m['kind']] ?? SchoolTestKind.quiz,
      title: m['title'] as String? ?? '',
      date: _parseDate(m['date'] as String),
      subject: m['subject'] as String?,
      period: (m['period'] as num?)?.toInt(),
      startTime: _parseTime(m['startTime']),
      scope: m['scope'] as String?,
      memo: m['memo'] as String?,
    );
  }

  static Map<String, dynamic> ruleToMap(WeeklyLessonTestRule r) => {
    'subject': r.subject,
    'title': r.title,
    'baseWeekDate': dateKey(r.baseWeekDate),
    'baseRangeStart': r.baseRangeStart,
    'rangeStep': r.rangeStep,
    'skippedWeeks': r.skippedWeeks.toList()..sort(),
  };

  static WeeklyLessonTestRule ruleFromMap(String id, Map<String, dynamic> m) {
    return WeeklyLessonTestRule(
      id: id,
      subject: m['subject'] as String,
      title: m['title'] as String,
      baseWeekDate: _parseDate(m['baseWeekDate'] as String),
      baseRangeStart: (m['baseRangeStart'] as num).toInt(),
      rangeStep: (m['rangeStep'] as num?)?.toInt() ?? 100,
      skippedWeeks: {
        for (final w in (m['skippedWeeks'] as List<dynamic>? ?? const []))
          w as String,
      },
    );
  }
}
