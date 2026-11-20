/// 忘れ物探偵 ― 明日（次の登校日）の持ち物のうち、しばらく持っていっていない
/// ものを教えてくれるカード。既存の「持ち物」設定・checkedとは別に、
/// 持ち物ごとの「最後に持っていった日」を記録して使う。
library;

import 'package:material_ui/material_ui.dart';

import '../events/calendar_event.dart';
import '../recurring/recurring_schedule.dart';
import '../timetable/day_timetable_resolver.dart';
import '../timetable/timetable_repository.dart';
import 'belongings.dart';
import 'belongings_repository.dart';

class ForgottenItemDetectiveCard extends StatefulWidget {
  const ForgottenItemDetectiveCard({
    super.key,
    required this.data,
    required this.recurring,
    required this.repository,
    this.events = const [],
  });

  final TimetableData data;
  final List<RecurringSchedule> recurring;
  final BelongingsRepository repository;

  /// 定期でない予定（カテゴリごとの持ち物・予定ごとの持ち物に使う）
  final List<CalendarEvent> events;

  @override
  State<ForgottenItemDetectiveCard> createState() =>
      _ForgottenItemDetectiveCardState();
}

class _ForgottenItemDetectiveCardState
    extends State<ForgottenItemDetectiveCard> {
  late final _settings = widget.repository.watchSettings();
  late final _lastBrought = widget.repository.watchLastBrought();

  /// 明日（明日が休みなら次の登校日。7日先まで）
  DateTime get _target {
    final now = DateTime.now();
    for (var i = 1; i <= 7; i++) {
      final d = DateTime(now.year, now.month, now.day + i);
      if (widget.data.resolver.resolve(d).status == DayStatus.school) {
        return d;
      }
    }
    return DateTime(now.year, now.month, now.day + 1);
  }

  String _agoLabel(DateTime? last) {
    if (last == null) return '記録がありません';
    final lastDay = DateTime(last.year, last.month, last.day);
    final today = DateTime.now();
    final todayDay = DateTime(today.year, today.month, today.day);
    final days = todayDay.difference(lastDay).inDays;
    if (days <= 0) return '今日持っていきました';
    return '前回から$days日';
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final target = _target;

    return StreamBuilder<BelongingSettings>(
      stream: _settings,
      builder: (context, ss) {
        final items = belongingsFor(
          day: widget.data.resolver.resolve(target),
          recurring: widget.recurring,
          settings: ss.data ?? const BelongingSettings(),
          events: widget.events,
        );
        if (items.isEmpty) return const SizedBox.shrink();

        return StreamBuilder<Map<String, DateTime>>(
          stream: _lastBrought,
          builder: (context, ls) {
            final last = ls.data ?? const <String, DateTime>{};
            final warnings = [
              for (final x in items)
                if (last[x] == null ||
                    DateTime.now().difference(last[x]!).inDays >= 3)
                  x,
            ];

            return Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.search, color: cs.primary, size: 20),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            '忘れ物探偵（${target.month}/${target.day}）',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                        ),
                      ],
                    ),
                    if (warnings.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 6, bottom: 4),
                        child: Text(
                          '⚠️ ${warnings.length}件、しばらく持っていっていないかもしれません',
                          style: TextStyle(color: cs.error, fontSize: 12),
                        ),
                      ),
                    for (final x in items)
                      ListTile(
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        title: Text(x),
                        subtitle: Text(
                          _agoLabel(last[x]),
                          style: TextStyle(
                            color: warnings.contains(x)
                                ? cs.error
                                : cs.outline,
                            fontSize: 12,
                          ),
                        ),
                        trailing: FilledButton.tonal(
                          onPressed: () => widget.repository.markBrought(x),
                          child: const Text('持った'),
                        ),
                      ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}
