/// お小遣い管理 ― 収支のデータ
library;

/// 支出のカテゴリ（自由に増やせるようにはせず、まずは決め打ちで十分にする）
const List<String> expenseCategories = [
  '食費',
  '交通',
  '娯楽',
  '部費・楽器',
  '交際',
  '文房具・書籍',
  'その他',
];

const List<String> incomeCategories = ['お小遣い', 'アルバイト', 'お年玉', 'その他'];

/// 収支1件
class MoneyTransaction {
  const MoneyTransaction({
    this.id,
    required this.date,
    required this.isIncome,
    required this.category,
    required this.amount,
    this.memo,
  });

  final String? id;
  final DateTime date;

  /// 収入なら true、支出なら false
  final bool isIncome;

  final String category;

  /// 金額（円。常に正の数で持つ。符号は isIncome で判断）
  final int amount;

  final String? memo;

  /// 収支に効く符号つきの金額（支出はマイナス）
  int get signedAmount => isIncome ? amount : -amount;

  String? validate() {
    if (category.trim().isEmpty) return 'カテゴリを選んでください';
    if (amount <= 0) return '金額は1円以上にしてください';
    return null;
  }
}

/// ひと月分の収支をまとめたもの
class MonthlySummary {
  const MonthlySummary({
    required this.income,
    required this.expense,
    required this.byCategory,
  });

  final int income;
  final int expense;
  int get balance => income - expense;

  /// 支出のみ、カテゴリ別の合計（円）
  final Map<String, int> byCategory;

  static MonthlySummary from(List<MoneyTransaction> items) {
    var income = 0;
    var expense = 0;
    final byCategory = <String, int>{};
    for (final t in items) {
      if (t.isIncome) {
        income += t.amount;
      } else {
        expense += t.amount;
        byCategory[t.category] = (byCategory[t.category] ?? 0) + t.amount;
      }
    }
    return MonthlySummary(income: income, expense: expense, byCategory: byCategory);
  }
}
