/// Google カレンダーの予定を読み込んで、Firestore に保存する
library;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/date_format.dart';
import '../events/calendar_event.dart';
import 'google_calendar_service.dart';

const String googleIdPrefix = 'google:';

bool isGoogleEvent(CalendarEvent e) =>
    e.id?.startsWith(googleIdPrefix) ?? false;

/// Google の予定の色（Google の予定でなければ null）
Color? googleEventColor(CalendarEvent e) {
  final id = e.categoryId;
  if (!id.startsWith('color:#') || id.length != 13) return null;
  return Color(int.parse('FF${id.substring(7)}', radix: 16));
}

class GoogleSyncRepository {
  GoogleSyncRepository({required this.uid, FirebaseFirestore? firestore})
    : _db = firestore ?? FirebaseFirestore.instance;

  final String uid;
  final FirebaseFirestore _db;

  CollectionReference<Map<String, dynamic>> get _col =>
      _db.collection('users').doc(uid).collection('google_events');

  Stream<List<CalendarEvent>> watchCached() => _col.snapshots().map(
    (s) => [
      for (final d in s.docs)
        CalendarEvent(
          id: '$googleIdPrefix${d.id}',
          title: d.data()['title'] as String? ?? '',
          start: (d.data()['start'] as Timestamp).toDate(),
          end: (d.data()['end'] as Timestamp).toDate(),
          isAllDay: d.data()['isAllDay'] as bool? ?? false,
          location: d.data()['location'] as String?,
          categoryId: 'color:${d.data()['color'] ?? '#78909C'}',
        ),
    ],
  );

  /// Google の日時を読み取る（終日の終わりは Google では「翌日」なので1日戻す）
  static (DateTime, bool)? _time(Object? v, {bool isEnd = false}) {
    if (v is! Map) return null;
    if (v['dateTime'] is String) {
      return (DateTime.parse(v['dateTime'] as String).toLocal(), false);
    }
    if (v['date'] is String) {
      final p = (v['date'] as String).split('-').map(int.parse).toList();
      return (DateTime(p[0], p[1], p[2] - (isEnd ? 1 : 0)), true);
    }
    return null;
  }

  /// 読み込んで保存し直す。読み込んだ件数を返す
  Future<int> syncFromGoogle() async {
    final settings = await _db
        .collection('users')
        .doc(uid)
        .collection('settings')
        .doc('google_calendar')
        .get();
    final readIds = [
      for (final x
          in (settings.data()?['readIds'] as List<dynamic>? ?? const []))
        x as String,
    ];

    final service = GoogleCalendarService.instance;
    final colors = {
      for (final c in await service.listCalendars()) c.id: c.color,
    };
    final now = DateTime.now();
    final from = DateTime(now.year, now.month - 2, 1);
    final to = DateTime(now.year, now.month + 7, 1);

    final docs = <String, Map<String, dynamic>>{};
    for (var i = 0; i < readIds.length; i++) {
      final calId = readIds[i];
      for (final e in await service.listEvents(calId, from, to)) {
        if (e['status'] == 'cancelled') continue;
        final start = _time(e['start']);
        final end = _time(e['end'], isEnd: true);
        if (start == null || end == null) continue;
        docs['${i}_${e['id']}'] = {
          'calendarId': calId,
          'eventId': e['id'],
          'title': e['summary'] ?? '（無題）',
          'start': Timestamp.fromDate(start.$1),
          'end': Timestamp.fromDate(end.$1),
          'isAllDay': start.$2,
          'location': e['location'],
          'color': colors[calId],
        };
      }
    }

    // 前回の分を消して、今回の分を書き込む（500件ずつ）
    final old = await _col.get();
    final ops = <void Function(WriteBatch)>[
      for (final d in old.docs)
        if (!docs.containsKey(d.id)) (b) => b.delete(d.reference),
      for (final entry in docs.entries)
        (b) => b.set(_col.doc(entry.key), entry.value),
    ];
    for (var i = 0; i < ops.length; i += 450) {
      final batch = _db.batch();
      for (final op in ops.skip(i).take(450)) {
        op(batch);
      }
      await batch.commit();
    }
    return docs.length;
  }
}

/// 🔄 ボタン：同期して、結果を画面の下に出す
Future<void> syncGoogleWithFeedback(BuildContext context) async {
  final messenger = ScaffoldMessenger.of(context);
  try {
    final n = await GoogleSyncRepository(
      uid: FirebaseAuth.instance.currentUser!.uid,
    ).syncFromGoogle();
    messenger.showSnackBar(
      SnackBar(content: Text('Google カレンダーから $n 件を読み込みました')),
    );
  } catch (e) {
    messenger.showSnackBar(SnackBar(content: Text('同期できませんでした：$e')));
  }
}

/// Google の予定をタップしたとき
void showGoogleEventSheet(BuildContext context, CalendarEvent e) {
  String hm(DateTime d) => '${d.hour}:${d.minute.toString().padLeft(2, '0')}';
  showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    builder: (c) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(e.title, style: Theme.of(c).textTheme.titleLarge),
            const SizedBox(height: 8),
            Text(
              e.isAllDay
                  ? '${formatDateJa(e.start)}〜${formatDateJa(e.end)}（終日）'
                  : '${formatDateJa(e.start)}  ${hm(e.start)}〜${hm(e.end)}',
            ),
            if (e.location != null) Text(e.location!),
            const SizedBox(height: 12),
            Text(
              'Google カレンダーの予定です',
              style: TextStyle(color: Theme.of(c).colorScheme.outline),
            ),
          ],
        ),
      ),
    ),
  );
}
