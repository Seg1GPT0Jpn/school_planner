/// 暗記カード ― 単語帳・カードセットの一覧
library;

import 'package:firebase_auth/firebase_auth.dart';
import 'package:material_ui/material_ui.dart';

import '../review/review_widgets.dart';
import 'deck_detail_page.dart';
import 'flashcard.dart';
import 'flashcard_repository.dart';

void openFlashcardDecks(BuildContext context) {
  Navigator.of(
    context,
    rootNavigator: true,
  ).push(MaterialPageRoute<void>(builder: (_) => const DecksPage()));
}

class DecksPage extends StatefulWidget {
  const DecksPage({super.key});

  @override
  State<DecksPage> createState() => _DecksPageState();
}

class _DecksPageState extends State<DecksPage> {
  late final _uid = FirebaseAuth.instance.currentUser!.uid;
  late final _repository = FlashcardRepository(uid: _uid);

  Future<void> _createDeck() async {
    final controller = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('単語帳を作る'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(hintText: '例：英単語（Lesson3） / 化学式'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('キャンセル'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, controller.text),
            child: const Text('作る'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (name == null || name.trim().isEmpty) return;
    final id = await _repository.saveDeck(FlashcardDeck(name: name));
    if (mounted) {
      Navigator.of(context, rootNavigator: true).push(
        MaterialPageRoute<void>(
          builder: (_) => DeckDetailPage(
            repository: _repository,
            deck: FlashcardDeck(id: id, name: name),
          ),
        ),
      );
    }
  }

  Future<void> _confirmDelete(FlashcardDeck deck) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('削除しますか？'),
        content: Text('「${deck.name}」を、中のカードごと削除します'),
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
    if (ok == true && deck.id != null) await _repository.deleteDeck(deck.id!);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('暗記カード')),
      floatingActionButton: FloatingActionButton(
        onPressed: _createDeck,
        child: const Icon(Icons.add),
      ),
      body: StreamBuilder<List<FlashcardDeck>>(
        stream: _repository.watchDecks(),
        builder: (context, snapshot) {
          final decks = snapshot.data ?? const <FlashcardDeck>[];
          if (decks.isEmpty) {
            return const Center(child: Faint('まだ単語帳がありません。＋から作りましょう'));
          }
          return Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 640),
              child: ListView.builder(
                padding: const EdgeInsets.fromLTRB(8, 8, 8, 80),
                itemCount: decks.length,
                itemBuilder: (context, i) {
                  final d = decks[i];
                  return Card(
                    child: ListTile(
                      leading: const Icon(Icons.style_outlined),
                      title: Text(d.name),
                      trailing: IconButton(
                        icon: const Icon(Icons.delete_outline),
                        onPressed: () => _confirmDelete(d),
                      ),
                      onTap: () => Navigator.of(context, rootNavigator: true)
                          .push(
                            MaterialPageRoute<void>(
                              builder: (_) => DeckDetailPage(
                                repository: _repository,
                                deck: d,
                              ),
                            ),
                          ),
                    ),
                  );
                },
              ),
            ),
          );
        },
      ),
    );
  }
}
