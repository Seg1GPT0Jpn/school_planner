/// 成長ログの記録を書く画面
library;

import 'package:material_ui/material_ui.dart';

import '../settings/settings_scope.dart';
import 'growth_log.dart';
import 'growth_log_repository.dart';

/// 予定から「記録する」を開く
Future<void> openGrowthLogEntry(
  BuildContext context, {
  required GrowthLogRepository repository,
  required String categoryId,
  String? eventId,
  String? title,
  DateTime? date,
  int? minutes,
  GrowthLogEntry? existing,
}) {
  return Navigator.of(context, rootNavigator: true).push(
    MaterialPageRoute<void>(
      fullscreenDialog: true,
      builder: (_) => GrowthLogEntryPage(
        repository: repository,
        categoryId: categoryId,
        eventId: eventId,
        initialTitle: title,
        initialDate: date,
        initialMinutes: minutes,
        existing: existing,
      ),
    ),
  );
}

class GrowthLogEntryPage extends StatefulWidget {
  const GrowthLogEntryPage({
    super.key,
    required this.repository,
    required this.categoryId,
    this.eventId,
    this.initialTitle,
    this.initialDate,
    this.initialMinutes,
    this.existing,
  });

  final GrowthLogRepository repository;
  final String categoryId;
  final String? eventId;
  final String? initialTitle;
  final DateTime? initialDate;
  final int? initialMinutes;

  /// 編集するとき（新規なら null）
  final GrowthLogEntry? existing;

  @override
  State<GrowthLogEntryPage> createState() => _GrowthLogEntryPageState();
}

class _GrowthLogEntryPageState extends State<GrowthLogEntryPage> {
  late final TextEditingController _title;
  late final TextEditingController _minutes;
  late final TextEditingController _note;
  late final TextEditingController _nextGoal;
  late DateTime _date;
  int? _rating;
  bool _saving = false;
  GrowthLogEntry? _previous;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _title = TextEditingController(
      text: e?.title ?? widget.initialTitle ?? '',
    );
    _date = e?.date ?? widget.initialDate ?? DateTime.now();
    _minutes = TextEditingController(
      text: '${e?.minutes ?? widget.initialMinutes ?? 0}',
    );
    _note = TextEditingController(text: e?.note ?? '');
    _nextGoal = TextEditingController(text: e?.nextGoal ?? '');
    _rating = e?.rating;
    widget.repository
        .latestForCategory(widget.categoryId, excludeId: e?.id)
        .then((v) {
          if (mounted) setState(() => _previous = v);
        });
  }

  @override
  void dispose() {
    _title.dispose();
    _minutes.dispose();
    _note.dispose();
    _nextGoal.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2020),
      lastDate: DateTime(2035, 12, 31),
    );
    if (picked != null) {
      setState(
        () => _date = DateTime(
          picked.year,
          picked.month,
          picked.day,
          _date.hour,
          _date.minute,
        ),
      );
    }
  }

  Future<void> _save() async {
    final title = _title.text.trim();
    if (title.isEmpty) return;
    setState(() => _saving = true);
    try {
      await widget.repository.save(
        GrowthLogEntry(
          id: widget.existing?.id,
          categoryId: widget.categoryId,
          eventId: widget.existing?.eventId ?? widget.eventId,
          title: title,
          date: _date,
          minutes: int.tryParse(_minutes.text.trim()) ?? 0,
          rating: _rating,
          note: _note.text.trim(),
          nextGoal: _nextGoal.text.trim(),
        ),
      );
      if (mounted) Navigator.of(context).pop();
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _delete() async {
    final id = widget.existing?.id;
    if (id == null) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('この記録を削除しますか？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(c).pop(false),
            child: const Text('キャンセル'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(c).pop(true),
            child: const Text('削除'),
          ),
        ],
      ),
    );
    if (ok == true) {
      await widget.repository.delete(id);
      if (mounted) Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = SettingsScope.of(context);
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.existing == null ? '記録する' : '記録を編集'),
        actions: [
          if (widget.existing != null)
            IconButton(
              icon: const Icon(Icons.delete_outline),
              tooltip: '削除',
              onPressed: _saving ? null : _delete,
            ),
          TextButton(
            onPressed: _saving ? null : _save,
            child: const Text('保存'),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              if (_previous != null) ...[
                Card(
                  color: cs.surfaceContainerLow,
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '前回の記録（${s.date(_previous!.date)}）',
                          style: Theme.of(context).textTheme.labelLarge,
                        ),
                        const SizedBox(height: 4),
                        if (_previous!.note.isNotEmpty) Text(_previous!.note),
                        if (_previous!.nextGoal.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Text(
                              '前回の目標：${_previous!.nextGoal}',
                              style: TextStyle(color: cs.primary),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
              ],
              TextField(
                controller: _title,
                decoration: const InputDecoration(labelText: 'タイトル'),
              ),
              const SizedBox(height: 12),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.event_outlined),
                title: const Text('日付'),
                subtitle: Text(s.date(_date, weekday: true)),
                onTap: _pickDate,
              ),
              TextField(
                controller: _minutes,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'かけた時間（分）',
                  suffixText: '分',
                ),
              ),
              const SizedBox(height: 16),
              Text('自己評価', style: Theme.of(context).textTheme.labelLarge),
              Row(
                children: [
                  for (var i = 1; i <= 5; i++)
                    IconButton(
                      icon: Icon(
                        (_rating ?? 0) >= i ? Icons.star : Icons.star_border,
                        color: cs.primary,
                      ),
                      onPressed: () => setState(
                        () => _rating = _rating == i ? null : i,
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _note,
                minLines: 3,
                maxLines: 8,
                decoration: const InputDecoration(
                  labelText: 'メモ・感想',
                  alignLabelWithHint: true,
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _nextGoal,
                decoration: const InputDecoration(labelText: '次の目標・ひとこと'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
