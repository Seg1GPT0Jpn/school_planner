/// メモ・ノート一覧
library;

import 'package:firebase_auth/firebase_auth.dart';
import 'package:material_ui/material_ui.dart';

import 'note.dart';
import 'note_edit_page.dart';
import 'note_repository.dart';

void openNotes(BuildContext context) {
  Navigator.of(
    context,
    rootNavigator: true,
  ).push(MaterialPageRoute<void>(builder: (_) => const NotesHubPage()));
}

class NotesHubPage extends StatefulWidget {
  const NotesHubPage({super.key});

  @override
  State<NotesHubPage> createState() => _NotesHubPageState();
}

class _NotesHubPageState extends State<NotesHubPage> {
  late final String _uid = FirebaseAuth.instance.currentUser!.uid;
  late final _repo = NoteRepository(uid: _uid);

  String _query = '';
  String? _folderId; // null=すべて、'__fav__'=お気に入り
  static const _favFilter = '__fav__';

  void _openNote(Note? n) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => NoteEditPage(repository: _repo, note: n),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('メモ')),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _openNote(null),
        child: const Icon(Icons.add),
      ),
      body: StreamBuilder<List<NoteFolder>>(
        stream: _repo.watchFolders(),
        builder: (context, folderSnap) {
          final folders = folderSnap.data ?? const <NoteFolder>[];
          return StreamBuilder<List<Note>>(
            stream: _repo.watchNotes(),
            builder: (context, noteSnap) {
              if (!noteSnap.hasData) {
                return const Center(child: CircularProgressIndicator());
              }
              var notes = noteSnap.data!;
              if (_folderId == _favFilter) {
                notes = [for (final n in notes) if (n.favorite) n];
              } else if (_folderId != null) {
                notes = [for (final n in notes) if (n.folderId == _folderId) n];
              }
              notes = [for (final n in notes) if (noteMatches(n, _query)) n];

              return Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                    child: TextField(
                      decoration: const InputDecoration(
                        prefixIcon: Icon(Icons.search),
                        hintText: 'メモを検索（タイトル・本文・タグ）',
                        isDense: true,
                        border: OutlineInputBorder(),
                      ),
                      onChanged: (v) => setState(() => _query = v),
                    ),
                  ),
                  SizedBox(
                    height: 40,
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      children: [
                        _chip('すべて', _folderId == null, () => setState(() => _folderId = null)),
                        const SizedBox(width: 6),
                        _chip(
                          '★ お気に入り',
                          _folderId == _favFilter,
                          () => setState(() => _folderId = _favFilter),
                        ),
                        for (final f in folders) ...[
                          const SizedBox(width: 6),
                          _chip(f.name, _folderId == f.id, () => setState(() => _folderId = f.id)),
                        ],
                        const SizedBox(width: 6),
                        ActionChip(
                          avatar: const Icon(Icons.create_new_folder_outlined, size: 16),
                          label: const Text('フォルダ'),
                          onPressed: () => _addFolder(context),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 4),
                  Expanded(
                    child: notes.isEmpty
                        ? Center(
                            child: Text('メモはまだありません', style: TextStyle(color: cs.outline)),
                          )
                        : ListView.builder(
                            padding: const EdgeInsets.fromLTRB(8, 4, 8, 80),
                            itemCount: notes.length,
                            itemBuilder: (context, i) {
                              final n = notes[i];
                              return ListTile(
                                title: Text(
                                  n.title.isEmpty ? '無題のメモ' : n.title,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                subtitle: Text(
                                  n.preview,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                trailing: n.favorite
                                    ? Icon(Icons.star, color: cs.primary, size: 20)
                                    : null,
                                onTap: () => _openNote(n),
                              );
                            },
                          ),
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }

  Widget _chip(String label, bool selected, VoidCallback onTap) => ChoiceChip(
    label: Text(label),
    selected: selected,
    onSelected: (_) => onTap(),
  );

  Future<void> _addFolder(BuildContext context) async {
    final controller = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('新しいフォルダ'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(hintText: 'フォルダ名'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('やめる')),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: const Text('作る'),
          ),
        ],
      ),
    );
    if (name != null && name.isNotEmpty) {
      await _repo.addFolder(name);
    }
  }
}
