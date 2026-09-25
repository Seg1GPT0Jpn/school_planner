import 'package:material_ui/material_ui.dart';

import '../../widgets/color_palette_picker.dart';
import 'event_category.dart';
import 'event_category_repository.dart';

/// カテゴリの編集画面（追加・名前変更・色・並べ替え・削除）
class CategoryManagePage extends StatefulWidget {
  const CategoryManagePage({super.key, required this.repository});

  final EventCategoryRepository repository;

  @override
  State<CategoryManagePage> createState() => _CategoryManagePageState();
}

class _CategoryManagePageState extends State<CategoryManagePage> {
  late final Stream<List<EventCategory>> _stream;

  @override
  void initState() {
    super.initState();
    _stream = widget.repository.watch();
  }

  /// 追加・編集のダイアログを開く
  Future<void> _edit(EventCategory? existing, int count) async {
    final result = await showDialog<EventCategory>(
      context: context,
      builder: (_) => _CategoryEditDialog(
        initial:
            existing ??
            EventCategory(
              id: widget.repository.newId(),
              name: '',
              colorValue: 0xFF78909C,
              order: count,
            ),
        isNew: existing == null,
      ),
    );
    if (result != null) await widget.repository.save(result);
  }

  /// 確認してから削除する
  Future<void> _confirmDelete(EventCategory category) async {
    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('「${category.name}」を削除しますか？'),
        content: const Text('このカテゴリの予定は「その他」に移ります。'),
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
    if (shouldDelete == true) await widget.repository.delete(category.id);
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<EventCategory>>(
      stream: _stream,
      builder: (context, snapshot) {
        final categories = snapshot.data ?? const <EventCategory>[];

        return Scaffold(
          appBar: AppBar(title: const Text('カテゴリの編集')),
          floatingActionButton: FloatingActionButton.extended(
            onPressed: () => _edit(null, categories.length),
            icon: const Icon(Icons.add),
            label: const Text('追加'),
          ),
          body: !snapshot.hasData
              ? const Center(child: CircularProgressIndicator())
              : Align(
                  alignment: Alignment.topCenter,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 560),
                    child: ReorderableListView.builder(
                      // 並べ替えのつまみは、自分で左側に置く
                      buildDefaultDragHandles: false,
                      padding: const EdgeInsets.only(bottom: 88),
                      itemCount: categories.length,
                      onReorderItem: (oldIndex, newIndex) {
                        final list = [...categories];
                        list.insert(newIndex, list.removeAt(oldIndex));
                        widget.repository.reorder(list);
                      },
                      itemBuilder: (context, index) {
                        final c = categories[index];
                        return ListTile(
                          key: ValueKey(c.id),
                          leading: ReorderableDragStartListener(
                            index: index,
                            child: const Icon(Icons.drag_handle),
                          ),
                          title: Row(
                            children: [
                              CircleAvatar(
                                radius: 10,
                                backgroundColor: Color(c.colorValue),
                              ),
                              const SizedBox(width: 12),
                              Expanded(child: Text(c.name)),
                            ],
                          ),
                          subtitle: Text('負荷：${c.loadLevel.label}'),
                          onTap: () => _edit(c, categories.length),
                          trailing: c.isDeletable
                              ? IconButton(
                                  icon: const Icon(Icons.delete_outline),
                                  tooltip: '削除',
                                  onPressed: () => _confirmDelete(c),
                                )
                              : null,
                        );
                      },
                    ),
                  ),
                ),
        );
      },
    );
  }
}

/// カテゴリの名前と色を入力するダイアログ
class _CategoryEditDialog extends StatefulWidget {
  const _CategoryEditDialog({required this.initial, required this.isNew});

  final EventCategory initial;
  final bool isNew;

  @override
  State<_CategoryEditDialog> createState() => _CategoryEditDialogState();
}

class _CategoryEditDialogState extends State<_CategoryEditDialog> {
  late final TextEditingController _nameController;
  late int _colorValue;
  late bool _growthLogEnabled;
  late CategoryLoadLevel _loadLevel;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.initial.name);
    _colorValue = widget.initial.colorValue;
    _growthLogEnabled = widget.initial.growthLogEnabled;
    _loadLevel = widget.initial.loadLevel;
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _pickColor() async {
    final picked = await showColorPalettePicker(
      context,
      initial: Color(_colorValue),
    );
    if (picked != null) setState(() => _colorValue = picked.toARGB32());
  }

  void _save() {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      setState(() => _errorMessage = '名前を入力してください');
      return;
    }
    Navigator.of(context).pop(
      widget.initial.copyWith(
        name: name,
        colorValue: _colorValue,
        growthLogEnabled: _growthLogEnabled,
        loadLevel: _loadLevel,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final color = Color(_colorValue);

    return AlertDialog(
      title: Text(widget.isNew ? 'カテゴリを追加' : 'カテゴリを編集'),
      content: SingleChildScrollView(
        child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _nameController,
            autofocus: true,
            decoration: InputDecoration(
              labelText: '名前',
              errorText: _errorMessage,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              const Text('色'),
              const Spacer(),
              InkWell(
                onTap: _pickColor,
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '色を選ぶ',
                    style: TextStyle(color: readableTextColor(color)),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Align(
            alignment: Alignment.centerLeft,
            child: Text('負荷（忙しさ）', style: Theme.of(context).textTheme.labelLarge),
          ),
          const SizedBox(height: 4),
          Text(
            'このカテゴリの予定1件あたりの重さです。軽い予定を多く入れても'
            '「詰め込みすぎ」と判定されにくくなります。',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final level in CategoryLoadLevel.values)
                ChoiceChip(
                  label: Text(level.label),
                  selected: _loadLevel == level,
                  onSelected: (_) => setState(() => _loadLevel = level),
                ),
            ],
          ),
          const SizedBox(height: 8),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('成長ログを使う'),
            subtitle: const Text('部活・練習・趣味など。予定を記録として残せます'),
            value: _growthLogEnabled,
            onChanged: (v) => setState(() => _growthLogEnabled = v),
          ),
        ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('キャンセル'),
        ),
        FilledButton(onPressed: _save, child: const Text('保存')),
      ],
    );
  }
}
