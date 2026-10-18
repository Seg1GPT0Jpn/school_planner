import 'package:material_ui/material_ui.dart';
import 'package:url_launcher/url_launcher.dart';

import '../study/study.dart';
import 'quest_link.dart';

/// つづりクエストを開く
Future<void> openQuest() =>
    launchUrl(Uri.parse(questUrl), mode: LaunchMode.externalApplication);

/// ホームの「つづりクエスト」：クエストで勉強した時間・問題数・苦手な単元
class QuestLinkCard extends StatelessWidget {
  const QuestLinkCard({super.key, required this.results, required this.now});

  /// クエストから届いた成果（まだつないでいなければ null）
  final QuestResults? results;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final r = results;
    String sum(QuestSum s) {
      final acc = s.accuracy;
      return '${s.minutes == 0 ? '0分' : formatMinutes(s.minutes)}・${s.answered}問'
          '${acc == null ? '' : '（正答率$acc%）'}';
    }

    return Card(
      key: const ValueKey('quest-link-card'),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 8, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.sports_esports_outlined, color: cs.primary),
                const SizedBox(width: 12),
                Expanded(child: Text('つづりクエスト', style: tt.titleMedium)),
              ],
            ),
            const SizedBox(height: 8),
            if (r == null)
              Text(
                'つづりクエストの「アカウント」から「つづりと連携」すると、'
                'ここのテスト予定がクエストに届き、クエストで勉強した時間と成果がここに出ます。',
                style: tt.bodySmall?.copyWith(color: cs.outline),
              )
            else ...[
              Text('今日：${sum(r.todayAt(now))}'),
              Text('この1週間：${sum(r.week)}'),
              if (r.updatedAt != null && r.todayAt(now) != r.today)
                Text(
                  '${r.updatedAt!.month}/${r.updatedAt!.day} にクエストから届いた記録です',
                  style: tt.bodySmall?.copyWith(color: cs.outline),
                ),
              if (r.weak.isNotEmpty) ...[
                const SizedBox(height: 6),
                Text('苦手な単元', style: tt.bodySmall?.copyWith(color: cs.outline)),
                for (final w in r.weak.take(3))
                  Text(
                    '・${w.unit}（正答率${w.accuracy}%）',
                    style: tt.bodySmall,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
              ],
            ],
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                key: const ValueKey('open-quest'),
                onPressed: openQuest,
                icon: const Icon(Icons.open_in_new, size: 18),
                label: const Text('クエストを開く'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
