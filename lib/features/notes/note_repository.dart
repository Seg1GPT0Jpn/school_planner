/// メモ・ノートの保存（あなた専用の保存場所にだけ保存する）
library;

import 'package:cloud_firestore/cloud_firestore.dart';

import 'note.dart';

class NoteRepository {
  NoteRepository({required this.uid, FirebaseFirestore? firestore})
    : _db = firestore ?? FirebaseFirestore.instance;

  final String uid;
  final FirebaseFirestore _db;

  CollectionReference<Map<String, dynamic>> get _notes =>
      _db.collection('users').doc(uid).collection('notes');

  CollectionReference<Map<String, dynamic>> get _folders =>
      _db.collection('users').doc(uid).collection('note_folders');

  Note _fromDoc(QueryDocumentSnapshot<Map<String, dynamic>> d) {
    final m = d.data();
    return Note(
      id: d.id,
      title: m['title'] as String? ?? '',
      body: m['body'] as String? ?? '',
      folderId: m['folderId'] as String?,
      tags: [for (final t in (m['tags'] as List<dynamic>? ?? const [])) '$t'],
      favorite: m['favorite'] as bool? ?? false,
      updatedAt:
          (m['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Stream<List<Note>> watchNotes() => _notes.snapshots().map(
    (s) => [for (final d in s.docs) _fromDoc(d)]
      ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt)),
  );

  Stream<List<NoteFolder>> watchFolders() => _folders.snapshots().map(
    (s) => [
      for (final d in s.docs)
        NoteFolder(id: d.id, name: d.data()['name'] as String? ?? ''),
    ]..sort((a, b) => a.name.compareTo(b.name)),
  );

  Future<String> addFolder(String name) async {
    final doc = await _folders.add({'name': name});
    return doc.id;
  }

  Future<void> deleteFolder(String id) async {
    await _folders.doc(id).delete();
    // そのフォルダのメモは「フォルダなし」に戻す
    final inFolder = await _notes.where('folderId', isEqualTo: id).get();
    for (final d in inFolder.docs) {
      await d.reference.update({'folderId': null});
    }
  }

  Future<String> add({
    required String title,
    required String body,
    String? folderId,
    List<String> tags = const [],
  }) async {
    final doc = await _notes.add({
      'title': title,
      'body': body,
      'folderId': folderId,
      'tags': tags,
      'favorite': false,
      'updatedAt': FieldValue.serverTimestamp(),
    });
    return doc.id;
  }

  Future<void> update(Note n) async {
    await _notes.doc(n.id).set({
      'title': n.title,
      'body': n.body,
      'folderId': n.folderId,
      'tags': n.tags,
      'favorite': n.favorite,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> delete(String id) => _notes.doc(id).delete();
}
