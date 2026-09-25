/// 暗記カードの復習セッション ― 1枚ずつめくって「できた／できなかった」で答える
library;

import 'package:material_ui/material_ui.dart';

import '../review/review_widgets.dart';
import 'flashcard.dart';
import 'flashcard_repository.dart';

class StudySessionPage extends StatefulWidget {
  const StudySessionPage({
    super.key,
    required this.repository,
    required this.deckId,
    required this.cards,
  });

  final FlashcardRepository repository;
  final String deckId;
  final List<Flashcard> cards;

  @override
  State<StudySessionPage> createState() => _StudySessionPageState();
}

class _StudySessionPageState extends State<StudySessionPage> {
  int _index = 0;
  bool _showBack = false;
  int _correctCount = 0;

  Future<void> _grade(bool correct) async {
    final card = widget.cards[_index];
    if (correct) _correctCount++;
    await widget.repository.saveCard(
      widget.deckId,
      card.graded(correct),
    );
    if (!mounted) return;
    if (_index + 1 >= widget.cards.length) {
      await showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('復習おつかれさま！'),
          content: Text(
            '${widget.cards.length}枚中、$_correctCount枚できました',
          ),
          actions: [
            FilledButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('OK'),
            ),
          ],
        ),
      );
      if (mounted) Navigator.of(context).pop();
      return;
    }
    setState(() {
      _index++;
      _showBack = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final card = widget.cards[_index];
    return Scaffold(
      appBar: AppBar(
        title: Text('${_index + 1} / ${widget.cards.length}'),
      ),
      body: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                LinearProgressIndicator(
                  value: _index / widget.cards.length,
                ),
                const SizedBox(height: 24),
                Expanded(
                  child: GestureDetector(
                    onTap: () => setState(() => _showBack = !_showBack),
                    child: Card(
                      child: Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                _showBack ? card.back : card.front,
                                style: Theme.of(context).textTheme.headlineSmall,
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 16),
                              Faint(_showBack ? '（タップで表に戻る）' : '（タップして答えを見る）'),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                if (_showBack)
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => _grade(false),
                          child: const Text('できなかった'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: FilledButton(
                          onPressed: () => _grade(true),
                          child: const Text('できた'),
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
