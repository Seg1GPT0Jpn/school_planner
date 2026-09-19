/// 時間割データの保存・読み込み（Firestore とのやりとりはここだけで行う）
library;

import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';

import 'day_timetable_resolver.dart';
import 'initial_data.dart';
import 'school_periods.dart';
import 'timetable_models.dart';
import 'week_cycle.dart';

/// Firestore から読み込んだ時間割データ一式
class TimetableData {
  const TimetableData({
    required this.isSeeded,
    required this.subjects,
    required this.slots,
    required this.anchors,
    required this.weekOverrides,
    required this.dayOverrides,
    required this.closures,
  });

  /// 初期データを登録済みか
  final bool isSeeded;

  final List<Subject> subjects;
  final List<TimetableSlot> slots;
  final List<WeekAnchor> anchors;
  final Map<String, WeekType> weekOverrides;
  final List<DayOverride> dayOverrides;
  final List<SchoolClosure> closures;

  /// このデータを使って「その日の時間割」を計算する係
  DayTimetableResolver get resolver => DayTimetableResolver(
    weekCalculator: WeekCycleCalculator(
      anchors: anchors,
      weekOverrides: weekOverrides,
    ),
    slots: slots,
    dayOverrides: dayOverrides,
    closures: closures,
  );

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

    final isSeeded = s['settings']!.docs.any((d) => d.id == 'app');

    final subjectMaps = docs('subjects')
      ..sort((a, b) => _toInt(a['order']).compareTo(_toInt(b['order'])));

    return TimetableData(
      isSeeded: isSeeded,
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
    );
  }

  // ------------------------------------------------------------
  // 初期データの登録（最初の1回だけ）
  // ------------------------------------------------------------

  /// 初期データを登録する。すでに登録済みなら何もしない。
  Future<void> seedInitialData() async {
    final meta = _col('settings').doc('app');
    if ((await meta.get()).exists) return;

    // まとめて書き込む（途中で失敗したら全部やり直しになる＝中途半端にならない）
    final batch = _db.batch();

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

    for (final override in initialDayOverrides) {
      batch.set(
        _col('timetable_overrides').doc(dateKey(override.date)),
        _dayOverrideToMap(override),
      );
    }

    batch.set(meta, {
      'initialDataVersion': 1,
      'initialDataSeededAt': FieldValue.serverTimestamp(),
    });

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

  static Map<String, dynamic> _dayOverrideToMap(DayOverride o) => {
    'date': dateKey(o.date),
    'weekType': o.weekType?.name,
    'note': o.note,
    'changes': [
      for (final c in o.changes)
        {
          'type': c.type.name,
          'period': c.period,
          'otherPeriod': c.otherPeriod,
          'subject': c.subject,
          'room': c.room,
          'teacher': c.teacher,
          'memo': c.memo,
          'start': c.start?.toString(),
          'end': c.end?.toString(),
        },
    ],
  };

  static DayOverride _dayOverrideFromMap(Map<String, dynamic> m) {
    final weekTypeName = m['weekType'] as String?;
    final changeMaps = (m['changes'] as List<dynamic>? ?? const [])
        .cast<Map<String, dynamic>>();

    return DayOverride(
      date: _parseDate(m['date'] as String),
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
