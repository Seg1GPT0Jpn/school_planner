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

  /// 保存する（新しいものなら追加、既存のものなら上書き）。保存した ID を返す
  Future<String> save(SchoolTest test) async {
    final data = testToMap(test);
    if (test.id == null) {
      final ref = await _tests.add({
        ...data,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      return ref.id;
    }
    await _tests.doc(test.id).update({
      ...data,
      'updatedAt': FieldValue.serverTimestamp(),
    });
    return test.id!;
  }

  /// 削除する
  Future<void> delete(String id) => _tests.doc(id).delete();

  // ------------------------------------------------------------
  // 毎週のテストのルール（LEAP など）
  // ------------------------------------------------------------

  /// 「LEAP を最初に登録したか」の記録（消したあとに勝手に戻らないように）
  DocumentReference<Map<String, dynamic>> get _rulesInfo => _db
      .collection('users')
      .doc(uid)
      .collection('settings')
      .doc('weekly_rules');

  /// 初めてのときだけ、LEAP のルールを登録する
  /// （前から登録済みで「最後の番号」が未設定なら、初期値だけ足す）
  Future<void> ensureDefaultRules() async {
    final info = await _rulesInfo.get();
    if (info.data()?['leapSeeded'] == true) return;

    final doc = _rules.doc(leapRule.id);
    final snap = await doc.get();
    if (!snap.exists) {
      await doc.set(ruleToMap(leapRule));
    } else if (!(snap.data() ?? const {}).containsKey('endNumber')) {
      await doc.set({'endNumber': leapRule.endNumber}, SetOptions(merge: true));
    }
    await _rulesInfo.set({'leapSeeded': true}, SetOptions(merge: true));
  }

  /// ルールの一覧（設定画面用）
  Stream<List<WeeklyLessonTestRule>> watchRules() => _rules.snapshots().map(
    (s) => [for (final d in s.docs) ruleFromMap(d.id, d.data())],
  );

  /// ルールを保存する（id が空なら新しく追加。「なし」にした週はそのまま）
  Future<void> saveRule(WeeklyLessonTestRule r) async {
    final data = ruleToMap(r)..remove('skippedWeeks');
    if (r.id.isEmpty) {
      await _rules.add({...data, 'skippedWeeks': <String>[]});
    } else {
      await _rules.doc(r.id).set(data, SetOptions(merge: true));
    }
  }

  /// ルールを削除する
  Future<void> deleteRule(String id) => _rules.doc(id).delete();

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
    'targetScore': t.targetScore,
    'studyTodo': t.studyTodo,
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
      targetScore: m['targetScore'] as num?,
      studyTodo: m['studyTodo'] as bool? ?? false,
    );
  }

  static Map<String, dynamic> ruleToMap(WeeklyLessonTestRule r) => {
    'subject': r.subject,
    'title': r.title,
    'baseWeekDate': dateKey(r.baseWeekDate),
    'baseRangeStart': r.baseRangeStart,
    'rangeStep': r.rangeStep,
    'skippedWeeks': r.skippedWeeks.toList()..sort(),
    'endNumber': r.endNumber,
    'startDate': r.startDate == null ? null : dateKey(r.startDate!),
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
      endNumber: (m['endNumber'] as num?)?.toInt(),
      startDate: m['startDate'] is String
          ? _parseDate(m['startDate'] as String)
          : null,
    );
  }
}
