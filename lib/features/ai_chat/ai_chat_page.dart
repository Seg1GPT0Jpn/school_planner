/// 汎用AIチャット ― 要約・添削・翻訳・なんでも質問できるチャット画面
///
/// Firebase AI Logic 経由で Gemini を呼び出す（gemini_advisor.dart と同じしくみ）。
/// 会話はこの画面を開いている間だけ保持し、保存はしない。
library;

import 'package:firebase_ai/firebase_ai.dart';
import 'package:material_ui/material_ui.dart';

import '../review/review_widgets.dart';
import '../settings/preferences_pages.dart';
import '../settings/settings_scope.dart';

void openAiChat(BuildContext context) {
  Navigator.of(
    context,
    rootNavigator: true,
  ).push(MaterialPageRoute<void>(builder: (_) => const AiChatPage()));
}

class _UiMessage {
  _UiMessage({required this.isUser, required this.text});
  final bool isUser;
  String text;
}

class AiChatPage extends StatefulWidget {
  const AiChatPage({super.key});

  @override
  State<AiChatPage> createState() => _AiChatPageState();
}

class _AiChatPageState extends State<AiChatPage> {
  final _inputController = TextEditingController();
  final _scrollController = ScrollController();
  final List<_UiMessage> _messages = [];
  late final ChatSession _chat;
  bool _sending = false;
  bool _unavailable = false;

  static const _suggestions = ['要約して', '添削して', '英語に翻訳して', '説明して'];

  @override
  void initState() {
    super.initState();
    final model = FirebaseAI.googleAI().generativeModel(
      model: 'gemini-3.8-flash',
      systemInstruction: Content.system(
        'あなたは、高校生向け学習管理アプリ「つづり」の中にいる、なんでも相談できるAIアシスタントです。'
        '要約・文章の添削・翻訳・宿題や勉強の質問など、幅広く手伝ってください。'
        '日本語で、高校生にわかりやすく、親しみやすい言葉で答えてください。'
        '長くなりすぎないよう、必要な範囲で簡潔にまとめてください。',
      ),
    );
    _chat = model.startChat();
  }

  @override
  void dispose() {
    _inputController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
      );
    });
  }

  Future<void> _send([String? presetText]) async {
    final text = (presetText ?? _inputController.text).trim();
    if (text.isEmpty || _sending) return;
    if (!SettingsScope.of(context).generativeAiEnabled) {
      setState(() => _unavailable = true);
      return;
    }
    _inputController.clear();
    setState(() {
      _messages.add(_UiMessage(isUser: true, text: text));
      _sending = true;
      _unavailable = false;
    });
    _scrollToBottom();

    final modelMessage = _UiMessage(isUser: false, text: '');
    setState(() => _messages.add(modelMessage));

    try {
      final stream = _chat.sendMessageStream(Content.text(text));
      await for (final chunk in stream) {
        final piece = chunk.text;
        if (piece == null) continue;
        setState(() => modelMessage.text += piece);
        _scrollToBottom();
      }
      if (modelMessage.text.isEmpty) {
        setState(() => modelMessage.text = 'うまく答えられませんでした。もう一度試してください。');
      }
    } catch (e) {
      debugPrint('AIチャットの呼び出しに失敗しました: $e');
      final msg = e.toString();
      final isRateLimited =
          msg.contains('quota') || msg.contains('429') || msg.contains('RESOURCE_EXHAUSTED');
      setState(() {
        modelMessage.text = isRateLimited
            ? 'いま混み合っていて、一時的に利用できません（無料枠のリクエスト上限に達しました）。'
                  '数十秒待ってからもう一度試してください。'
            : 'いま接続できませんでした。設定でAI機能がONか確認するか、また後で試してください。';
        _unavailable = !isRateLimited;
      });
    } finally {
      if (mounted) setState(() => _sending = false);
      _scrollToBottom();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!SettingsScope.of(context).generativeAiEnabled) {
      return Scaffold(
        appBar: AppBar(title: const Text('AIチャット')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.auto_awesome_outlined, size: 48),
                const SizedBox(height: 12),
                const Text(
                  '生成AI（Gemini）がまだONになっていません',
                  style: TextStyle(fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                const Text(
                  '設定 ＞ がんばり・気分 の「生成AI（Gemini）を使う」をONにすると使えます。\n'
                  'ONにしても動かないときは、Firebase Console 側で AI Logic（Gemini Developer API）が'
                  '有効になっているか確認してください。',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 20),
                FilledButton.icon(
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => const MotivationSettingsPage(),
                    ),
                  ),
                  icon: const Icon(Icons.settings),
                  label: const Text('設定を開く'),
                ),
              ],
            ),
          ),
        ),
      );
    }
    return Scaffold(
      appBar: AppBar(title: const Text('AIチャット')),
      body: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: Column(
            children: [
              Expanded(
                child: _messages.isEmpty
                    ? const Center(
                        child: Faint('要約・添削・翻訳・勉強の質問など、なんでも聞いてください'),
                      )
                    : ListView.builder(
                        controller: _scrollController,
                        padding: const EdgeInsets.all(12),
                        itemCount: _messages.length,
                        itemBuilder: (context, i) {
                          final m = _messages[i];
                          return Align(
                            alignment: m.isUser
                                ? Alignment.centerRight
                                : Alignment.centerLeft,
                            child: Container(
                              margin: const EdgeInsets.symmetric(vertical: 4),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 10,
                              ),
                              constraints: BoxConstraints(
                                maxWidth:
                                    MediaQuery.of(context).size.width * 0.8,
                              ),
                              decoration: BoxDecoration(
                                color: m.isUser
                                    ? Theme.of(
                                        context,
                                      ).colorScheme.primaryContainer
                                    : Theme.of(
                                        context,
                                      ).colorScheme.surfaceContainerHighest,
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: Text(
                                m.text.isEmpty ? '…' : m.text,
                              ),
                            ),
                          );
                        },
                      ),
              ),
              if (_messages.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final s in _suggestions)
                        ActionChip(label: Text(s), onPressed: () => _send(s)),
                    ],
                  ),
                ),
              if (_unavailable)
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  child: Faint('設定の「AIアドバイス」がONになっているか確認してみてください'),
                ),
              const Divider(height: 1),
              Padding(
                padding: const EdgeInsets.all(8),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _inputController,
                        minLines: 1,
                        maxLines: 4,
                        decoration: const InputDecoration(
                          hintText: 'メッセージを入力',
                          border: OutlineInputBorder(),
                          isDense: true,
                        ),
                        onSubmitted: (_) => _send(),
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton.filled(
                      icon: _sending
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                              ),
                            )
                          : const Icon(Icons.send),
                      onPressed: _sending ? null : () => _send(),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
