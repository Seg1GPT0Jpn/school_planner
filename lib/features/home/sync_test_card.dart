import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:material_ui/material_ui.dart';

/// Firestore の同期を確認するための一時的な部品
///
/// 保存場所：users/{自分のID}/debug/sync_test
class SyncTestCard extends StatefulWidget {
  const SyncTestCard({super.key});

  @override
  State<SyncTestCard> createState() => _SyncTestCardState();
}

class _SyncTestCardState extends State<SyncTestCard> {
  final TextEditingController _controller = TextEditingController();

  late final DocumentReference<Map<String, dynamic>> _doc;
  late final Stream<DocumentSnapshot<Map<String, dynamic>>> _stream;

  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    final uid = FirebaseAuth.instance.currentUser!.uid;
    _doc = FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('debug')
        .doc('sync_test');

    // データが変わるたびに自動で届く「流れ」（リアルタイム同期の正体）
    _stream = _doc.snapshots();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    try {
      await _doc.set({
        'text': _controller.text,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      _controller.clear();
      setState(() => _errorMessage = null);
    } on FirebaseException catch (e) {
      setState(() => _errorMessage = '保存に失敗しました（${e.code}）');
    }
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('同期テスト', style: textTheme.titleMedium),
            const SizedBox(height: 12),

            // Firestore に保存されている内容（変わると自動で書き換わる）
            StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
              stream: _stream,
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Text('読み込みエラー：${snapshot.error}');
                }
                if (!snapshot.hasData) {
                  return const Text('読み込み中…');
                }
                final text = snapshot.data!.data()?['text'] as String?;
                return Text('保存されている内容：${text ?? '（まだありません）'}');
              },
            ),
            const SizedBox(height: 12),

            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _controller,
                    decoration: const InputDecoration(labelText: 'メモ'),
                    onSubmitted: (_) => _save(),
                  ),
                ),
                const SizedBox(width: 8),
                FilledButton(onPressed: _save, child: const Text('保存')),
              ],
            ),

            if (_errorMessage != null) ...[
              const SizedBox(height: 8),
              Text(
                _errorMessage!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
