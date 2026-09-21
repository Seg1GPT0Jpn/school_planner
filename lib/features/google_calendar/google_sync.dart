/// Google カレンダーとの同期（読み込み・書き込み）と、Google の予定の編集・削除
library;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/date_format.dart';
import '../../core/maps.dart';
import '../events/calendar_event.dart';
import 'google_calendar_service.dart';
import 'google_event_edit_page.dart';
import 'google_push.dart';

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

  DocumentReference<Map<String, dynamic>> get _settings => _db
      .collection('users')
      .doc(uid)
      .collection('settings')
      .doc('google_calendar');

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
          memo: d.data()['memo'] as String?,
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
  /// Google カレンダーを使う設定がしてあるか（読むカレンダーか書き込み先がある）
  Future<bool> isConfigured() async {
    final s = (await _settings.get()).data();
    final read = s?['readIds'];
    return s?['tsuzuriId'] is String || (read is List && read.isNotEmpty);
  }

  Future<int> syncFromGoogle() async {
    final settings = (await _settings.get()).data();
    final tsuzuriId = settings?['tsuzuriId'] as String?;
    final readIds = [
      for (final x in (settings?['readIds'] as List<dynamic>? ?? const []))
        // 「つづり」カレンダーは自分が書き込んだものなので読まない（二重になるため）
        if (x != tsuzuriId) x as String,
    ];

    final service = GoogleCalendarService.instance;
    final calendars = await service.listCalendars();
    final colors = {for (final c in calendars) c.id: c.color};
    final writable = {for (final c in calendars) c.id: c.canWrite};
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
          'memo': e['description'],
          'color': colors[calId],
          'canWrite': writable[calId] ?? false,
        };
      }
    }

    // 前回の分を消して、今回の分を書き込む（450件ずつ）
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

  /// 「つづり」カレンダーに書き込む（まだ作っていなければ null）
  Future<PushResult?> pushIfReady() async {
    final tsuzuriId = (await _settings.get()).data()?['tsuzuriId'] as String?;
    if (tsuzuriId == null) return null;
    return pushToGoogle(uid, tsuzuriId);
  }

  // ---------------- Google の予定の編集・削除（6-4） ----------------

  String _docId(CalendarEvent e) => e.id!.substring(googleIdPrefix.length);

  /// その予定がどのカレンダーのものか・書き換えられるか
  Future<({String calendarId, String eventId, bool canWrite})?> infoOf(
    CalendarEvent e,
  ) async {
    final m = (await _col.doc(_docId(e)).get()).data();
    if (m == null) return null;
    return (
      calendarId: m['calendarId'] as String,
      eventId: m['eventId'] as String,
      canWrite: m['canWrite'] as bool? ?? true,
    );
  }

  /// Google の予定を書き換える
  Future<void> updateGoogleEvent(CalendarEvent old, CalendarEvent next) async {
    final info = await infoOf(old);
    if (info == null) throw Exception('予定が見つかりません。🔄で同期し直してください');
    final body = googleEventBody(
      title: next.title,
      start: next.start,
      end: next.end,
      allDay: next.isAllDay,
      location: next.location,
    )..remove('description');
    body['description'] = next.memo ?? '';
    await GoogleCalendarService.instance.patchEvent(
      info.calendarId,
      info.eventId,
      body,
    );
    await _col.doc(_docId(old)).update({
      'title': next.title,
      'start': Timestamp.fromDate(next.start),
      'end': Timestamp.fromDate(next.end),
      'isAllDay': next.isAllDay,
      'location': next.location,
      'memo': next.memo,
    });
  }

  /// Google の予定を消す
  Future<void> deleteGoogleEvent(CalendarEvent e) async {
    final info = await infoOf(e);
    if (info != null) {
      await GoogleCalendarService.instance.deleteEvent(
        info.calendarId,
        info.eventId,
      );
    }
    await _col.doc(_docId(e)).delete();
  }
}

/// 🔄 ボタン：読み込みと書き込みをして、結果を画面の下に出す
Future<void> syncGoogleWithFeedback(BuildContext context) async {
  final messenger = ScaffoldMessenger.of(context);
  final repo = GoogleSyncRepository(
    uid: FirebaseAuth.instance.currentUser!.uid,
  );
  try {
    // まだつないでいない人には、つなぎ方を案内する（いきなり Google の画面を出さない）
    if (!await repo.isConfigured()) {
      messenger.showSnackBar(
        const SnackBar(
          content: Text('Google カレンダーはまだつないでいません。設定 ＞ Google カレンダー から接続できます'),
        ),
      );
      return;
    }
    messenger.showSnackBar(
      const SnackBar(content: Text('Google カレンダーと同期しています…')),
    );
    final n = await repo.syncFromGoogle();
    final pushed = await repo.pushIfReady();
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          [
            '読み込み $n 件',
            if (pushed != null)
              '書き込み：追加 ${pushed.added}・変更 ${pushed.updated}・削除 ${pushed.deleted}',
          ].join('　'),
        ),
      ),
    );
  } catch (e) {
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(SnackBar(content: Text('同期できませんでした：$e')));
  }
}

/// Google の予定をタップしたとき
void showGoogleEventSheet(BuildContext context, CalendarEvent e) {
  String hm(DateTime d) => '${d.hour}:${d.minute.toString().padLeft(2, '0')}';
  final repo = GoogleSyncRepository(
    uid: FirebaseAuth.instance.currentUser!.uid,
  );

  showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    builder: (c) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
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
            if (e.location != null && e.location!.isNotEmpty)
              PlaceLink(e.location!),
            if (e.memo != null && e.memo!.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(e.memo!, style: Theme.of(c).textTheme.bodySmall),
            ],
            const SizedBox(height: 8),
            Text(
              'Google カレンダーの予定です',
              style: TextStyle(
                color: Theme.of(c).colorScheme.outline,
                fontSize: 12,
              ),
            ),
            const Divider(),
            FutureBuilder(
              future: repo.infoOf(e),
              builder: (c2, snap) {
                if (snap.connectionState != ConnectionState.done) {
                  return const SizedBox(height: 40);
                }
                if (snap.data?.canWrite == false) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Text(
                      '読み取り専用のカレンダー（祝日・誕生日など）なので、編集・削除はできません',
                      style: TextStyle(
                        color: Theme.of(c).colorScheme.outline,
                        fontSize: 12,
                      ),
                    ),
                  );
                }
                return _GoogleEventActions(
                  sheetContext: c,
                  pageContext: context,
                  event: e,
                  repo: repo,
                );
              },
            ),
          ],
        ),
      ),
    ),
  );
}

/// 「編集」「削除」ボタン
class _GoogleEventActions extends StatelessWidget {
  const _GoogleEventActions({
    required this.sheetContext,
    required this.pageContext,
    required this.event,
    required this.repo,
  });

  final BuildContext sheetContext;
  final BuildContext pageContext;
  final CalendarEvent event;
  final GoogleSyncRepository repo;

  Future<void> _delete() async {
    final c = sheetContext;
    final ok = await showDialog<bool>(
      context: c,
      builder: (d) => AlertDialog(
        title: const Text('Google カレンダーからも削除しますか？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(d, false),
            child: const Text('キャンセル'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(d, true),
            child: const Text('削除'),
          ),
        ],
      ),
    );
    if (ok != true || !c.mounted) return;
    final nav = Navigator.of(c);
    final messenger = ScaffoldMessenger.of(pageContext);
    try {
      await repo.deleteGoogleEvent(event);
      nav.pop();
    } catch (err) {
      messenger.showSnackBar(SnackBar(content: Text('削除できませんでした：$err')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        TextButton.icon(
          icon: const Icon(Icons.edit_outlined),
          label: const Text('編集'),
          onPressed: () {
            Navigator.of(sheetContext).pop();
            Navigator.of(pageContext, rootNavigator: true).push(
              MaterialPageRoute<void>(
                fullscreenDialog: true,
                builder: (_) => GoogleEventEditPage(event: event),
              ),
            );
          },
        ),
        TextButton.icon(
          icon: const Icon(Icons.delete_outline),
          label: const Text('削除'),
          onPressed: _delete,
        ),
      ],
    );
  }
}
