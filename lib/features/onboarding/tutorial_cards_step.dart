/// ⑩ チュートリアル（スキップ可）
///
/// 実際の画面に重ねる案内（コーチマーク）ではなく、
/// 順番にめくる、かんたんな説明カードだけの軽量版。
library;

import 'package:material_ui/material_ui.dart';

class _TutorialCard {
  const _TutorialCard(this.icon, this.title, this.body);

  final IconData icon;
  final String title;
  final String body;
}

const _cards = [
  _TutorialCard(
    Icons.home_outlined,
    'ホーム画面をつかってみよう',
    '今日・明日の予定や時間割、テストまでの日数などが、ホーム画面にまとまって出てきます。'
        '毎日まずここを見れば、学校生活の全体がわかります。',
  ),
  _TutorialCard(
    Icons.calendar_month_outlined,
    'カレンダーを操作してみよう',
    '予定はカレンダーからも追加・編集できます。タップした日の予定がすぐ確認でき、'
        'テストや行事もまとめて表示されます。',
  ),
  _TutorialCard(
    Icons.schedule_outlined,
    '時間割をいじってみよう',
    '時間割タブから、科目の変更や振替・自習などをその場で直せます。'
        '時程そのものを変えたいときは、設定 ＞ 時程の設定から調整できます。',
  ),
  _TutorialCard(
    Icons.checklist_outlined,
    'To doリストを作成しよう',
    '宿題や提出物などは To do リストで管理できます。終わらせるとポイントがたまって、'
        '続けるほど記録が積み重なっていきます。',
  ),
  _TutorialCard(
    Icons.flag_outlined,
    '目標を設定しよう',
    'テストの目標点や、部活・勉強の目標を登録しておけます。'
        '日々の記録と合わせて、振り返りにも使えます。',
  ),
];

class TutorialCardsStep extends StatefulWidget {
  const TutorialCardsStep({super.key, required this.onDone});

  final VoidCallback onDone;

  @override
  State<TutorialCardsStep> createState() => _TutorialCardsStepState();
}

class _TutorialCardsStepState extends State<TutorialCardsStep> {
  final _controller = PageController();
  int _index = 0;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _next() {
    if (_index == _cards.length - 1) {
      widget.onDone();
      return;
    }
    setState(() => _index++);
    _controller.animateToPage(
      _index,
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: const Text('⑩ 使い方の案内'),
        actions: [
          TextButton(onPressed: widget.onDone, child: const Text('スキップ')),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: PageView.builder(
              controller: _controller,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _cards.length,
              itemBuilder: (context, i) => _CardView(card: _cards[i]),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                for (var i = 0; i < _cards.length; i++)
                  Container(
                    margin: const EdgeInsets.symmetric(horizontal: 3),
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: i == _index
                          ? cs.primary
                          : cs.surfaceContainerHighest,
                    ),
                  ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
            child: FilledButton(
              onPressed: _next,
              child: Text(_index == _cards.length - 1 ? '完了' : '次へ'),
            ),
          ),
        ],
      ),
    );
  }
}

class _CardView extends StatelessWidget {
  const _CardView({required this.card});

  final _TutorialCard card;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 40, 24, 24),
          child: Column(
            children: [
              Icon(card.icon, size: 56, color: cs.primary),
              const SizedBox(height: 20),
              Text(
                card.title,
                style: tt.headlineSmall,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              Text(
                card.body,
                style: tt.bodyMedium?.copyWith(color: cs.outline),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
