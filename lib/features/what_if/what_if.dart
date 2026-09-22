/// もしも予定シミュレーター ― 1つの予定の時間が変わったら、その日の後の予定が
/// どれだけずれるかをプレビューするだけの、純粋な計算（保存はしない）
library;

import '../events/calendar_event.dart';

class ShiftedEvent {
  const ShiftedEvent({
    required this.event,
    required this.newStart,
    required this.newEnd,
  });

  final CalendarEvent event;
  final DateTime newStart;
  final DateTime newEnd;
}

/// [dayEvents] のうち [changedEventId] の予定の終了時刻を [newEnd] に変えたら、
/// もとの終了時刻より後に始まっていた予定が、同じ分だけずれる様子を返す。
/// 先頭に「変えた予定自身」、続けて影響を受けた予定（開始時刻の順）を返す。
/// [changedEventId] が見つからない・変化なしのときは空リスト。
List<ShiftedEvent> simulateDelay({
  required List<CalendarEvent> dayEvents,
  required String changedEventId,
  required DateTime newEnd,
}) {
  final sorted = [...dayEvents]..sort((a, b) => a.start.compareTo(b.start));

  CalendarEvent? original;
  for (final e in sorted) {
    if (e.id == changedEventId) {
      original = e;
      break;
    }
  }
  if (original == null) return const [];

  final delta = newEnd.difference(original.end);
  if (delta == Duration.zero) return const [];

  final result = <ShiftedEvent>[
    ShiftedEvent(event: original, newStart: original.start, newEnd: newEnd),
  ];
  for (final e in sorted) {
    if (e.id == changedEventId) continue;
    // もとの変更前の終了時刻以降に始まっていた予定だけ、同じだけずらす
    if (!e.start.isBefore(original.end)) {
      result.add(
        ShiftedEvent(
          event: e,
          newStart: e.start.add(delta),
          newEnd: e.end.add(delta),
        ),
      );
    }
  }
  return result;
}
