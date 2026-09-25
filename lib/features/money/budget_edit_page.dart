/// カテゴリ別の月の予算を編集する画面
library;

import 'package:material_ui/material_ui.dart';

import '../review/review_widgets.dart';
import 'money_repository.dart';
import 'money_transaction.dart';

class BudgetEditPage extends StatefulWidget {
  const BudgetEditPage({super.key, required this.repository});

  final MoneyRepository repository;

  @override
  State<BudgetEditPage> createState() => _BudgetEditPageState();
}

class _BudgetEditPageState extends State<BudgetEditPage> {
  final _controllers = <String, TextEditingController>{
    for (final c in expenseCategories) c: TextEditingController(),
  };
  bool _loaded = false;

  @override
  void dispose() {
    for (final c in _controllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save(String category) async {
    final text = _controllers[category]!.text.trim();
    if (text.isEmpty) {
      await widget.repository.removeBudget(category);
      return;
    }
    final v = int.tryParse(text);
    if (v == null || v < 0) return;
    await widget.repository.setBudget(category, v);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('カテゴリ別の予算')),
      body: StreamBuilder<Map<String, int>>(
        stream: widget.repository.watchBudgets(),
        builder: (context, snapshot) {
          final budgets = snapshot.data;
          if (budgets != null && !_loaded) {
            _loaded = true;
            for (final c in expenseCategories) {
              _controllers[c]!.text = budgets[c]?.toString() ?? '';
            }
          }
          return Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  const Faint('1か月あたりの上限を円で入力します。空欄なら予算なし（無制限）扱いです'),
                  const SizedBox(height: 12),
                  for (final c in expenseCategories)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: TextField(
                        controller: _controllers[c],
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(
                          labelText: c,
                          suffixText: '円',
                          border: const OutlineInputBorder(),
                          isDense: true,
                        ),
                        onSubmitted: (_) => _save(c),
                        onTapOutside: (_) => _save(c),
                      ),
                    ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
