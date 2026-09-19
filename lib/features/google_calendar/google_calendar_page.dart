import 'package:firebase_auth/firebase_auth.dart';
import 'package:material_ui/material_ui.dart';

import 'google_calendar_service.dart';
import 'google_calendar_settings.dart';

class GoogleCalendarPage extends StatefulWidget {
  const GoogleCalendarPage({super.key});

  @override
  State<GoogleCalendarPage> createState() => _GoogleCalendarPageState();
}

class _GoogleCalendarPageState extends State<GoogleCalendarPage> {
  final _service = GoogleCalendarService.instance;
  late final _repo = GoogleCalendarSettingsRepository(
    uid: FirebaseAuth.instance.currentUser!.uid,
  );
  late final _settings = _repo.watch();

  List<GoogleCalendarInfo>? _calendars;
  bool _busy = false;
  String? _error;

  Future<void> _run(Future<void> Function() task) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await task();
    } catch (e) {
      setState(() => _error = '$e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _connect() => _run(() async {
    await _service.connect();
    final list = await _service.listCalendars();
    setState(() => _calendars = list);
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Google カレンダー')),
      body: StreamBuilder<GoogleCalendarSettings>(
        stream: _settings,
        builder: (context, snap) {
          final s = snap.data ?? const GoogleCalendarSettings();
          final list = _calendars;

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text(
                'Google カレンダーの予定を「つづり」に表示し、つづりの予定を Google の「つづり」カレンダーに書き込みます。'
                '許可は1時間ごとに切れるので、切れたら「接続」を押し直してください。',
                style: TextStyle(color: cs.outline),
              ),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: _busy ? null : _connect,
                icon: const Icon(Icons.link),
                label: Text(
                  _service.isConnected ? 'カレンダーの一覧を更新' : 'Google に接続',
                ),
              ),
              if (_busy)
                const Padding(
                  padding: EdgeInsets.all(16),
                  child: Center(child: CircularProgressIndicator()),
                ),
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Text(_error!, style: TextStyle(color: cs.error)),
                ),

              if (list != null) ...[
                const Divider(height: 32),
                Text(
                  '読み込むカレンダー',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                for (final c in list)
                  if (c.id != s.tsuzuriId)
                    CheckboxListTile(
                      contentPadding: EdgeInsets.zero,
                      value: s.readIds.contains(c.id),
                      title: Text(c.name),
                      secondary: CircleAvatar(
                        radius: 8,
                        backgroundColor: _hex(c.color) ?? cs.primary,
                      ),
                      onChanged: (v) async {
                        final messenger = ScaffoldMessenger.of(context);
                        try {
                          await _repo.setReadIds(
                            v == true
                                ? [...s.readIds, c.id]
                                : ([...s.readIds]..remove(c.id)),
                          );
                        } catch (e) {
                          messenger.showSnackBar(
                            SnackBar(content: Text('保存できませんでした：$e')),
                          );
                        }
                      },
                    ),
                const Divider(height: 32),
                Text('書き込み先', style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 8),
                if (s.tsuzuriId != null && list.any((c) => c.id == s.tsuzuriId))
                  const ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(Icons.check_circle_outline),
                    title: Text('「つづり」カレンダー：作成済み'),
                  )
                else
                  OutlinedButton.icon(
                    onPressed: _busy
                        ? null
                        : () => _run(() async {
                            final id = await _service.createTsuzuriCalendar();
                            await _repo.setTsuzuriId(id);
                            final updated = await _service.listCalendars();
                            setState(() => _calendars = updated);
                          }),
                    icon: const Icon(Icons.add),
                    label: const Text('Google に「つづり」カレンダーを作る'),
                  ),
              ],
            ],
          );
        },
      ),
    );
  }

  static Color? _hex(String? s) {
    if (s == null || !s.startsWith('#') || s.length != 7) return null;
    return Color(int.parse('FF${s.substring(1)}', radix: 16));
  }
}
