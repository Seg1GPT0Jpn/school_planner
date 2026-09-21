/// ①最初の画面：アプリのイメージをアニメーションで見せてから、説明文をだんだん表示する
///
/// 動画は用意していないので、Flutter のアニメーションだけで
/// 「ロゴがふわっと浮かび上がる → 予定っぽいカードが並ぶ → 説明文がだんだん表示される」
/// という流れを作る。
library;

import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

class IntroPage extends StatefulWidget {
  const IntroPage({super.key});

  @override
  State<IntroPage> createState() => _IntroPageState();
}

class _IntroPageState extends State<IntroPage>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 3200),
  )..forward();

  // タイムライン上のいろいろな区間（0.0〜1.0）
  late final _logo = CurvedAnimation(
    parent: _c,
    curve: const Interval(0.0, 0.35, curve: Curves.easeOutBack),
  );
  late final _cards = CurvedAnimation(
    parent: _c,
    curve: const Interval(0.25, 0.6, curve: Curves.easeOut),
  );
  late final _title = CurvedAnimation(
    parent: _c,
    curve: const Interval(0.45, 0.7, curve: Curves.easeOut),
  );
  late final _lead = CurvedAnimation(
    parent: _c,
    curve: const Interval(0.6, 0.85, curve: Curves.easeOut),
  );
  late final _button = CurvedAnimation(
    parent: _c,
    curve: const Interval(0.85, 1.0, curve: Curves.easeOut),
  );

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  void _go() {
    if (!mounted) return;
    context.go('/login');
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Scaffold(
      body: SafeArea(
        child: Stack(
          children: [
            // 背景：予定っぽいカードがふわっと並ぶ
            Positioned.fill(
              child: AnimatedBuilder(
                animation: _cards,
                builder: (context, _) => Opacity(
                  opacity: _cards.value,
                  child: Transform.translate(
                    offset: Offset(0, (1 - _cards.value) * 16),
                    child: _BackgroundCards(color: cs.primary),
                  ),
                ),
              ),
            ),

            // 右上：スキップ
            Positioned(
              top: 8,
              right: 8,
              child: AnimatedBuilder(
                animation: _button,
                builder: (context, _) => Opacity(
                  opacity: _button.value,
                  child: TextButton(
                    onPressed: _go,
                    child: const Text('スキップ'),
                  ),
                ),
              ),
            ),

            Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    AnimatedBuilder(
                      animation: _logo,
                      builder: (context, _) => Transform.scale(
                        scale: 0.6 + 0.4 * _logo.value,
                        child: Opacity(
                          opacity: _logo.value.clamp(0, 1),
                          child: Icon(
                            Icons.menu_book,
                            size: 76,
                            color: cs.primary,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    AnimatedBuilder(
                      animation: _title,
                      builder: (context, _) => Opacity(
                        opacity: _title.value,
                        child: Transform.translate(
                          offset: Offset(0, (1 - _title.value) * 10),
                          child: Text('つづり', style: tt.headlineMedium),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    AnimatedBuilder(
                      animation: _lead,
                      builder: (context, _) => Opacity(
                        opacity: _lead.value,
                        child: Transform.translate(
                          offset: Offset(0, (1 - _lead.value) * 10),
                          child: Text(
                            '時間割・予定・テスト・目標をひとつに。\n'
                            '学校生活の記録を、ここに「つづって」いこう。',
                            textAlign: TextAlign.center,
                            style: tt.bodyLarge?.copyWith(color: cs.outline),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 36),
                    AnimatedBuilder(
                      animation: _button,
                      builder: (context, _) => Opacity(
                        opacity: _button.value,
                        child: IgnorePointer(
                          ignoring: _button.value < 0.4,
                          child: FilledButton.icon(
                            onPressed: _go,
                            icon: const Icon(Icons.arrow_forward),
                            label: const Text('はじめる'),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 背景にふわっと浮かぶ、予定カードっぽい図形
class _BackgroundCards extends StatelessWidget {
  const _BackgroundCards({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    Widget bar(double width, double top, double left, double opacity) =>
        Positioned(
          top: top,
          left: left,
          child: Container(
            width: width,
            height: 46,
            decoration: BoxDecoration(
              color: color.withOpacity(opacity),
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        );

    return LayoutBuilder(
      builder: (context, constraints) => Stack(
        children: [
          bar(constraints.maxWidth * 0.55, constraints.maxHeight * 0.14,
              -constraints.maxWidth * 0.15, 0.08),
          bar(constraints.maxWidth * 0.45, constraints.maxHeight * 0.24,
              constraints.maxWidth * 0.6, 0.06),
          bar(constraints.maxWidth * 0.5, constraints.maxHeight * 0.78,
              constraints.maxWidth * 0.55, 0.07),
          bar(constraints.maxWidth * 0.4, constraints.maxHeight * 0.86,
              -constraints.maxWidth * 0.1, 0.05),
        ],
      ),
    );
  }
}
