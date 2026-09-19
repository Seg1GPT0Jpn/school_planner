/// 予定の保存・読み込み
library;

import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';

import '../google_calendar/google_sync.dart';
import 'calendar_event.dart';
import 'event_category.dart';

class EventRepository {
  EventRepository({required this.uid, FirebaseFirestore? firestore})
    : _db = firestore ?? FirebaseFirestore.instance;

  final String uid;
  final FirebaseFirestore _db;

  CollectionReference<Map<String, dynamic>> get _events =>
      _db.collection('users').doc(uid).collection('events');

  /// 自分の予定＋Google から読み込んだ予定
  Stream<List<CalendarEvent>> watchAll() {
    var own = const <CalendarEvent>[];
    var google = const <CalendarEvent>[];
    var gotOwn = false, gotGoogle = false;
    final subs = <StreamSubscription<dynamic>>[];
    late final StreamController<List<CalendarEvent>> controller;

    void emit() {
      if (gotOwn && gotGoogle) controller.add([...own, ...google]);
    }

    controller = StreamController<List<CalendarEvent>>(
      onListen: () {
        subs.add(
          _events.orderBy('start').snapshots().listen((s) {
            own = [for (final d in s.docs) _fromMap(d.id, d.data())];
            gotOwn = true;
            emit();
          }, onError: controller.addError),
        );
        subs.add(
          GoogleSyncRepository(uid: uid, firestore: _db).watchCached().listen((
            g,
          ) {
            google = g;
            gotGoogle = true;
            emit();
          }, onError: controller.addError),
        );
      },
      onCancel: () async {
        for (final s in subs) {
          await s.cancel();
        }
      },
    );
    return controller.stream;
  }

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

  Future<void> delete(String id) => _events.doc(id).delete();

  static String? _emptyToNull(String? s) =>
      (s == null || s.trim().isEmpty) ? null : s.trim();

  static Map<String, dynamic> _toMap(CalendarEvent e) => {
    'title': e.title.trim(),
    'start': Timestamp.fromDate(e.start),
    'end': Timestamp.fromDate(e.end),
    'isAllDay': e.isAllDay,
    'location': _emptyToNull(e.location),
    'memo': _emptyToNull(e.memo),
    'categoryId': e.categoryId,
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
      categoryId:
          m['categoryId'] as String? ??
          m['category'] as String? ??
          EventCategory.otherId,
    );
  }
}
