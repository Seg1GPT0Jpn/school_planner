/// アラームの保存・読み込み（users/{uid}/alarms）
library;

import 'package:cloud_firestore/cloud_firestore.dart';

import '../timetable/school_periods.dart' show ClockTime;
import '../timetable/week_cycle.dart';
import 'clock_models.dart';

class AlarmRepository {
  AlarmRepository({required this.uid, FirebaseFirestore? firestore})
    : _db = firestore ?? FirebaseFirestore.instance;

  final String uid;
  final FirebaseFirestore _db;

  CollectionReference<Map<String, dynamic>> get _col =>
      _db.collection('users').doc(uid).collection('alarms');

  Stream<List<Alarm>> watch() =>
      _col.snapshots().map((s) => [for (final d in s.docs) fromMap(d.id, d.data())]);

  Future<String> save(Alarm a) async {
    final data = toMap(a);
    if (a.id == null) {
      final doc = await _col.add(data);
      return doc.id;
    }
    await _col.doc(a.id).set(data);
    return a.id!;
  }

  Future<void> delete(String id) => _col.doc(id).delete();

  Future<void> setEnabled(String id, bool enabled) =>
      _col.doc(id).update({'enabled': enabled});

  static DateTime? _date(Object? v) {
    if (v is! String) return null;
    final p = v.split('-').map(int.parse).toList();
    return DateTime(p[0], p[1], p[2]);
  }

  static Map<String, dynamic> toMap(Alarm a) => {
    'time': '${a.time.hour}:${a.time.minute}',
    'label': a.label.trim(),
    'enabled': a.enabled,
    'kind': a.kind.name,
    'weekdays': a.weekdays.toList()..sort(),
    'specificDate': a.specificDate == null ? null : dateKey(a.specificDate!),
    'soundPath': a.soundPath,
    'soundName': a.soundName,
    'volume': a.volume,
    'gradualVolume': a.gradualVolume,
    'snoozeMinutes': a.snoozeMinutes,
    'dismissAfterMinutes': a.dismissAfterMinutes,
    'volumeButtonAction': a.volumeButtonAction.name,
    'vibrate': a.vibrate,
    'includeWeather': a.includeWeather,
    'bedtimeLinked': a.bedtimeLinked,
  };

  static Alarm fromMap(String id, Map<String, dynamic> m) => Alarm(
    id: id,
    time: ClockTime.tryParse(m['time']) ?? const ClockTime(7, 0),
    label: m['label'] as String? ?? '',
    enabled: m['enabled'] as bool? ?? true,
    kind: AlarmKind.values.asNameMap()[m['kind']] ?? AlarmKind.normal,
    weekdays: {
      for (final w in (m['weekdays'] as List<dynamic>? ?? const [])) (w as num).toInt(),
    },
    specificDate: _date(m['specificDate']),
    soundPath: m['soundPath'] as String?,
    soundName: m['soundName'] as String?,
    volume: (m['volume'] as num?)?.toDouble() ?? 0.85,
    gradualVolume: m['gradualVolume'] as bool? ?? true,
    snoozeMinutes: (m['snoozeMinutes'] as num?)?.toInt() ?? 5,
    dismissAfterMinutes: (m['dismissAfterMinutes'] as num?)?.toInt() ?? 15,
    volumeButtonAction:
        AlarmVolumeButtonAction.values.asNameMap()[m['volumeButtonAction']] ??
        AlarmVolumeButtonAction.snooze,
    vibrate: m['vibrate'] as bool? ?? true,
    includeWeather: m['includeWeather'] as bool? ?? false,
    bedtimeLinked: m['bedtimeLinked'] as bool? ?? false,
  );
}
