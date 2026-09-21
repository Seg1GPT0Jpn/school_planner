/// 地震情報の画面
///
/// ・震度3以上の最新の地震（震度分布図つき）
/// ・過去100件ほどの履歴（震度1以上）
/// ・リアルタイム震度（防災科学技術研究所 強震モニタ へのリンク）
library;

import 'package:material_ui/material_ui.dart';
import 'package:url_launcher/url_launcher.dart';

import 'earthquake_models.dart';
import 'earthquake_service.dart';
import 'intensity_map_painter.dart';

void openEarthquake(BuildContext context) {
  Navigator.of(
    context,
    rootNavigator: true,
  ).push(MaterialPageRoute<void>(builder: (_) => const EarthquakePage()));
}

String _hm2(DateTime t) =>
    '${t.month}/${t.day} ${t.hour}:${t.minute.toString().padLeft(2, '0')}';

class EarthquakePage extends StatefulWidget {
  const EarthquakePage({super.key});

  @override
  State<EarthquakePage> createState() => _EarthquakePageState();
}

class _EarthquakePageState extends State<EarthquakePage> {
  late Future<List<EarthquakeInfo>> _future = EarthquakeService.instance.load();

  Future<void> _refresh() async {
    final f = EarthquakeService.instance.load(force: true);
    setState(() => _future = f);
    await f;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('地震情報'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: '取り直す',
            onPressed: _refresh,
          ),
        ],
      ),
      body: FutureBuilder<List<EarthquakeInfo>>(
        future: _future,
        builder: (context, snap) {
          final list = snap.data ?? EarthquakeService.instance.cached;
          if (list == null) {
            return snap.hasError
                ? Center(child: Text('読み込めませんでした\n${snap.error}'))
                : const Center(child: CircularProgressIndicator());
          }
          return RefreshIndicator(
            onRefresh: _refresh,
            child: _EarthquakeBody(list: list),
          );
        },
      ),
    );
  }
}

class _EarthquakeBody extends StatelessWidget {
  const _EarthquakeBody({required this.list});

  final List<EarthquakeInfo> list;

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;

    // 震度3以上の最新
    EarthquakeInfo? latestSignificant;
    for (final e in list) {
      if ((e.maxScale ?? 0) >= 30) {
        latestSignificant = e;
        break;
      }
    }
    // 震度1以上（履歴一覧）
    final history = [
      for (final e in list)
        if ((e.maxScale ?? 0) >= 10) e,
    ];

    const gap = SizedBox(height: 12);

    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 720),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
          children: [
            _Section(
              title: 'リアルタイム震度',
              icon: Icons.sensors,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '本物のリアルタイム震度は、防災科学技術研究所（NIED）の'
                    '「強震モニタ」で見られます。いまゆれているかどうかが'
                    '数秒ごとに更新されます。',
                  ),
                  const SizedBox(height: 10),
                  FilledButton.icon(
                    onPressed: () => launchUrl(
                      kmoniUri,
                      mode: LaunchMode.externalApplication,
                    ),
                    icon: const Icon(Icons.open_in_new),
                    label: const Text('強震モニタを開く'),
                  ),
                ],
              ),
            ),
            gap,
            _Section(
              title: '震度3以上の最新の地震',
              icon: Icons.warning_amber_rounded,
              child: latestSignificant == null
                  ? Text(
                      '最近、震度3以上の地震はありません',
                      style: TextStyle(color: cs.outline),
                    )
                  : _EarthquakeDetail(info: latestSignificant),
            ),
            gap,
            _Section(
              title: '地震の履歴（震度1以上・最新100件）',
              icon: Icons.history,
              child: history.isEmpty
                  ? Text('履歴がありません', style: TextStyle(color: cs.outline))
                  : Column(
                      children: [
                        for (final e in history)
                          _HistoryTile(
                            info: e,
                            onTap: () => _openDetail(context, e),
                          ),
                      ],
                    ),
            ),
            const SizedBox(height: 16),
            Text(
              '地震情報：気象庁の発表をもとにした P2P地震情報（p2pquake.net）\n'
              'リアルタイム震度：防災科学技術研究所（NIED） 強震モニタ',
              style: tt.bodySmall?.copyWith(color: cs.outline),
            ),
          ],
        ),
      ),
    );
  }

  void _openDetail(BuildContext context, EarthquakeInfo info) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        minChildSize: 0.4,
        maxChildSize: 0.95,
        expand: false,
        builder: (context, scrollController) => SingleChildScrollView(
          controller: scrollController,
          padding: const EdgeInsets.all(16),
          child: _EarthquakeDetail(info: info),
        ),
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({
    required this.title,
    required this.icon,
    required this.child,
  });

  final String title;
  final IconData icon;
  final Widget child;

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                icon,
                size: 20,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(width: 6),
              Text(title, style: Theme.of(context).textTheme.titleMedium),
            ],
          ),
          const SizedBox(height: 10),
          child,
        ],
      ),
    ),
  );
}

class _HistoryTile extends StatelessWidget {
  const _HistoryTile({required this.info, required this.onTap});

  final EarthquakeInfo info;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return ListTile(
      contentPadding: EdgeInsets.zero,
      dense: true,
      onTap: onTap,
      leading: Container(
        width: 34,
        height: 34,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: scaleColor(info.maxScale ?? 0),
          shape: BoxShape.circle,
        ),
        child: Text(
          scaleLabel(info.maxScale),
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 12,
          ),
        ),
      ),
      title: Text(info.hypocenterName),
      subtitle: Text(
        '${_hm2(info.time)}　'
        '${info.magnitude == null ? 'M不明' : 'M${info.magnitude!.toStringAsFixed(1)}'}',
        style: TextStyle(color: cs.outline),
      ),
      trailing: const Icon(Icons.chevron_right),
    );
  }
}

class _EarthquakeDetail extends StatelessWidget {
  const _EarthquakeDetail({required this.info});

  final EarthquakeInfo info;

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    final byPref = info.maxScaleByPref;
    final epicenter = (info.latitude != null && info.longitude != null)
        ? (info.latitude!, info.longitude!)
        : null;

    Widget row(String label, String value) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 84,
            child: Text(label, style: TextStyle(color: cs.outline)),
          ),
          Expanded(child: Text(value)),
        ],
      ),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 44,
              height: 44,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: scaleColor(info.maxScale ?? 0),
                shape: BoxShape.circle,
              ),
              child: Text(
                scaleLabel(info.maxScale),
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(info.hypocenterName, style: tt.titleMedium),
                  Text(_hm2(info.time), style: TextStyle(color: cs.outline)),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (byPref.isNotEmpty) ...[
          IntensityMap(maxScaleByPref: byPref, epicenter: epicenter),
          const SizedBox(height: 10),
        ],
        row('発生時刻', _hm2(info.time)),
        row('震源地', info.hypocenterName),
        row('最大震度', scaleLabel(info.maxScale)),
        row(
          'マグニチュード',
          info.magnitude == null
              ? '不明'
              : 'M${info.magnitude!.toStringAsFixed(1)}',
        ),
        row(
          '深さ',
          info.depth == null ? '不明' : '約${info.depth!.toStringAsFixed(0)}km',
        ),
        row(
          '緯度経度',
          epicenter == null
              ? '不明'
              : '北緯${epicenter.$1.toStringAsFixed(2)}° '
                    '東経${epicenter.$2.toStringAsFixed(2)}°',
        ),
        if (tsunamiLabel(info.domesticTsunami).isNotEmpty)
          row('情報', tsunamiLabel(info.domesticTsunami)),
        if (byPref.isNotEmpty) ...[
          const SizedBox(height: 12),
          Text('各地の震度', style: tt.labelLarge),
          const SizedBox(height: 6),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final e
                  in byPref.entries.toList()
                    ..sort((a, b) => b.value.compareTo(a.value)))
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: scaleColor(e.value).withValues(alpha: 0.15),
                    border: Border.all(color: scaleColor(e.value)),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Text(
                    '${e.key} 震度${scaleLabel(e.value)}',
                    style: TextStyle(
                      color: scaleColor(e.value),
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
            ],
          ),
        ],
      ],
    );
  }
}
