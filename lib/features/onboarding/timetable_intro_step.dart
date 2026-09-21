/// ⑨ 時間割を入力しましょう！（スキップ可）
library;

import 'package:material_ui/material_ui.dart';

import '../timetable/timetable_page.dart';

class TimetableIntroStep extends StatelessWidget {
  const TimetableIntroStep({super.key, required this.onNext});

  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    return Scaffold(
      body: SafeArea(
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(24, 40, 24, 24),
              children: [
                Icon(Icons.event_note, size: 48, color: cs.primary),
                const SizedBox(height: 16),
                Text('⑨ 時間割を入力しましょう！', style: tt.headlineSmall),
                const SizedBox(height: 8),
                Text(
                  '科目やクラスなど、いつもの時間割を入れておくと、'
                  'ホーム画面や日々の予定にすぐ反映されます。あとからでも入力できます。',
                  style: tt.bodyMedium?.copyWith(color: cs.outline),
                ),
                const SizedBox(height: 28),
                FilledButton.icon(
                  onPressed: () async {
                    await Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => const TimetablePage(),
                      ),
                    );
                    if (context.mounted) onNext();
                  },
                  icon: const Icon(Icons.edit_calendar),
                  label: const Text('時間割を入力する'),
                ),
                const SizedBox(height: 12),
                OutlinedButton(
                  onPressed: onNext,
                  child: const Text('あとで入力する（スキップ）'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
