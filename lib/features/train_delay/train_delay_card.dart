/// ホームに出す「よく使う路線」の運行状況
library;

import 'package:material_ui/material_ui.dart';
import 'package:url_launcher/url_launcher.dart';

import '../settings/app_settings.dart';
import 'train_delay_models.dart';
import 'train_delay_service.dart';
import 'train_lines.dart';

// ── Cloud Functions が使えないとき（未デプロイなど）に見にいく、代わりの情報源 ──

/// 路線名で検索する（Google 検索）
Uri _lineSearchUri(String lineName) =>
    Uri.https('www.google.com', '/search', {'q': '$lineName 運行情報'});

/// Yahoo!路線情報の運行情報トップ（今止まっている路線が一覧で見られる）
final _yahooTransitUri = Uri.https('transit.yahoo.co.jp', '/diainfo');

Future<void> _openExternal(BuildContext context, Uri uri) async {
  final messenger = ScaffoldMessenger.of(context);
  var ok = false;
  try {
    ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
  } catch (_) {
    ok = false;
  }
  if (!ok) {
    messenger.showSnackBar(const SnackBar(content: Text('開けませんでした')));
  }
}

/// 遅延・運転見合わせなどがあるかどうか
Color _statusColor(String status, ColorScheme cs) {
  if (status.contains('見合わせ') || status.contains('運休')) {
    return const Color(0xFFB71C1C);
  }
  if (status.contains('遅延') || status.contains('遅れ')) {
    return const Color(0xFFEF6C00);
  }
  return cs.outline;
}

class TrainDelayCard extends StatefulWidget {
  const TrainDelayCard({super.key, required this.settings});

  final AppSettings settings;

  @override
  State<TrainDelayCard> createState() => _TrainDelayCardState();
}

class _TrainDelayCardState extends State<TrainDelayCard> {
  late Future<TrainStatusBundle> _future = TrainDelayService.instance.load(
    widget.settings.favoriteLineIds,
  );

  @override
  void didUpdateWidget(covariant TrainDelayCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.settings.favoriteLineIds != widget.settings.favoriteLineIds) {
      _future = TrainDelayService.instance.load(
        widget.settings.favoriteLineIds,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.settings.favoriteLineIds.isEmpty) {
      return const SizedBox.shrink();
    }
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return FutureBuilder<TrainStatusBundle>(
      future: _future,
      builder: (context, snap) {
        final bundle = snap.data ?? TrainDelayService.instance.cached;
        if (bundle == null) {
          return Card(
            child: ListTile(
              leading: const Icon(Icons.train_outlined),
              title: const Text('運行情報を読み込んでいます…'),
            ),
          );
        }
        final lines = [
          for (final id in widget.settings.favoriteLineIds)
            if (findTrainLine(id) case final l?) l,
        ];
        final anyTrouble = lines.any(
          (l) => !(bundle.statuses[l.id]?.isNormal ?? true),
        );

        return Card(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(
              color: anyTrouble ? const Color(0xFFEF6C00) : cs.outlineVariant,
              width: anyTrouble ? 2 : 1,
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.train_outlined, color: cs.primary),
                    const SizedBox(width: 8),
                    Text('運行情報', style: tt.titleMedium),
                  ],
                ),
                const SizedBox(height: 8),
                for (final l in lines)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 3),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SizedBox(width: 110, child: Text(l.name)),
                        Expanded(
                          child: Text(
                            (bundle.statuses[l.id]?.isNormal ?? true)
                                ? '平常運転'
                                : (bundle.statuses[l.id]?.status.isNotEmpty ==
                                          true
                                      ? bundle.statuses[l.id]!.status
                                      : bundle.statuses[l.id]!.text),
                            style: TextStyle(
                              color: _statusColor(
                                bundle.statuses[l.id]?.status ?? '',
                                cs,
                              ),
                              fontWeight:
                                  (bundle.statuses[l.id]?.isNormal ?? true)
                                  ? null
                                  : FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                if (bundle.error == null && bundle.source == 'free')
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(
                      '無料の代わりの情報源（てつどう遅延情報）から取得しています。'
                      '対応していない路線は「平常運転」と出ます。',
                      style: tt.bodySmall?.copyWith(color: cs.outline),
                    ),
                  ),
                if (bundle.error != null) ...[
                  Padding(
                    padding: const EdgeInsets.only(top: 6, bottom: 4),
                    child: Text(
                      '自動での取得ができません。かわりに、こちらで確認できます。',
                      style: tt.bodySmall?.copyWith(color: cs.outline),
                    ),
                  ),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      for (final l in lines)
                        OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            visualDensity: VisualDensity.compact,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                            ),
                          ),
                          onPressed: () =>
                              _openExternal(context, _lineSearchUri(l.name)),
                          icon: const Icon(Icons.open_in_new, size: 14),
                          label: Text(l.name),
                        ),
                    ],
                  ),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton.icon(
                      onPressed: () =>
                          _openExternal(context, _yahooTransitUri),
                      icon: const Icon(Icons.travel_explore, size: 18),
                      label: const Text('Yahoo!路線情報で確認する'),
                    ),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}
