/// タイムゾーンと世界時計の設定
library;

import 'package:material_ui/material_ui.dart';

import '../../core/time_zones.dart';
import 'app_settings.dart';
import 'preferences_pages.dart';
import 'settings_scope.dart';

/// タイムゾーンを1つ選ぶ画面（検索できる）
class TimeZonePickerPage extends StatefulWidget {
  const TimeZonePickerPage({super.key, required this.title, this.current});

  final String title;
  final String? current;

  @override
  State<TimeZonePickerPage> createState() => _TimeZonePickerPageState();
}

class _TimeZonePickerPageState extends State<TimeZonePickerPage> {
  final _search = TextEditingController();
  late final _all = allTimeZoneNames();
  final _now = DateTime.now();

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final q = _search.text.trim().toLowerCase();
    final hits = [
      // よく使うものを先に
      for (final n in commonTimeZoneNames)
        if (_all.contains(n) && n.toLowerCase().contains(q)) n,
      for (final n in _all)
        if (!commonTimeZoneNames.contains(n) && n.toLowerCase().contains(q)) n,
    ];

    return Scaffold(
      appBar: AppBar(title: Text(widget.title)),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: TextField(
              controller: _search,
              onChanged: (_) => setState(() {}),
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.search),
                hintText: '地名で探す（例：Vienna、Tokyo）',
              ),
            ),
          ),
          Expanded(
            child: ListView.builder(
              itemCount: hits.length,
              itemBuilder: (context, i) {
                final name = hits[i];
                return ListTile(
                  title: Text(name),
                  subtitle: Text(
                    '${offsetText(zoneOffsetMinutes(name, _now))}・'
                    'いま ${formatMinutesWith(nowMinutesIn(name), use24Hour: true)}',
                  ),
                  trailing: name == widget.current
                      ? const Icon(Icons.check)
                      : null,
                  onTap: () => Navigator.pop(context, name),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

/// タイムゾーンと世界時計
class TimeZoneSettingsPage extends StatelessWidget {
  const TimeZoneSettingsPage({super.key});

  Future<String?> _pick(BuildContext context, String title, String? current) =>
      Navigator.of(context).push<String>(
        MaterialPageRoute(
          builder: (_) => TimeZonePickerPage(title: title, current: current),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final s = SettingsScope.of(context);
    final now = DateTime.now();
    final second = s.secondTimeZone;
    final diff = second.isEmpty
        ? 0
        : zoneDifferenceMinutes(s.timeZone, second, now);

    return Scaffold(
      appBar: AppBar(title: const Text('タイムゾーンと世界時計')),
      body: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: ListView(
            padding: const EdgeInsets.only(bottom: 24),
            children: [
              ListTile(
                leading: const Icon(Icons.public),
                title: const Text('表示するタイムゾーン'),
                subtitle: Text(timeZoneLabel(s.timeZone, now)),
                onTap: () async {
                  final v = await _pick(context, '表示するタイムゾーン', s.timeZone);
                  if (v != null && context.mounted) {
                    await saveSettings(context, s.copyWith(timeZone: v));
                  }
                },
              ),
              const Divider(height: 24),
              SwitchListTile(
                secondary: const Icon(Icons.schedule_outlined),
                title: const Text('世界時計を表示する'),
                subtitle: const Text('週・日ビューの目盛りに、もう1つの時刻を出します'),
                value: s.showWorldClock,
                onChanged: (v) =>
                    saveSettings(context, s.copyWith(showWorldClock: v)),
              ),
              ListTile(
                enabled: s.showWorldClock,
                leading: const Icon(Icons.travel_explore),
                title: const Text('2つめのタイムゾーン'),
                subtitle: Text(
                  second.isEmpty ? '選んでいません' : timeZoneLabel(second, now),
                ),
                onTap: () async {
                  final v = await _pick(context, '2つめのタイムゾーン', second);
                  if (v != null && context.mounted) {
                    await saveSettings(context, s.copyWith(secondTimeZone: v));
                  }
                },
              ),
              if (s.showWorldClock && second.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                  child: Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'いまの時刻',
                            style: Theme.of(context).textTheme.titleSmall,
                          ),
                          const SizedBox(height: 8),
                          _ClockRow(name: s.timeZone, settings: s),
                          const SizedBox(height: 4),
                          _ClockRow(name: second, settings: s),
                          const SizedBox(height: 8),
                          Text(
                            diff == 0 ? '時差はありません' : '時差 ${offsetText(diff)}',
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.outline,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                child: Text(
                  '表示するタイムゾーンは、通知の時刻にも使われます。',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.outline,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ClockRow extends StatelessWidget {
  const _ClockRow({required this.name, required this.settings});

  final String name;
  final AppSettings settings;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Expanded(child: Text(name)),
      Text(
        settings.time(nowMinutesIn(name)),
        style: const TextStyle(fontWeight: FontWeight.bold),
      ),
    ],
  );
}
