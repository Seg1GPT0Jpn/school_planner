/// お小遣い管理 ― 収支の記録・予算・グラフ
library;

import 'package:firebase_auth/firebase_auth.dart';
import 'package:material_ui/material_ui.dart';

import '../review/review_widgets.dart';
import 'budget_edit_page.dart';
import 'money_repository.dart';
import 'money_transaction.dart';

void openMoney(BuildContext context) {
  Navigator.of(
    context,
    rootNavigator: true,
  ).push(MaterialPageRoute<void>(builder: (_) => const MoneyPage()));
}

class MoneyPage extends StatefulWidget {
  const MoneyPage({super.key});

  @override
  State<MoneyPage> createState() => _MoneyPageState();
}

class _MoneyPageState extends State<MoneyPage> {
  late final _uid = FirebaseAuth.instance.currentUser!.uid;
  late final _repository = MoneyRepository(uid: _uid);
  late DateTime _month = DateTime(DateTime.now().year, DateTime.now().month);

  static String _yen(int v) {
    final s = v.abs().toString();
    final buf = StringBuffer();
    for (var i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) buf.write(',');
      buf.write(s[i]);
    }
    return '${v < 0 ? '-' : ''}${buf.toString()}円';
  }

  Future<void> _addTransaction() async {
    await showDialog<void>(
      context: context,
      builder: (_) => _AddTransactionDialog(
        repository: _repository,
        initialDate: _month.month == DateTime.now().month &&
                _month.year == DateTime.now().year
            ? DateTime.now()
            : _month,
      ),
    );
  }

  Future<void> _confirmDelete(MoneyTransaction t) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('削除しますか？'),
        content: Text('「${t.category}」 ${_yen(t.amount)}'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('キャンセル'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('削除'),
          ),
        ],
      ),
    );
    if (ok == true && t.id != null) await _repository.delete(t.id!);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('お小遣い管理'),
        actions: [
          IconButton(
            icon: const Icon(Icons.pie_chart_outline),
            tooltip: '予算を編集',
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => BudgetEditPage(repository: _repository),
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _addTransaction,
        child: const Icon(Icons.add),
      ),
      body: StreamBuilder<List<MoneyTransaction>>(
        stream: _repository.watchMonth(_month),
        builder: (context, txSnap) {
          final items = txSnap.data ?? const <MoneyTransaction>[];
          final summary = MonthlySummary.from(items);
          return StreamBuilder<Map<String, int>>(
            stream: _repository.watchBudgets(),
            builder: (context, budgetSnap) {
              final budgets = budgetSnap.data ?? const <String, int>{};
              return Align(
                alignment: Alignment.topCenter,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 640),
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.chevron_left),
                            onPressed: () => setState(
                              () => _month =
                                  DateTime(_month.year, _month.month - 1),
                            ),
                          ),
                          Text(
                            '${_month.year}年${_month.month}月',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          IconButton(
                            icon: const Icon(Icons.chevron_right),
                            onPressed: () => setState(
                              () => _month =
                                  DateTime(_month.year, _month.month + 1),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Row(
                            children: [
                              Expanded(
                                child: _SummaryStat(
                                  label: '収入',
                                  value: _yen(summary.income),
                                  color: Colors.green,
                                ),
                              ),
                              Expanded(
                                child: _SummaryStat(
                                  label: '支出',
                                  value: _yen(summary.expense),
                                  color: Colors.red,
                                ),
                              ),
                              Expanded(
                                child: _SummaryStat(
                                  label: '残高',
                                  value: _yen(summary.balance),
                                  color: summary.balance < 0
                                      ? Colors.red
                                      : Colors.blueGrey,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      if (summary.byCategory.isNotEmpty) ...[
                        const SizedBox(height: 16),
                        Text(
                          'カテゴリ別の支出',
                          style: Theme.of(context).textTheme.labelLarge,
                        ),
                        const SizedBox(height: 8),
                        _CategoryBarChart(byCategory: summary.byCategory),
                      ],
                      if (budgets.isNotEmpty) ...[
                        const SizedBox(height: 20),
                        Text(
                          '予算の使用状況',
                          style: Theme.of(context).textTheme.labelLarge,
                        ),
                        const SizedBox(height: 8),
                        for (final entry in budgets.entries)
                          _BudgetBar(
                            category: entry.key,
                            limit: entry.value,
                            spent: summary.byCategory[entry.key] ?? 0,
                          ),
                      ],
                      const SizedBox(height: 20),
                      Text(
                        'この月の記録',
                        style: Theme.of(context).textTheme.labelLarge,
                      ),
                      const SizedBox(height: 4),
                      if (items.isEmpty) const Faint('この月の記録はまだありません'),
                      for (final t in items)
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: Icon(
                            t.isIncome
                                ? Icons.add_circle_outline
                                : Icons.remove_circle_outline,
                            color: t.isIncome ? Colors.green : Colors.red,
                          ),
                          title: Text(t.category),
                          subtitle: Text(
                            '${t.date.month}/${t.date.day}'
                            '${t.memo == null || t.memo!.isEmpty ? '' : ' ・ ${t.memo}'}',
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                (t.isIncome ? '+' : '-') + _yen(t.amount),
                                style: TextStyle(
                                  color: t.isIncome ? Colors.green : Colors.red,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              IconButton(
                                icon: const Icon(Icons.delete_outline, size: 18),
                                onPressed: () => _confirmDelete(t),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

class _SummaryStat extends StatelessWidget {
  const _SummaryStat({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(label, style: const TextStyle(fontSize: 12)),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            color: color,
            fontWeight: FontWeight.bold,
            fontSize: 15,
          ),
        ),
      ],
    );
  }
}

class _CategoryBarChart extends StatelessWidget {
  const _CategoryBarChart({required this.byCategory});

  final Map<String, int> byCategory;

  @override
  Widget build(BuildContext context) {
    final entries = byCategory.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final maxV = entries.first.value;
    return Column(
      children: [
        for (final e in entries)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 3),
            child: Row(
              children: [
                SizedBox(
                  width: 88,
                  child: Text(e.key, style: const TextStyle(fontSize: 12)),
                ),
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: maxV == 0 ? 0 : e.value / maxV,
                      minHeight: 14,
                      backgroundColor: Theme.of(
                        context,
                      ).colorScheme.surfaceContainerHighest,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                SizedBox(
                  width: 60,
                  child: Text(
                    '${e.value}円',
                    textAlign: TextAlign.right,
                    style: const TextStyle(fontSize: 12),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _BudgetBar extends StatelessWidget {
  const _BudgetBar({
    required this.category,
    required this.limit,
    required this.spent,
  });

  final String category;
  final int limit;
  final int spent;

  @override
  Widget build(BuildContext context) {
    final ratio = limit == 0 ? 0.0 : spent / limit;
    final over = spent > limit;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(category, style: const TextStyle(fontSize: 12)),
              const Spacer(),
              Text(
                '$spent / $limit円',
                style: TextStyle(
                  fontSize: 12,
                  color: over ? Colors.red : null,
                  fontWeight: over ? FontWeight.bold : null,
                ),
              ),
            ],
          ),
          const SizedBox(height: 2),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: ratio.clamp(0, 1).toDouble(),
              minHeight: 8,
              backgroundColor: Theme.of(
                context,
              ).colorScheme.surfaceContainerHighest,
              color: over ? Colors.red : null,
            ),
          ),
        ],
      ),
    );
  }
}

class _AddTransactionDialog extends StatefulWidget {
  const _AddTransactionDialog({
    required this.repository,
    required this.initialDate,
  });

  final MoneyRepository repository;
  final DateTime initialDate;

  @override
  State<_AddTransactionDialog> createState() => _AddTransactionDialogState();
}

class _AddTransactionDialogState extends State<_AddTransactionDialog> {
  bool _isIncome = false;
  late String _category = expenseCategories.first;
  final _amountController = TextEditingController();
  final _memoController = TextEditingController();
  late DateTime _date = widget.initialDate;
  String? _error;
  bool _saving = false;

  @override
  void dispose() {
    _amountController.dispose();
    _memoController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(_date.year - 1),
      lastDate: DateTime(_date.year + 1),
    );
    if (picked != null) setState(() => _date = picked);
  }

  Future<void> _save() async {
    final amount = int.tryParse(_amountController.text.trim()) ?? 0;
    final t = MoneyTransaction(
      date: _date,
      isIncome: _isIncome,
      category: _category,
      amount: amount,
      memo: _memoController.text,
    );
    final error = t.validate();
    if (error != null) {
      setState(() => _error = error);
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await widget.repository.save(t);
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = '保存できませんでした：$e';
          _saving = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final categories = _isIncome ? incomeCategories : expenseCategories;
    if (!categories.contains(_category)) _category = categories.first;
    return AlertDialog(
      title: const Text('収支を記録'),
      content: SizedBox(
        width: 360,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SegmentedButton<bool>(
              segments: const [
                ButtonSegment(value: false, label: Text('支出')),
                ButtonSegment(value: true, label: Text('収入')),
              ],
              selected: {_isIncome},
              onSelectionChanged: (s) => setState(() => _isIncome = s.first),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: _category,
              decoration: const InputDecoration(labelText: 'カテゴリ'),
              items: [
                for (final c in categories)
                  DropdownMenuItem(value: c, child: Text(c)),
              ],
              onChanged: (v) => setState(() => _category = v ?? _category),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _amountController,
              autofocus: true,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: '金額', suffixText: '円'),
            ),
            const SizedBox(height: 12),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('日付'),
              trailing: TextButton(
                onPressed: _pickDate,
                child: Text('${_date.month}/${_date.day}'),
              ),
            ),
            TextField(
              controller: _memoController,
              decoration: const InputDecoration(labelText: 'メモ（任意）'),
            ),
            if (_error != null) ...[
              const SizedBox(height: 8),
              Text(_error!, style: const TextStyle(color: Colors.red)),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('キャンセル'),
        ),
        FilledButton(
          onPressed: _saving ? null : _save,
          child: Text(_saving ? '保存中…' : '保存'),
        ),
      ],
    );
  }
}
