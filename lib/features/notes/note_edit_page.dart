/// メモの編集・閲覧（入力してしばらくすると自動で保存される）
library;

import 'dart:async';

import 'package:material_ui/material_ui.dart';

import 'mini_markdown.dart';
import 'note.dart';
import 'note_repository.dart';

class NoteEditPage extends StatefulWidget {
  const NoteEditPage({super.key, required this.repository, this.note});

  final NoteRepository repository;
  final Note? note;

  @override
  State<NoteEditPage> createState() => _NoteEditPageState();
}

class _NoteEditPageState extends State<NoteEditPage> {
  late final TextEditingController _titleCtrl;
  late final TextEditingController _bodyCtrl;
  String? _id;
  String? _folderId;
  List<String> _tags = const [];
  bool _favorite = false;
  bool _preview = false;
  bool _dirty = false;
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _titleCtrl = TextEditingController(text: widget.note?.title ?? '');
    _bodyCtrl = TextEditingController(text: widget.note?.body ?? '');
    _id = widget.note?.id;
    _folderId = widget.note?.folderId;
    _tags = List.of(widget.note?.tags ?? const []);
    _favorite = widget.note?.favorite ?? false;
  }

  void _scheduleSave() {
    _dirty = true;
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 700), _save);
  }

  Future<void> _save() async {
    if (!_dirty) return;
    _dirty = false;
    final bodyEmpty = _bodyCtrl.text.trim().isEmpty;
    final titleEmpty = _titleCtrl.text.trim().isEmpty;
    if (_id == null && bodyEmpty && titleEmpty) return; // 空メモは作らない

    final title = titleEmpty ? titleFromBody(_bodyCtrl.text) : _titleCtrl.text.trim();
    if (_id == null) {
      _id = await widget.repository.add(
        title: title,
        body: _bodyCtrl.text,
        folderId: _folderId,
        tags: _tags,
      );
    } else {
      await widget.repository.update(
        Note(
          id: _id!,
          title: title,
          body: _bodyCtrl.text,
          folderId: _folderId,
          tags: _tags,
          favorite: _favorite,
          updatedAt: DateTime.now(),
        ),
      );
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    if (_dirty) unawaited(_save());
    _titleCtrl.dispose();
    _bodyCtrl.dispose();
    super.dispose();
  }

  void _insertWrap(String before, String after) {
    final text = _bodyCtrl.text;
    final sel = _bodyCtrl.selection;
    final start = sel.start < 0 ? text.length : sel.start;
    final end = sel.end < 0 ? text.length : sel.end;
    final selected = text.substring(start, end);
    final newText = text.replaceRange(start, end, '$before$selected$after');
    _bodyCtrl.value = TextEditingValue(
      text: newText,
      selection: TextSelection.collapsed(offset: start + before.length + selected.length),
    );
    _scheduleSave();
  }

  void _insertLinePrefix(String prefix) {
    final text = _bodyCtrl.text;
    final sel = _bodyCtrl.selection;
    final pos = (sel.start < 0 ? text.length : sel.start).clamp(0, text.length);
    final lineStart = text.lastIndexOf('\n', pos - 1) + 1;
    final newText = text.substring(0, lineStart) + prefix + text.substring(lineStart);
    _bodyCtrl.value = TextEditingValue(
      text: newText,
      selection: TextSelection.collapsed(offset: pos + prefix.length),
    );
    _scheduleSave();
  }

  void _toggleCheck(int lineIndex, bool checked) {
    setState(() {
      _bodyCtrl.text = toggleChecklistLine(_bodyCtrl.text, lineIndex, checked);
    });
    _scheduleSave();
  }

  Future<void> _delete() async {
    if (_id == null) {
      if (mounted) Navigator.pop(context);
      return;
    }
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('このメモを削除しますか？'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('やめる')),
          FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('削除')),
        ],
      ),
    );
    if (ok == true) {
      _dirty = false;
      await widget.repository.delete(_id!);
      if (mounted) Navigator.pop(context);
    }
  }

  Future<void> _pickFolder() async {
    final folders = await widget.repository.watchFolders().first;
    if (!mounted) return;
    final picked = await showDialog<String>(
      context: context,
      builder: (context) => SimpleDialog(
        title: const Text('フォルダを選ぶ'),
        children: [
          SimpleDialogOption(
            onPressed: () => Navigator.pop(context, '__none__'),
            child: const Text('（フォルダなし）'),
          ),
          for (final f in folders)
            SimpleDialogOption(
              onPressed: () => Navigator.pop(context, f.id),
              child: Text(f.name),
            ),
        ],
      ),
    );
    if (picked == null) return;
    setState(() => _folderId = picked == '__none__' ? null : picked);
    _scheduleSave();
  }

  Future<void> _addTag() async {
    final controller = TextEditingController();
    final tag = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('タグを追加'),
        content: TextField(controller: controller, autofocus: true),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('やめる')),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: const Text('追加'),
          ),
        ],
      ),
    );
    if (tag != null && tag.isNotEmpty && !_tags.contains(tag)) {
      setState(() => _tags = [..._tags, tag]);
      _scheduleSave();
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        actions: [
          IconButton(
            icon: Icon(_favorite ? Icons.star : Icons.star_border),
            color: _favorite ? cs.primary : null,
            tooltip: 'お気に入り',
            onPressed: () {
              setState(() => _favorite = !_favorite);
              _scheduleSave();
            },
          ),
          IconButton(
            icon: Icon(_preview ? Icons.edit_outlined : Icons.visibility_outlined),
            tooltip: _preview ? '編集する' : 'プレビュー',
            onPressed: () => setState(() => _preview = !_preview),
          ),
          PopupMenuButton<String>(
            onSelected: (v) {
              if (v == 'folder') _pickFolder();
              if (v == 'delete') _delete();
            },
            itemBuilder: (context) => const [
              PopupMenuItem(value: 'folder', child: Text('フォルダを選ぶ')),
              PopupMenuItem(value: 'delete', child: Text('削除')),
            ],
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _titleCtrl,
              decoration: const InputDecoration(hintText: 'タイトル', border: InputBorder.none),
              style: Theme.of(context).textTheme.titleLarge,
              onChanged: (_) => _scheduleSave(),
            ),
            Wrap(
              spacing: 6,
              runSpacing: 4,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                for (final t in _tags)
                  Chip(
                    label: Text(t, style: const TextStyle(fontSize: 12)),
                    visualDensity: VisualDensity.compact,
                    onDeleted: () {
                      setState(() => _tags = [for (final x in _tags) if (x != t) x]);
                      _scheduleSave();
                    },
                  ),
                ActionChip(
                  avatar: const Icon(Icons.add, size: 14),
                  label: const Text('タグ', style: TextStyle(fontSize: 12)),
                  visualDensity: VisualDensity.compact,
                  onPressed: _addTag,
                ),
              ],
            ),
            const Divider(height: 16),
            if (!_preview)
              Wrap(
                children: [
                  IconButton(
                    icon: const Icon(Icons.format_bold),
                    tooltip: '太字',
                    onPressed: () => _insertWrap('**', '**'),
                  ),
                  IconButton(
                    icon: const Icon(Icons.title),
                    tooltip: '見出し',
                    onPressed: () => _insertLinePrefix('## '),
                  ),
                  IconButton(
                    icon: const Icon(Icons.format_list_bulleted),
                    tooltip: '箇条書き',
                    onPressed: () => _insertLinePrefix('- '),
                  ),
                  IconButton(
                    icon: const Icon(Icons.checklist),
                    tooltip: 'チェックリスト',
                    onPressed: () => _insertLinePrefix('- [ ] '),
                  ),
                ],
              ),
            Expanded(
              child: _preview
                  ? SingleChildScrollView(
                      child: MiniMarkdownView(text: _bodyCtrl.text, onToggleCheck: _toggleCheck),
                    )
                  : TextField(
                      controller: _bodyCtrl,
                      maxLines: null,
                      expands: true,
                      textAlignVertical: TextAlignVertical.top,
                      decoration: const InputDecoration(
                        hintText: '本文（Markdownが使えます。「- [ ] 」でチェックリスト）',
                        border: InputBorder.none,
                      ),
                      onChanged: (_) => _scheduleSave(),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
