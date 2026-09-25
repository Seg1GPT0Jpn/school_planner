/// 単語帳の中身 ― カードの一覧・追加編集・復習開始
library;

import 'package:material_ui/material_ui.dart';

import '../review/review_widgets.dart';
import 'flashcard.dart';
import 'flashcard_repository.dart';
import 'study_session_page.dart';

class DeckDetailPage extends StatefulWidget {
  const DeckDetailPage({
    super.key,
    required this.repository,
    required this.deck,
  });

  final FlashcardRepository repository;
  final FlashcardDeck deck;

  @override
  State<DeckDetailPage> createState() => _DeckDetailPageState();
}

class _DeckDetailPageState extends State<DeckDetailPage> {
  Future<void> _editCard([Flashcard? existing]) async {
    final frontController = TextEditingController(text: existing?.front ?? '');
    final backController = TextEditingController(text: existing?.back ?? '');
    final saved = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(existing == null ? 'カードを追加' : 'カードを編集'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: frontController,
              autofocus: true,
              decoration: const InputDecoration(labelText: '表（問題・単語）'),
              maxLines: 3,
            ),
            const SizedBox(height: 8),
            TextField(
              controller: backController,
              decoration: const InputDecoration(labelText: '裏（答え・意味）'),
              maxLines: 3,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('キャンセル'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('保存'),
          ),
        ],
      ),
    );
    if (saved == true) {
      final card = Flashcard(
        id: existing?.id,
        front: frontController.text,
        back: backController.text,
        box: existing?.box ?? 1,
        nextReview: existing?.nextReview,
      );
      final error = card.validate();
      if (error == null) {
        await widget.repository.saveCard(widget.deck.id!, card);
      }
    }
    frontController.dispose();
    backController.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.deck.name)),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _editCard(),
        child: const Icon(Icons.add),
      ),
      body: StreamBuilder<List<Flashcard>>(
        stream: widget.repository.watchCards(widget.deck.id!),
        builder: (context, snapshot) {
          final cards = snapshot.data ?? const <Flashcard>[];
          final today = DateTime.now();
          final due = cards.where((c) => c.isDueOn(today)).toList();
          return Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 640),
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.all(12),
                    child: FilledButton.icon(
                      icon: const Icon(Icons.play_arrow),
                      label: Text(
                        due.isEmpty
                            ? '今日復習するカードはありません'
                            : '復習をはじめる（${due.length}枚）',
                      ),
                      onPressed: due.isEmpty
                          ? null
                          : () => Navigator.of(context, rootNavigator: true)
                              .push(
                                MaterialPageRoute<void>(
                                  fullscreenDialog: true,
                                  builder: (_) => StudySessionPage(
                                    repository: widget.repository,
                                    deckId: widget.deck.id!,
                                    cards: due,
                                  ),
                                ),
                              ),
                    ),
                  ),
                  Expanded(
                    child: cards.isEmpty
                        ? const Center(child: Faint('まだカードがありません。＋から追加しましょう'))
                        : ListView.builder(
                            padding: const EdgeInsets.fromLTRB(8, 0, 8, 24),
                            itemCount: cards.length,
                            itemBuilder: (context, i) {
                              final c = cards[i];
                              return ListTile(
                                title: Text(c.front),
                                subtitle: Text(c.back),
                                trailing: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Chip(
                                      visualDensity: VisualDensity.compact,
                                      label: Text('箱${c.box}'),
                                    ),
                                    IconButton(
                                      icon: const Icon(
                                        Icons.delete_outline,
                                        size: 18,
                                      ),
                                      onPressed: () => widget.repository
                                          .deleteCard(widget.deck.id!, c.id!),
                                    ),
                                  ],
                                ),
                                onTap: () => _editCard(c),
                              );
                            },
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
