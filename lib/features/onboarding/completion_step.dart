/// ⑪ 準備が整いました！これからの日々をつづりましょう → ⑫ ホーム画面へ
library;

import 'package:material_ui/material_ui.dart';

class CompletionStep extends StatelessWidget {
  const CompletionStep({super.key, required this.onGoHome});

  final VoidCallback onGoHome;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.check_circle, size: 72, color: cs.primary),
              const SizedBox(height: 20),
              Text(
                '準備が整いました！',
                style: tt.headlineSmall,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                'これからの日々を、つづりましょう。',
                style: tt.bodyLarge?.copyWith(color: cs.outline),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),
              FilledButton.icon(
                onPressed: onGoHome,
                icon: const Icon(Icons.home),
                label: const Text('ホーム画面へ'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
