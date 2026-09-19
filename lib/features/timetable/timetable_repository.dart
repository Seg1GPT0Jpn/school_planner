/// 時間割データの保存・読み込み（Firestore とのやりとりはここだけで行う）
library;

import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';

import '../../core/japanese_holidays.dart';
import '../school_tests/initial_rules.dart';
import '../school_tests/lesson_test_annotation.dart';
import '../school_tests/school_test.dart';
import '../school_tests/school_test_repository.dart';
import '../school_tests/weekly_lesson_test.dart';
import 'day_timetable_resolver.dart';
import 'initial_data.dart';
import 'school_periods.dart';
import 'timetable_models.dart';
import 'week_cycle.dart';

/// Firestore から読み込んだ時間割データ一式
class TimetableData {
  const TimetableData({
    required this.dataVersion,
    required this.subjects,
    required this.slots,
    required this.anchors,
    required this.weekOverrides,
    required this.dayOverrides,
    required this.closures,
    required this.schoolTests,
    required this.weeklyRules,
  });

  /// 登録済みの初期データの版（0 = 未登録）
  final int dataVersion;

  final List<Subject> subjects;
  final List<TimetableSlot> slots;
  final List<WeekAnchor> anchors;
  final Map<String, WeekType> weekOverrides;
  final List<DayOverride> dayOverrides;
  final List<SchoolClosure> closures;

  /// 手で登録した小テスト・学校イベント
  final List<SchoolTest> schoolTests;

  /// 毎週のテストのルール（LEAP など）
  final List<WeeklyLessonTestRule> weeklyRules;

  /// 初期データを登録済みか
  bool get isSeeded => dataVersion > 0;

  /// 新しい版の初期データがあるか
  bool get hasInitialDataUpdate =>
      isSeeded && dataVersion < TimetableRepository.latestDataVersion;

  /// 使うルール（まだ保存されていなければ、LEAP の初期値）
  List<WeeklyLessonTestRule> get activeRules =>
      weeklyRules.isEmpty ? [leapRule] : weeklyRules;

  /// その科目の授業で行う毎週のテストのルール（なければ null）
  WeeklyLessonTestRule? ruleForSubject(String? subject) {
    for (final rule in activeRules) {
      if (rule.subject == subject) return rule;
    }
    return null;
  }

  /// その日の小テスト・学校イベント（手で登録したもの）
  List<SchoolTest> testsOn(DateTime date) => [
    for (final t in schoolTests)
      if (t.isOn(date)) t,
  ];

  /// 時間割だけを計算する係（小テストの印は付けない）
  DayTimetableResolver get baseResolver => DayTimetableResolver(
    weekCalculator: WeekCycleCalculator(
      anchors: anchors,
      weekOverrides: weekOverrides,
    ),
    slots: slots,
    dayOverrides: dayOverrides,
    closures: closures,
    holidays: japaneseHolidays,
  );

  /// 画面で使う計算係（小テストの印を付ける）
  DayTimetableResolver get resolver {
    final base = baseResolver;
    final calculators = [
      for (final rule in activeRules)
        WeeklyLessonTestCalculator(rule: rule, resolver: base),
    ];
    return DayTimetableResolver(
      weekCalculator: base.weekCalculator,
      slots: slots,
      dayOverrides: dayOverrides,
      closures: closures,
      holidays: japaneseHolidays,
      postProcess: (day) =>
          annotateLessonTests(day, calculators, manualTests: schoolTests),
    );
  }

  /// 通常時間割の1コマを取り出す（なければ null）
  TimetableSlot? slotAt(WeekType weekType, int weekday, int period) {
    for (final slot in slots) {
      if (slot.weekType == weekType &&
          slot.weekday == weekday &&
          slot.period == period) {
        return slot;
      }
    }
    return null;
  }
}

/// 時間割データの保存・読み込みを担当する
class TimetableRepository {
  TimetableRepository({required this.uid, FirebaseFirestore? firestore})
    : _db = firestore ?? FirebaseFirestore.instance;

  /// 初期データの最新の版
  ///   1：科目・基本時間割・基準日・10月の例外
  ///   2：学校休業日・短縮日課・試験日課
  static const int latestDataVersion = 2;

  final String uid;
  final FirebaseFirestore _db;

  /// 見張るコレクションの一覧
  static const List<String> _collections = [
    'settings',
    'subjects',
    'timetable_slots',
    'week_anchors',
    'week_overrides',
    'timetable_overrides',
    'closures',
    'school_tests',
    'weekly_test_rules',
  ];

  CollectionReference<Map<String, dynamic>> _col(String name) =>
      _db.collection('users').doc(uid).collection(name);

  static String slotId(WeekType weekType, int weekday, int period) =>
      '${weekType.name}-$weekday-$period';

  // ------------------------------------------------------------
  // 読み込み（リアルタイム）
  // ------------------------------------------------------------

  /// 時間割データ一式を見張り、どれかが変わるたびに最新の一式を届ける
  Stream<TimetableData> watch() {
    final latest = <String, QuerySnapshot<Map<String, dynamic>>>{};
    final subscriptions = <StreamSubscription<dynamic>>[];
    late final StreamController<TimetableData> controller;

    void emitIfReady() {
      // すべてのコレクションを1回以上読み込めたら届ける
      if (latest.length == _collections.length) {
        controller.add(_build(latest));
      }
    }

    controller = StreamController<TimetableData>(
      onListen: () {
        for (final name in _collections) {
          subscriptions.add(
            _col(name).snapshots().listen((snapshot) {
              latest[name] = snapshot;
              emitIfReady();
            }, onError: controller.addError),
          );
        }
      },
      onCancel: () async {
        for (final s in subscriptions) {
          await s.cancel();
        }
      },
    );

    return controller.stream;
  }

  TimetableData _build(Map<String, QuerySnapshot<Map<String, dynamic>>> s) {
    List<Map<String, dynamic>> docs(String name) =>
        s[name]!.docs.map((d) => d.data()).toList();

    // 登録済みの版（版番号がない古いデータは版1とみなす）
    var dataVersion = 0;
    for (final d in s['settings']!.docs) {
      if (d.id == 'app') {
        dataVersion = _toInt(d.data()['initialDataVersion'] ?? 1);
      }
    }

    final subjectMaps = docs('subjects')
      ..sort((a, b) => _toInt(a['order']).compareTo(_toInt(b['order'])));

    return TimetableData(
      dataVersion: dataVersion,
      subjects: [
        for (final m in subjectMaps)
          Subject(name: m['name'] as String, category: m['category'] as String),
      ],
      slots: [
        for (final m in docs('timetable_slots'))
          TimetableSlot(
            weekType: WeekType.values.byName(m['weekType'] as String),
            weekday: _toInt(m['weekday']),
            period: _toInt(m['period']),
            subject: m['subject'] as String,
            room: m['room'] as String?,
            teacher: m['teacher'] as String?,
            memo: m['memo'] as String?,
          ),
      ],
      anchors: [
        for (final m in docs('week_anchors'))
          WeekAnchor(
            date: _parseDate(m['date'] as String),
            weekType: WeekType.values.byName(m['weekType'] as String),
          ),
      ],
      weekOverrides: {
        for (final d in s['week_overrides']!.docs)
          d.id: WeekType.values.byName(d.data()['weekType'] as String),
      },
      dayOverrides: [
        for (final m in docs('timetable_overrides')) _dayOverrideFromMap(m),
      ],
      closures: [
        for (final m in docs('closures'))
          SchoolClosure(
            start: _parseDate(m['start'] as String),
            end: _parseDate(m['end'] as String),
            title: m['title'] as String,
          ),
      ],
      schoolTests: [
        for (final d in s['school_tests']!.docs)
          SchoolTestRepository.testFromMap(d.id, d.data()),
      ],
      weeklyRules: [
        for (final d in s['weekly_test_rules']!.docs)
          SchoolTestRepository.ruleFromMap(d.id, d.data()),
      ],
    );
  }

  // ------------------------------------------------------------
  // 特定日の時限の変更（科目の変更・休講・試験科目）
  // ------------------------------------------------------------

  /// その日のその時限の変更を保存する（同じ時限の変更があれば置き換える）
  Future<void> setPeriodChange(DateTime date, PeriodChange change) async {
    final doc = _col('timetable_overrides').doc(dateKey(date));
    final snapshot = await doc.get();
    final data = snapshot.data() ?? <String, dynamic>{};

    await doc.set({
      ...data,
      'date': dateKey(date),
      'changes': updatedChanges(
        data['changes'] as List<dynamic>?,
        change.period,
        change,
      ),
    });
  }

  /// その日のその時限の変更を消す（元に戻す）
  ///
  /// ほかに何も設定が残らなければ、その日の例外ごと削除する。
  Future<void> clearPeriodChange(DateTime date, int period) async {
    final doc = _col('timetable_overrides').doc(dateKey(date));
    final snapshot = await doc.get();
    if (!snapshot.exists) return;

    final data = snapshot.data()!;
    final changes = updatedChanges(
      data['changes'] as List<dynamic>?,
      period,
      null,
    );

    final hasOtherSettings =
        data['schedule'] != null ||
        data['weekType'] != null ||
        data['note'] != null ||
        changes.isNotEmpty;

    if (hasOtherSettings) {
      await doc.set({...data, 'changes': changes});
    } else {
      await doc.delete();
    }
  }

  /// 変更の一覧のうち、その時限のものを change に置き換える（null なら消す）
  static List<Map<String, dynamic>> updatedChanges(
    List<dynamic>? existing,
    int period,
    PeriodChange? change,
  ) {
    final result = [
      for (final c in existing ?? const []) Map<String, dynamic>.from(c as Map),
    ]..removeWhere((c) => _toInt(c['period']) == period);

    if (change != null) result.add(_changeToMap(change));
    return result;
  }

  // ------------------------------------------------------------
  // 初期データの登録（版ごとに、まだ登録していない分だけ）
  // ------------------------------------------------------------

  /// 初期データを登録する。登録済みの版より新しい分だけを追加する。
  Future<void> seedInitialData() async {
    final meta = _col('settings').doc('app');
    final metaSnapshot = await meta.get();
    final currentVersion = metaSnapshot.exists
        ? _toInt(metaSnapshot.data()?['initialDataVersion'] ?? 1)
        : 0;

    if (currentVersion >= latestDataVersion) return;

    // まとめて書き込む（途中で失敗したら全部やり直しになる＝中途半端にならない）
    final batch = _db.batch();

    // ---- 版1 ----
    if (currentVersion < 1) {
      for (var i = 0; i < initialSubjects.length; i++) {
        final subject = initialSubjects[i];
        batch.set(_col('subjects').doc(subject.name), {
          'name': subject.name,
          'category': subject.category,
          'order': i,
        });
      }

      for (final slot in initialSlots) {
        batch.set(
          _col('timetable_slots')
              .doc(slotId(slot.weekType, slot.weekday, slot.period)),
          {
            'weekType': slot.weekType.name,
            'weekday': slot.weekday,
            'period': slot.period,
            'subject': slot.subject,
            'room': slot.room,
            'teacher': slot.teacher,
            'memo': slot.memo,
          },
        );
      }

      for (final anchor in initialAnchors) {
        batch.set(_col('week_anchors').doc(dateKey(mondayOf(anchor.date))), {
          'date': dateKey(anchor.date),
          'weekType': anchor.weekType.name,
        });
      }

      for (final entry in initialWeekOverrides.entries) {
        batch.set(_col('week_overrides').doc(entry.key), {
          'weekType': entry.value.name,
        });
      }
    }

    // ---- 版1・版2 共通：特定日の例外（同じ日付は上書きになる） ----
    if (currentVersion < 2) {
      for (final override in initialDayOverrides) {
        batch.set(
          _col('timetable_overrides').doc(dateKey(override.date)),
          _dayOverrideToMap(override),
        );
      }

      // ---- 版2：学校休業日 ----
      for (final entry in initialClosures.entries) {
        batch.set(_col('closures').doc(entry.key), {
          'start': dateKey(entry.value.start),
          'end': dateKey(entry.value.end),
          'title': entry.value.title,
        });
      }
    }

    batch.set(meta, {
      'initialDataVersion': latestDataVersion,
      'initialDataUpdatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    await batch.commit();
  }

  // ------------------------------------------------------------
  // 変換用の小さな関数
  // ------------------------------------------------------------

  static int _toInt(Object? value) => (value as num).toInt();

  static DateTime _parseDate(String key) {
    final parts = key.split('-').map(int.parse).toList();
    return DateTime(parts[0], parts[1], parts[2]);
  }

  static ClockTime? _parseTime(Object? value) {
    if (value is! String) return null;
    final parts = value.split(':').map(int.parse).toList();
    return ClockTime(parts[0], parts[1]);
  }

  static Map<String, dynamic> _changeToMap(PeriodChange c) => {
    'type': c.type.name,
    'period': c.period,
    'otherPeriod': c.otherPeriod,
    'subject': c.subject,
    'room': c.room,
    'teacher': c.teacher,
    'memo': c.memo,
    'start': c.start?.toString(),
    'end': c.end?.toString(),
  };

  static Map<String, dynamic> _dayOverrideToMap(DayOverride o) => {
    'date': dateKey(o.date),
    'schedule': o.schedule?.name,
    'weekType': o.weekType?.name,
    'note': o.note,
    'changes': [for (final c in o.changes) _changeToMap(c)],
  };

  static DayOverride _dayOverrideFromMap(Map<String, dynamic> m) {
    final scheduleName = m['schedule'] as String?;
    final weekTypeName = m['weekType'] as String?;
    final changeMaps = [
      for (final c in (m['changes'] as List<dynamic>? ?? const []))
        Map<String, dynamic>.from(c as Map),
    ];

    return DayOverride(
      date: _parseDate(m['date'] as String),
      schedule: scheduleName == null
          ? null
          : DaySchedule.values.byName(scheduleName),
      weekType: weekTypeName == null
          ? null
          : WeekType.values.byName(weekTypeName),
      note: m['note'] as String?,
      changes: [
        for (final c in changeMaps)
          switch (c['type'] as String) {
            'cancel' => PeriodChange.cancel(
              period: _toInt(c['period']),
              memo: c['memo'] as String?,
            ),
            'swap' => PeriodChange.swap(
              period: _toInt(c['period']),
              otherPeriod: _toInt(c['otherPeriod']),
            ),
            _ => PeriodChange.replace(
              period: _toInt(c['period']),
              subject: c['subject'] as String?,
              room: c['room'] as String?,
              teacher: c['teacher'] as String?,
              memo: c['memo'] as String?,
              start: _parseTime(c['start']),
              end: _parseTime(c['end']),
            ),
          },
      ],
    );
  }
}
