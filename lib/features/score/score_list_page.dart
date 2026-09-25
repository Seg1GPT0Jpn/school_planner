/// 楽譜の一覧（新規作成・既存の曲を開く）
library;

import 'package:firebase_auth/firebase_auth.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/date_format.dart';
import 'model/score.dart';
import 'score_editor_page.dart';
import 'score_repository.dart';

void openScoreList(BuildContext context) {
  Navigator.of(
    context,
    rootNavigator: true,
  ).push(MaterialPageRoute<void>(builder: (_) => const ScoreListPage()));
}

/// 楽譜作成アプリ（作曲・入力）のトップ画面
class ScoreListPage extends StatefulWidget {
  const ScoreListPage({super.key});

  @override
  State<ScoreListPage> createState() => _ScoreListPageState();
}

class _ScoreListPageState extends State<ScoreListPage> {
  late final ScoreRepository _repository;
  late final Stream<List<Score>> _stream;

  @override
  void initState() {
    super.initState();
    final uid = FirebaseAuth.instance.currentUser!.uid;
    _repository = ScoreRepository(uid: uid);
    _stream = _repository.watchAll();
  }

  Future<void> _createNew() async {
    final controller = TextEditingController();
    final title = await showDialog<String>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('新しい曲'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(labelText: '曲名', hintText: '例：暁の空からマーチ'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(c).pop(),
            child: const Text('キャンセル'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(c).pop(
              controller.text.trim().isEmpty ? '無題の曲' : controller.text.trim(),
            ),
            child: const Text('作成'),
          ),
        ],
      ),
    );
    if (title == null || !mounted) return;

    final id = await _repository.save(Score.blank(title: title));
    if (!mounted) return;
    openScoreEditor(context, scoreId: id);
  }

  Future<void> _delete(Score score) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text('「${score.title}」を削除しますか？'),
        content: const Text('この操作は取り消せません。'),
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
      await _repository.delete(score.id);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('楽譜作成')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _createNew,
        icon: const Icon(Icons.add),
        label: const Text('新しい曲'),
      ),
      body: StreamBuilder<List<Score>>(
        stream: _stream,
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final scores = snapshot.data!;
          if (scores.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'まだ曲がありません。\n右下の「新しい曲」から作曲を始められます。',
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }
          return Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 560),
              child: ListView.builder(
                padding: const EdgeInsets.only(bottom: 88),
                itemCount: scores.length,
                itemBuilder: (context, i) {
                  final score = scores[i];
                  final partCount = score.parts.length;
                  final measureCount = score.parts.isEmpty
                      ? 0
                      : score.parts.first.measures.length;
                  return ListTile(
                    leading: const Icon(Icons.music_note),
                    title: Text(score.title),
                    subtitle: Text(
                      [
                        if (score.composer.isNotEmpty) score.composer,
                        '$partCount パート・$measureCount 小節',
                        if (score.updatedAt != null)
                          formatDateJa(score.updatedAt!),
                      ].join('　'),
                    ),
                    trailing: IconButton(
                      icon: const Icon(Icons.delete_outline),
                      tooltip: '削除',
                      onPressed: () => _delete(score),
                    ),
                    onTap: () => openScoreEditor(context, scoreId: score.id),
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
