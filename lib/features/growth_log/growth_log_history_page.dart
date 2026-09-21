/// 成長ログの一覧（あるカテゴリの記録すべて）
library;

import 'package:material_ui/material_ui.dart';

import '../events/event_category.dart';
import '../settings/settings_scope.dart';
import 'growth_log.dart';
import 'growth_log_entry_page.dart';
import 'growth_log_repository.dart';

void openGrowthLogHistory(
  BuildContext context, {
  required EventCategory category,
  required GrowthLogRepository repository,
}) {
  Navigator.of(context, rootNavigator: true).push(
    MaterialPageRoute<void>(
      builder: (_) =>
          GrowthLogHistoryPage(category: category, repository: repository),
    ),
  );
}

class GrowthLogHistoryPage extends StatelessWidget {
  const GrowthLogHistoryPage({
    super.key,
    required this.category,
    required this.repository,
  });

  final EventCategory category;
  final GrowthLogRepository repository;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final s = SettingsScope.of(context);

    return Scaffold(
      appBar: AppBar(title: Text('${category.name}の成長ログ')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => openGrowthLogEntry(
          context,
          repository: repository,
          categoryId: category.id,
          title: category.name,
        ),
        icon: const Icon(Icons.add),
        label: const Text('記録する'),
      ),
      body: StreamBuilder<List<GrowthLogEntry>>(
        stream: repository.watchForCategory(category.id),
        builder: (context, snap) {
          if (!snap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final entries = [...snap.data!]
            ..sort((a, b) => b.date.compareTo(a.date));
          if (entries.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  'まだ記録がありません。「記録する」から最初の記録を残しましょう。',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: cs.outline),
                ),
              ),
            );
          }

          final now = DateTime.now();
          final weekAgo = now.subtract(const Duration(days: 7));
          final monthAgo = now.subtract(const Duration(days: 30));
          final totalAll = entries.fold<int>(0, (s, e) => s + e.minutes);
          final totalWeek = entries
              .where((e) => e.date.isAfter(weekAgo))
              .fold<int>(0, (s, e) => s + e.minutes);
          final totalMonth = entries
              .where((e) => e.date.isAfter(monthAgo))
              .fold<int>(0, (s, e) => s + e.minutes);

          String hm(int m) => m >= 60 ? '${m ~/ 60}時間${m % 60}分' : '$m分';

          final recent = entries.take(8).toList().reversed.toList();
          final maxMinutes = recent.isEmpty
              ? 1
              : recent
                    .map((e) => e.minutes)
                    .fold<int>(1, (m, x) => x > m ? x : m);

          return Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 560),
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 88),
                children: [
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              _Stat(label: '今週', value: hm(totalWeek)),
                              _Stat(label: '今月', value: hm(totalMonth)),
                              _Stat(label: '全体', value: hm(totalAll)),
                            ],
                          ),
                          if (recent.length >= 2) ...[
                            const SizedBox(height: 16),
                            SizedBox(
                              height: 60,
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  for (final e in recent)
                                    Expanded(
                                      child: Padding(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 2,
                                        ),
                                        child: Tooltip(
                                          message: '${hm(e.minutes)}'
                                              '（${s.date(e.date)}）',
                                          child: FractionallySizedBox(
                                            heightFactor:
                                                e.minutes / maxMinutes,
                                            alignment: Alignment.bottomCenter,
                                            child: Container(
                                              decoration: BoxDecoration(
                                                color: Color(
                                                  category.colorValue,
                                                ),
                                                borderRadius:
                                                    BorderRadius.circular(3),
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                            Text(
                              '直近${recent.length}回の記録時間',
                              style: tt.bodySmall?.copyWith(color: cs.outline),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  for (final e in entries)
                    Card(
                      child: ListTile(
                        title: Text(e.title),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${s.date(e.date, weekday: true)}'
                              '${e.minutes > 0 ? '・${hm(e.minutes)}' : ''}',
                            ),
                            if (e.note.isNotEmpty)
                              Text(
                                e.note,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                          ],
                        ),
                        isThreeLine: e.note.isNotEmpty,
                        trailing: e.rating == null
                            ? null
                            : Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.star,
                                    size: 16,
                                    color: Color(category.colorValue),
                                  ),
                                  Text('${e.rating}'),
                                ],
                              ),
                        onTap: () => openGrowthLogEntry(
                          context,
                          repository: repository,
                          categoryId: category.id,
                          existing: e,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    return Column(
      children: [
        Text(value, style: tt.titleMedium),
        Text(label, style: tt.bodySmall?.copyWith(color: cs.outline)),
      ],
    );
  }
}
