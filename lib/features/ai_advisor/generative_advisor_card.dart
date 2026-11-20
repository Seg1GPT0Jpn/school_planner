/// 生成AI（Gemini）による「今日のひとこと」カード
///
/// 設定でONのときだけ表示。ホームを開くたびに毎回は生成しない（利用枠の節約）。
/// 生成できなかったとき（未設定・オフライン・エラー）は、なにも表示しない
/// （下のルールベースのAIアドバイスカードがフォールバックになる）。
library;

import 'package:material_ui/material_ui.dart';

import 'gemini_advisor.dart';

class GenerativeAdvisorCard extends StatefulWidget {
  const GenerativeAdvisorCard({super.key, required this.input});

  final GeminiAdvisorInput input;

  @override
  State<GenerativeAdvisorCard> createState() => _GenerativeAdvisorCardState();
}

class _GenerativeAdvisorCardState extends State<GenerativeAdvisorCard> {
  Future<String?>? _future;

  @override
  void initState() {
    super.initState();
    _generate();
  }

  void _generate() {
    setState(() {
      _future = generateAdvisorMessage(widget.input);
    });
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<String?>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const SizedBox.shrink();
        }
        final text = snapshot.data;
        if (text == null) return const SizedBox.shrink();

        final cs = Theme.of(context).colorScheme;
        return Card(
          color: cs.primaryContainer,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.auto_awesome,
                  color: cs.onPrimaryContainer,
                  size: 20,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(text, style: TextStyle(color: cs.onPrimaryContainer)),
                ),
                IconButton(
                  icon: Icon(
                    Icons.refresh,
                    size: 18,
                    color: cs.onPrimaryContainer,
                  ),
                  tooltip: '作り直す',
                  onPressed: _generate,
                  visualDensity: VisualDensity.compact,
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
