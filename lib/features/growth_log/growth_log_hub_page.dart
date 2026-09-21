/// 成長ログの入り口（成長ログを使うカテゴリの一覧）
library;

import 'package:material_ui/material_ui.dart';

import '../events/event_category.dart';
import '../events/event_category_repository.dart';
import 'growth_log_history_page.dart';
import 'growth_log_repository.dart';

void openGrowthLogHub(
  BuildContext context, {
  required EventCategoryRepository categoryRepository,
  required GrowthLogRepository repository,
}) {
  Navigator.of(context, rootNavigator: true).push(
    MaterialPageRoute<void>(
      builder: (_) => GrowthLogHubPage(
        categoryRepository: categoryRepository,
        repository: repository,
      ),
    ),
  );
}

class GrowthLogHubPage extends StatelessWidget {
  const GrowthLogHubPage({
    super.key,
    required this.categoryRepository,
    required this.repository,
  });

  final EventCategoryRepository categoryRepository;
  final GrowthLogRepository repository;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('成長ログ')),
      body: StreamBuilder<List<EventCategory>>(
        stream: categoryRepository.watch(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final categories = [
            for (final c in snapshot.data!)
              if (c.growthLogEnabled) c,
          ];
          if (categories.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.trending_up, size: 48, color: cs.outline),
                    const SizedBox(height: 12),
                    Text(
                      'まだ成長ログ用のカテゴリがありません。\n'
                      'カテゴリの編集で「成長ログを使う」をONにすると、\n'
                      'ここに表示されます。',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: cs.outline),
                    ),
                  ],
                ),
              ),
            );
          }
          return Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 560),
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  for (final c in categories)
                    Card(
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: Color(c.colorValue),
                        ),
                        title: Text(c.name),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () => openGrowthLogHistory(
                          context,
                          category: c,
                          repository: repository,
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
