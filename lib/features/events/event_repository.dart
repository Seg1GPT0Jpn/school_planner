/// 予定の保存・読み込み（Firestore とのやりとりはここだけで行う）
library;

import 'package:cloud_firestore/cloud_firestore.dart';

import 'calendar_event.dart';

class EventRepository {
  EventRepository({required this.uid, FirebaseFirestore? firestore})
    : _db = firestore ?? FirebaseFirestore.instance;

  final String uid;
  final FirebaseFirestore _db;

  CollectionReference<Map<String, dynamic>> get _events =>
      _db.collection('users').doc(uid).collection('events');

  /// すべての予定を、開始日時の順に見張る（変わるたびに届く）
  Stream<List<CalendarEvent>> watchAll() {
    return _events
        .orderBy('start')
        .snapshots()
        .map(
          (snapshot) => [
            for (final doc in snapshot.docs) _fromMap(doc.id, doc.data()),
          ],
        );
  }

  /// 保存する（新しい予定なら追加、既存の予定なら上書き）
  Future<void> save(CalendarEvent event) async {
    final data = _toMap(event);
    if (event.id == null) {
      await _events.add({
        ...data,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } else {
      await _events.doc(event.id).update({
        ...data,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    }
  }

  /// 削除する
  Future<void> delete(String id) => _events.doc(id).delete();

  static Map<String, dynamic> _toMap(CalendarEvent e) => {
    'title': e.title.trim(),
    'start': Timestamp.fromDate(e.start),
    'end': Timestamp.fromDate(e.end),
    'isAllDay': e.isAllDay,
    'location': (e.location?.trim().isEmpty ?? true)
        ? null
        : e.location!.trim(),
    'memo': (e.memo?.trim().isEmpty ?? true) ? null : e.memo!.trim(),
    'category': e.category.name,
  };

  static CalendarEvent _fromMap(String id, Map<String, dynamic> m) {
    return CalendarEvent(
      id: id,
      title: m['title'] as String? ?? '',
      start: (m['start'] as Timestamp).toDate(),
      end: (m['end'] as Timestamp).toDate(),
      isAllDay: m['isAllDay'] as bool? ?? false,
      location: m['location'] as String?,
      memo: m['memo'] as String?,
      category:
          EventCategory.values.asNameMap()[m['category']] ??
          EventCategory.other,
    );
  }
}
