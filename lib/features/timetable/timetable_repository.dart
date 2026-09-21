/// 時間割データの保存・読み込み
library;

import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';

import '../../core/japanese_holidays.dart';
import '../school_tests/lesson_test_annotation.dart';
import '../school_tests/school_test.dart';
import '../school_tests/school_test_repository.dart';
import '../school_tests/weekly_lesson_test.dart';
import 'day_timetable_resolver.dart';
import 'initial_data.dart';
import 'school_periods.dart';
import 'timetable_models.dart';
import 'timetable_version.dart';
import 'timetable_version_repository.dart';
import 'week_cycle.dart';

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
    required this.versions,
    this.config = ScheduleConfig.standard,
  });

  final int dataVersion;

  /// 時程の設定（時限の時刻・曜日ごとのコマ数・Ⅰ・Ⅱ週を使うか など）
  final ScheduleConfig config;
  final List<Subject> subjects;

  /// 最初の時間割
  final List<TimetableSlot> slots;

  final List<WeekAnchor> anchors;
  final Map<String, WeekType> weekOverrides;
  final List<DayOverride> dayOverrides;
  final List<SchoolClosure> closures;
  final List<SchoolTest> schoolTests;
  final List<WeeklyLessonTestRule> weeklyRules;

  /// 切り替え日つきの時間割（古い順）
  final List<TimetableVersion> versions;

  bool get isSeeded => dataVersion > 0;

  bool get hasInitialDataUpdate =>
      isSeeded && dataVersion < TimetableRepository.latestDataVersion;

  List<WeeklyLessonTestRule> get activeRules => weeklyRules;

  WeeklyLessonTestRule? ruleForSubject(String? subject) {
    for (final rule in activeRules) {
      if (rule.subject == subject) return rule;
    }
    return null;
  }

  List<SchoolTest> testsOn(DateTime date) => [
    for (final t in schoolTests)
      if (t.isOn(date)) t,
  ];

  /// その日に使う時間割
  List<TimetableSlot> slotsForDate(DateTime date) =>
      slotsOn(date, slots, versions);

  List<TimetableSlot> Function(DateTime)? get _slotsFn =>
      versions.isEmpty ? null : slotsForDate;

  DayTimetableResolver get baseResolver => DayTimetableResolver(
    weekCalculator: WeekCycleCalculator(
      anchors: anchors,
      weekOverrides: weekOverrides,
      enabled: config.useWeekCycle,
    ),
    slots: slots,
    dayOverrides: dayOverrides,
    closures: closures,
    holidays: japaneseHolidays,
    slotsForDate: _slotsFn,
  );

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
      slotsForDate: _slotsFn,
      postProcess: (day) =>
          annotateLessonTests(day, calculators, manualTests: schoolTests),
    );
  }
}

class TimetableRepository {
  TimetableRepository({required this.uid, FirebaseFirestore? firestore})
    : _db = firestore ?? FirebaseFirestore.instance;

  static const int latestDataVersion = 2;

  final String uid;
  final FirebaseFirestore _db;

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
    'timetable_versions',
  ];

  CollectionReference<Map<String, dynamic>> _col(String name) =>
      _db.collection('users').doc(uid).collection(name);

  static String slotId(WeekType weekType, int weekday, int period) =>
      '${weekType.name}-$weekday-$period';

  Stream<TimetableData> watch() {
    final latest = <String, QuerySnapshot<Map<String, dynamic>>>{};
    final subscriptions = <StreamSubscription<dynamic>>[];
    late final StreamController<TimetableData> controller;

    void emitIfReady() {
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

    var dataVersion = 0;
    var config = ScheduleConfig.standard;
    for (final d in s['settings']!.docs) {
      if (d.id == 'app') {
        dataVersion = _toInt(d.data()['initialDataVersion'] ?? 1);
      }
      if (d.id == scheduleDocId) {
        config = ScheduleConfig.fromMap(d.data());
      }
    }
    // アプリ全体の時程を、この人の設定に入れかえる
    SchoolPeriods.config = config;

    final subjectMaps = docs('subjects')
      ..sort((a, b) => _toInt(a['order']).compareTo(_toInt(b['order'])));

    final versions = [
      for (final m in docs('timetable_versions'))
        TimetableVersionRepository.versionFromMap(m),
    ]..sort((a, b) => a.validFrom.compareTo(b.validFrom));

    return TimetableData(
      dataVersion: dataVersion,
      subjects: [
        for (final m in subjectMaps)
          Subject(name: m['name'] as String, category: m['category'] as String),
      ],
      slots: [
        for (final m in docs('timetable_slots'))
          TimetableVersionRepository.slotFromMap(m),
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
      versions: versions,
      config: config,
    );
  }

  // ---------------- 時程の設定 ----------------

  /// 時程の設定を保存する場所（settings/school_schedule）
  static const scheduleDocId = 'school_schedule';

  Future<void> saveScheduleConfig(ScheduleConfig config) =>
      _col('settings').doc(scheduleDocId).set(config.toMap());

  /// 今の学校の時程にもどす
  Future<void> resetScheduleConfig() =>
      _col('settings').doc(scheduleDocId).delete();

  // ---------------- 特定日の時限の変更 ----------------

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
    final hasOther =
        data['schedule'] != null ||
        data['weekType'] != null ||
        data['note'] != null ||
        changes.isNotEmpty;

    if (hasOther) {
      await doc.set({...data, 'changes': changes});
    } else {
      await doc.delete();
    }
  }

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

  // ---------------- 初期データの登録 ----------------

  Future<void> seedInitialData() async {
    final meta = _col('settings').doc('app');
    final metaSnapshot = await meta.get();
    final currentVersion = metaSnapshot.exists
        ? _toInt(metaSnapshot.data()?['initialDataVersion'] ?? 1)
        : 0;
    if (currentVersion >= latestDataVersion) return;

    final batch = _db.batch();

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
          TimetableVersionRepository.slotToMap(slot),
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

    if (currentVersion < 2) {
      for (final override in initialDayOverrides) {
        batch.set(
          _col('timetable_overrides').doc(dateKey(override.date)),
          _dayOverrideToMap(override),
        );
      }
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

  // ---------------- 変換 ----------------

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
