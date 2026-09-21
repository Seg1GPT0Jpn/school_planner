/// ホームに出す「予定の候補」カード（行動パターンからの提案）
library;

import 'package:material_ui/material_ui.dart';

import '../recurring/recurring_repository.dart';
import '../recurring/recurring_schedule.dart';
import '../settings/preferences_pages.dart';
import '../settings/settings_scope.dart';
import 'pattern_suggest.dart';

class PatternSuggestCard extends StatefulWidget {
  const PatternSuggestCard({
    super.key,
    required this.suggestions,
    required this.recurringRepository,
  });

  final List<PatternSuggestion> suggestions;
  final RecurringRepository recurringRepository;

  @override
  State<PatternSuggestCard> createState() => _PatternSuggestCardState();
}

class _PatternSuggestCardState extends State<PatternSuggestCard> {
  final _busy = <String>{};
  final _added = <String>{};

  Future<void> _add(PatternSuggestion s) async {
    setState(() => _busy.add(s.key));
    try {
      await widget.recurringRepository.save(
        RecurringSchedule(
          title: s.title,
          weekday: s.weekday,
          start: s.start,
          end: s.end,
          categoryId: s.categoryId,
          location: s.location,
        ),
      );
      if (mounted) setState(() => _added.add(s.key));
    } finally {
      if (mounted) setState(() => _busy.remove(s.key));
    }
  }

  Future<void> _dismiss(PatternSuggestion s) async {
    final settings = SettingsScope.of(context);
    await saveSettings(
      context,
      settings.copyWith(
        dismissedPatternKeys: [...settings.dismissedPatternKeys, s.key],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final list = [
      for (final s in widget.suggestions)
        if (!_added.contains(s.key)) s,
    ];
    if (list.isEmpty) return const SizedBox.shrink();

    String timeText(int h, int m) =>
        '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}';

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.auto_awesome_outlined, color: cs.primary),
                const SizedBox(width: 8),
                Text('予定の候補', style: tt.titleMedium),
              ],
            ),
            const SizedBox(height: 2),
            Text(
              'よく入れている予定を、定期の予定にしませんか？',
              style: tt.bodySmall?.copyWith(color: cs.outline),
            ),
            const SizedBox(height: 8),
            for (final s in list)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(s.title),
                          Text(
                            '毎週${s.weekdayLabel}曜'
                            '・${timeText(s.start.hour, s.start.minute)}'
                            '〜${timeText(s.end.hour, s.end.minute)}'
                            '（直近${s.occurrences}週）',
                            style: tt.bodySmall?.copyWith(color: cs.outline),
                          ),
                        ],
                      ),
                    ),
                    if (_busy.contains(s.key))
                      const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    else ...[
                      IconButton(
                        tooltip: '提案を消す',
                        icon: const Icon(Icons.close, size: 20),
                        onPressed: () => _dismiss(s),
                      ),
                      FilledButton.tonal(
                        onPressed: () => _add(s),
                        child: const Text('定期にする'),
                      ),
                    ],
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}
