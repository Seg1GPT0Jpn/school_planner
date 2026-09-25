/// 時間割の編集と、切り替え日つきの時間割の保存
library;

import 'package:cloud_firestore/cloud_firestore.dart';

import 'timetable_models.dart';
import 'timetable_version.dart';
import 'week_cycle.dart';

class TimetableVersionRepository {
  TimetableVersionRepository({required this.uid, FirebaseFirestore? firestore})
    : _db = firestore ?? FirebaseFirestore.instance;

  final String uid;
  final FirebaseFirestore _db;

  CollectionReference<Map<String, dynamic>> _col(String name) =>
      _db.collection('users').doc(uid).collection(name);

  static String _slotId(WeekType w, int weekday, int period) =>
      '${w.name}-$weekday-$period';

  static Map<String, dynamic> slotToMap(TimetableSlot s) => {
    'weekType': s.weekType.name,
    'weekday': s.weekday,
    'period': s.period,
    'subject': s.subject,
    'room': s.room,
    'teacher': s.teacher,
    'memo': s.memo,
  };

  static TimetableSlot slotFromMap(Map<String, dynamic> m) => TimetableSlot(
    weekType: WeekType.values.byName(m['weekType'] as String),
    weekday: (m['weekday'] as num).toInt(),
    period: (m['period'] as num).toInt(),
    subject: m['subject'] as String,
    room: m['room'] as String?,
    teacher: m['teacher'] as String?,
    memo: m['memo'] as String?,
  );

  static TimetableVersion versionFromMap(Map<String, dynamic> m) {
    final p = (m['validFrom'] as String).split('-').map(int.parse).toList();
    return TimetableVersion(
      validFrom: DateTime(p[0], p[1], p[2]),
      slots: [
        for (final s in (m['slots'] as List<dynamic>? ?? const []))
          slotFromMap(Map<String, dynamic>.from(s as Map)),
      ],
    );
  }

  /// 新しい時間割を作る（copyFrom の中身をコピー）
  Future<void> createVersion(DateTime validFrom, List<TimetableSlot> copyFrom) {
    return _col('timetable_versions').doc(dateKey(validFrom)).set({
      'validFrom': dateKey(validFrom),
      'slots': [for (final s in copyFrom) slotToMap(s)],
    });
  }

  Future<void> deleteVersion(DateTime validFrom) =>
      _col('timetable_versions').doc(dateKey(validFrom)).delete();

  /// 1マスを変更する（subject が null なら空きにする）
  ///   version が null なら「最初の時間割」を変更する
  Future<void> setSlot({
    required TimetableVersion? version,
    required WeekType weekType,
    required int weekday,
    required int period,
    required String? subject,
  }) async {
    final newSlot = subject == null
        ? null
        : TimetableSlot(
            weekType: weekType,
            weekday: weekday,
            period: period,
            subject: subject,
          );

    if (version == null) {
      final doc = _col('timetable_slots')
          .doc(_slotId(weekType, weekday, period));
      if (newSlot == null) {
        await doc.delete();
      } else {
        await doc.set(slotToMap(newSlot));
      }
      return;
    }

    final slots = [
      for (final s in version.slots)
        if (!(s.weekType == weekType &&
            s.weekday == weekday &&
            s.period == period))
          s,
      ?newSlot,
    ];
    await _col('timetable_versions').doc(dateKey(version.validFrom)).update({
      'slots': [for (final s in slots) slotToMap(s)],
    });
  }
}
