/// お小遣い管理 ― 保存・読み込み
library;

import 'package:cloud_firestore/cloud_firestore.dart';

import 'money_transaction.dart';

class MoneyRepository {
  MoneyRepository({required this.uid, FirebaseFirestore? firestore})
    : _db = firestore ?? FirebaseFirestore.instance;

  final String uid;
  final FirebaseFirestore _db;

  CollectionReference<Map<String, dynamic>> get _transactions =>
      _db.collection('users').doc(uid).collection('money_transactions');

  DocumentReference<Map<String, dynamic>> get _balance =>
      _db.collection('users').doc(uid).collection('settings').doc('money');

  CollectionReference<Map<String, dynamic>> get _budgets =>
      _db.collection('users').doc(uid).collection('money_budgets');

  /// [month] の月（1日〜末日）の収支
  Stream<List<MoneyTransaction>> watchMonth(DateTime month) {
    final start = DateTime(month.year, month.month, 1);
    final end = DateTime(month.year, month.month + 1, 1);
    return _transactions
        .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(start))
        .where('date', isLessThan: Timestamp.fromDate(end))
        .snapshots()
        .map((s) {
          final list = [
            for (final d in s.docs) _fromMap(d.id, d.data()),
          ];
          list.sort((a, b) => b.date.compareTo(a.date));
          return list;
        });
  }

  Future<String> save(MoneyTransaction t) async {
    final data = _toMap(t);
    if (t.id == null) {
      final ref = await _transactions.add(data);
      return ref.id;
    } else {
      await _transactions.doc(t.id).update(data);
      return t.id!;
    }
  }

  Future<void> delete(String id) => _transactions.doc(id).delete();

  /// 残高の基準（まだ設定していなければ null）
  Stream<MoneyBalanceBase?> watchBalanceBase() => _balance.snapshots().map((s) {
    final m = s.data();
    final amount = m?['balanceAmount'];
    final date = m?['balanceDate'];
    if (amount is! num || date is! Timestamp) return null;
    return MoneyBalanceBase(amount: amount.toInt(), date: date.toDate());
  });

  /// 残高の基準を保存する（あとから何度でも直せる）
  Future<void> setBalanceBase(MoneyBalanceBase base) => _balance.set({
    'balanceAmount': base.amount,
    'balanceDate': Timestamp.fromDate(base.day),
  }, SetOptions(merge: true));

  /// [from] の日からの収支（残高の計算に使う）
  Stream<List<MoneyTransaction>> watchSince(DateTime from) => _transactions
      .where(
        'date',
        isGreaterThanOrEqualTo: Timestamp.fromDate(
          DateTime(from.year, from.month, from.day),
        ),
      )
      .snapshots()
      .map((s) => [for (final d in s.docs) _fromMap(d.id, d.data())]);

  /// カテゴリごとの、月の予算上限（円）。未設定のカテゴリは含まれない
  Stream<Map<String, int>> watchBudgets() {
    return _budgets.snapshots().map((s) {
      final map = <String, int>{};
      for (final d in s.docs) {
        final v = d.data()['limit'];
        if (v is num) map[d.id] = v.toInt();
      }
      return map;
    });
  }

  Future<void> setBudget(String category, int limit) =>
      _budgets.doc(category).set({'limit': limit});

  Future<void> removeBudget(String category) => _budgets.doc(category).delete();

  static Map<String, dynamic> _toMap(MoneyTransaction t) => {
    'date': Timestamp.fromDate(t.date),
    'isIncome': t.isIncome,
    'category': t.category,
    'amount': t.amount,
    'memo': (t.memo == null || t.memo!.trim().isEmpty) ? null : t.memo!.trim(),
  };

  static MoneyTransaction _fromMap(String id, Map<String, dynamic> m) =>
      MoneyTransaction(
        id: id,
        date: (m['date'] as Timestamp).toDate(),
        isIncome: m['isIncome'] as bool? ?? false,
        category: m['category'] as String? ?? 'その他',
        amount: (m['amount'] as num?)?.toInt() ?? 0,
        memo: m['memo'] as String?,
      );
}
