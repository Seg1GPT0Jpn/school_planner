/// 切り替え日つきの時間割（例：10/1 からの新しい時間割）
library;

import 'timetable_models.dart';

class TimetableVersion {
  const TimetableVersion({required this.validFrom, required this.slots});

  /// この日から使う
  final DateTime validFrom;

  final List<TimetableSlot> slots;
}

DateTime _day(DateTime d) => DateTime(d.year, d.month, d.day);

/// その日に使う時間割（切り替え日が一番新しい版。なければ最初の時間割）
List<TimetableSlot> slotsOn(
  DateTime date,
  List<TimetableSlot> baseSlots,
  List<TimetableVersion> versions,
) {
  final d = _day(date);
  TimetableVersion? best;
  for (final v in versions) {
    final from = _day(v.validFrom);
    if (from.isAfter(d)) continue;
    if (best == null || from.isAfter(_day(best.validFrom))) best = v;
  }
  return best?.slots ?? baseSlots;
}
