import 'package:flutter_test/flutter_test.dart';
import 'package:school_planner/features/money/money_transaction.dart';

void main() {
  MoneyTransaction tx(DateTime d, bool income, int amount) => MoneyTransaction(
    date: d,
    isIncome: income,
    category: income ? 'お小遣い' : '食費',
    amount: amount,
  );

  test('残高：基準の残高に、基準の日からの収支を足し引きする', () {
    final base = MoneyBalanceBase(
      amount: 3000,
      date: DateTime(2026, 10, 10, 15, 30),
    );
    final items = [
      tx(DateTime(2026, 10, 9), false, 500), // 基準の日より前は数えない
      tx(DateTime(2026, 10, 10, 8), false, 200), // 基準の日の記録は数える
      tx(DateTime(2026, 10, 15), true, 5000),
      tx(DateTime(2026, 10, 18), false, 1200),
    ];
    expect(base.day, DateTime(2026, 10, 10));
    expect(base.balance(items), 3000 - 200 + 5000 - 1200);
    expect(base.balance(const []), 3000);
  });

  test('月の収支：収入 − 支出', () {
    final s = MonthlySummary.from([
      tx(DateTime(2026, 10, 1), true, 5000),
      tx(DateTime(2026, 10, 2), false, 1200),
    ]);
    expect(s.balance, 3800);
  });
}
