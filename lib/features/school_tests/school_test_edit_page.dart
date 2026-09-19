import 'package:material_ui/material_ui.dart';

import '../../core/date_format.dart';
import '../timetable/timetable_models.dart';
import 'school_test.dart';
import 'school_test_repository.dart';

/// 小テスト・学校イベントの登録・編集画面
class SchoolTestEditPage extends StatefulWidget {
  const SchoolTestEditPage({
    super.key,
    required this.repository,
    required this.subjects,
    this.test,
    this.initialDate,
    this.initialSubject,
    this.initialPeriod,
  });

  final SchoolTestRepository repository;

  /// 選べる科目の一覧
  final List<Subject> subjects;

  /// 編集するもの（新しく登録するときは null）
  final SchoolTest? test;

  /// 新しく登録するときの初期値
  final DateTime? initialDate;
  final String? initialSubject;
  final int? initialPeriod;

  @override
  State<SchoolTestEditPage> createState() => _SchoolTestEditPageState();
}

class _SchoolTestEditPageState extends State<SchoolTestEditPage> {
  late final TextEditingController _titleController;
  late final TextEditingController _scopeController;
  late final TextEditingController _memoController;

  late SchoolTestKind _kind;
  String? _subject;
  late DateTime _date;
  int? _period;

  bool _isSaving = false;
  String? _errorMessage;

  bool get _isEditing => widget.test != null;

  @override
  void initState() {
    super.initState();
    final t = widget.test;
    _titleController = TextEditingController(text: t?.title ?? '');
    _scopeController = TextEditingController(text: t?.scope ?? '');
    _memoController = TextEditingController(text: t?.memo ?? '');
    _kind = t?.kind ?? SchoolTestKind.quiz;
    _subject = t?.subject ?? widget.initialSubject;
    _period = t?.period ?? widget.initialPeriod;
    final d = t?.date ?? widget.initialDate ?? DateTime.now();
    _date = DateTime(d.year, d.month, d.day);
  }

  @override
  void dispose() {
    _titleController.dispose();
    _scopeController.dispose();
    _memoController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2020),
      lastDate: DateTime(2035, 12, 31),
    );
    if (picked != null) setState(() => _date = picked);
  }

  Future<void> _save() async {
    final test = SchoolTest(
      id: widget.test?.id,
      kind: _kind,
      title: _titleController.text.trim(),
      date: _date,
      subject: _subject,
      period: _period,
      scope: _scopeController.text,
      memo: _memoController.text,
    );

    final error = test.validate();
    if (error != null) {
      setState(() => _errorMessage = error);
      return;
    }

    setState(() {
      _isSaving = true;
      _errorMessage = null;
    });
    try {
      await widget.repository.save(test);
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      setState(() => _errorMessage = '保存に失敗しました：$e');
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _delete() async {
    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('削除しますか？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('キャンセル'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('削除'),
          ),
        ],
      ),
    );
    if (shouldDelete != true) return;

    await widget.repository.delete(widget.test!.id!);
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final labelStyle = Theme.of(context).textTheme.labelLarge;

    // 科目の選択肢（一覧にない科目が入っていても表示できるようにする）
    final subjectNames = [for (final s in widget.subjects) s.name];
    if (_subject != null && !subjectNames.contains(_subject)) {
      subjectNames.add(_subject!);
    }

    // 名前の候補（小テストで、候補がある科目のとき）
    final presets = _kind == SchoolTestKind.quiz
        ? (quizPresets[_subject] ?? const [])
        : const <String>[];

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.close),
          tooltip: '閉じる',
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(_isEditing ? '小テスト・学校イベントを編集' : '小テスト・学校イベントを追加'),
        actions: [
          if (_isEditing)
            IconButton(
              icon: const Icon(Icons.delete_outline),
              tooltip: '削除',
              onPressed: _isSaving ? null : _delete,
            ),
          TextButton(
            onPressed: _isSaving ? null : _save,
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
              // 種類
              Text('種類', style: labelStyle),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final kind in SchoolTestKind.values)
                    ChoiceChip(
                      label: Text(kind.label),
                      selected: _kind == kind,
                      onSelected: (_) => setState(() => _kind = kind),
                    ),
                ],
              ),
              const SizedBox(height: 16),

              // 科目
              Row(
                children: [
                  SizedBox(width: 56, child: Text('科目', style: labelStyle)),
                  Expanded(
                    child: DropdownButton<String?>(
                      isExpanded: true,
                      value: _subject,
                      hint: const Text('なし'),
                      items: [
                        const DropdownMenuItem<String?>(
                          value: null,
                          child: Text('なし'),
                        ),
                        for (final name in subjectNames)
                          DropdownMenuItem<String?>(
                            value: name,
                            child: Text(name),
                          ),
                      ],
                      onChanged: (value) => setState(() => _subject = value),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),

              // 名前（候補ボタン付き）
              if (presets.isNotEmpty) ...[
                Wrap(
                  spacing: 8,
                  children: [
                    for (final preset in presets)
                      ActionChip(
                        label: Text(preset),
                        onPressed: () =>
                            setState(() => _titleController.text = preset),
                      ),
                  ],
                ),
                const SizedBox(height: 4),
              ],
              TextField(
                controller: _titleController,
                decoration: const InputDecoration(
                  labelText: '名前（例：漢字テスト、文化祭、課題提出）',
                ),
              ),
              const SizedBox(height: 16),

              // 日付
              Row(
                children: [
                  SizedBox(width: 56, child: Text('日付', style: labelStyle)),
                  TextButton(
                    onPressed: _pickDate,
                    child: Text(formatDateJa(_date)),
                  ),
                ],
              ),
              const SizedBox(height: 8),

              // 時限
              Text('時限', style: labelStyle),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: [
                  ChoiceChip(
                    label: const Text('なし'),
                    selected: _period == null,
                    onSelected: (_) => setState(() => _period = null),
                  ),
                  for (var p = 1; p <= 5; p++)
                    ChoiceChip(
                      label: Text('$p限'),
                      selected: _period == p,
                      onSelected: (_) => setState(() => _period = p),
                    ),
                ],
              ),
              const SizedBox(height: 16),

              // 範囲・メモ
              TextField(
                controller: _scopeController,
                decoration: const InputDecoration(labelText: '範囲（例：p.20〜35）'),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _memoController,
                minLines: 2,
                maxLines: 6,
                decoration: const InputDecoration(labelText: 'メモ'),
              ),

              if (_errorMessage != null) ...[
                const SizedBox(height: 16),
                Text(
                  _errorMessage!,
                  style: TextStyle(color: colorScheme.error),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
