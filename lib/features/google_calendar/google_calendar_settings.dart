/// Google カレンダーの設定（どれを読むか・つづりカレンダーの ID）
library;

import 'package:cloud_firestore/cloud_firestore.dart';

class GoogleCalendarSettings {
  const GoogleCalendarSettings({this.readIds = const [], this.tsuzuriId});
  final List<String> readIds;
  final String? tsuzuriId;
}

class GoogleCalendarSettingsRepository {
  GoogleCalendarSettingsRepository({
    required this.uid,
    FirebaseFirestore? firestore,
  }) : _db = firestore ?? FirebaseFirestore.instance;

  final String uid;
  final FirebaseFirestore _db;

  DocumentReference<Map<String, dynamic>> get _doc => _db
      .collection('users')
      .doc(uid)
      .collection('settings')
      .doc('google_calendar');

  Stream<GoogleCalendarSettings> watch() => _doc.snapshots().map((s) {
    final m = s.data() ?? const <String, dynamic>{};
    return GoogleCalendarSettings(
      readIds: [
        for (final x in (m['readIds'] as List<dynamic>? ?? const []))
          x as String,
      ],
      tsuzuriId: m['tsuzuriId'] as String?,
    );
  });

  Future<void> setReadIds(List<String> ids) =>
      _doc.set({'readIds': ids}, SetOptions(merge: true));

  Future<void> setTsuzuriId(String id) =>
      _doc.set({'tsuzuriId': id}, SetOptions(merge: true));
}
