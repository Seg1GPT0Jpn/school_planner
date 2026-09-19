/// 科目の追加・変更・削除
library;

import 'package:cloud_firestore/cloud_firestore.dart';

import 'timetable_models.dart';

/// 2・3年生で使う科目（教科 → 科目）
const Map<String, List<String>> upperGradeSubjects = {
  '国語': ['論理国語', '文学国語', '古典研究'],
  '地理・歴史': ['地理探究', '歴史総合', '日本史探究', '世界史探究', '地理研究', '日本史研究', '世界史研究'],
  '公民': ['倫理', '政治・経済'],
  '数学': [
    '数学Ⅱ',
    '数学B',
    '数学Ⅲ',
    '数学C',
    '数学研究Ⅰ',
    '数学研究Ⅱ',
    '数学総合Ⅰ',
    '数学総合Ⅱ',
    '数学探究Ⅰ',
    '数学探究Ⅱ',
  ],
  '理科': ['物理基礎', '物理', '化学', '生物'],
  '英語': ['ECⅡ', 'ECⅢ', '論表Ⅱ', '論表Ⅲ'],
};

/// 今ある科目の教科を移すもの
const Map<String, String> subjectRecategorize = {'地理総合': '地理・歴史', '公共': '公民'};

class SubjectRepository {
  SubjectRepository({required this.uid, FirebaseFirestore? firestore})
    : _db = firestore ?? FirebaseFirestore.instance;

  final String uid;
  final FirebaseFirestore _db;

  CollectionReference<Map<String, dynamic>> get _col =>
      _db.collection('users').doc(uid).collection('subjects');

  /// 追加・教科の変更
  Future<void> save(Subject s, int order) => _col.doc(s.name).set({
    'name': s.name,
    'category': s.category,
    'order': order,
  });

  Future<void> delete(String name) => _col.doc(name).delete();

  /// まだない科目だけ追加し、教科の移し替えも行う。追加した数を返す
  Future<int> addUpperGrade(List<Subject> existing) async {
    final names = {for (final s in existing) s.name};
    final batch = _db.batch();
    var order = existing.length;
    var added = 0;

    upperGradeSubjects.forEach((category, list) {
      for (final name in list) {
        if (names.contains(name)) continue;
        batch.set(_col.doc(name), {
          'name': name,
          'category': category,
          'order': order++,
        });
        added++;
      }
    });

    subjectRecategorize.forEach((name, category) {
      if (names.contains(name)) {
        batch.update(_col.doc(name), {'category': category});
      }
    });

    await batch.commit();
    return added;
  }
}
