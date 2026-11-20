/// 暗記カード ― 保存・読み込み
library;

import 'package:cloud_firestore/cloud_firestore.dart';

import 'flashcard.dart';

class FlashcardRepository {
  FlashcardRepository({required this.uid, FirebaseFirestore? firestore})
    : _db = firestore ?? FirebaseFirestore.instance;

  final String uid;
  final FirebaseFirestore _db;

  CollectionReference<Map<String, dynamic>> get _decks =>
      _db.collection('users').doc(uid).collection('flashcard_decks');

  CollectionReference<Map<String, dynamic>> _cards(String deckId) =>
      _decks.doc(deckId).collection('cards');

  Stream<List<FlashcardDeck>> watchDecks() {
    return _decks.snapshots().map(
      (s) => [
        for (final d in s.docs)
          FlashcardDeck(id: d.id, name: d.data()['name'] as String? ?? ''),
      ],
    );
  }

  Future<String> saveDeck(FlashcardDeck deck) async {
    if (deck.id == null) {
      final ref = await _decks.add({'name': deck.name.trim()});
      return ref.id;
    } else {
      await _decks.doc(deck.id).update({'name': deck.name.trim()});
      return deck.id!;
    }
  }

  Future<void> deleteDeck(String deckId) async {
    final cards = await _cards(deckId).get();
    for (final d in cards.docs) {
      await d.reference.delete();
    }
    await _decks.doc(deckId).delete();
  }

  Stream<List<Flashcard>> watchCards(String deckId) {
    return _cards(deckId).snapshots().map(
      (s) => [for (final d in s.docs) _fromMap(d.id, d.data())],
    );
  }

  Future<void> saveCard(String deckId, Flashcard card) async {
    final data = _toMap(card);
    if (card.id == null) {
      await _cards(deckId).add(data);
    } else {
      await _cards(deckId).doc(card.id).update(data);
    }
  }

  Future<void> deleteCard(String deckId, String cardId) =>
      _cards(deckId).doc(cardId).delete();

  static Map<String, dynamic> _toMap(Flashcard c) => {
    'front': c.front.trim(),
    'back': c.back.trim(),
    'box': c.box,
    'nextReview': c.nextReview == null
        ? null
        : Timestamp.fromDate(c.nextReview!),
  };

  static Flashcard _fromMap(String id, Map<String, dynamic> m) => Flashcard(
    id: id,
    front: m['front'] as String? ?? '',
    back: m['back'] as String? ?? '',
    box: (m['box'] as num?)?.toInt() ?? 1,
    nextReview: (m['nextReview'] as Timestamp?)?.toDate(),
  );
}
