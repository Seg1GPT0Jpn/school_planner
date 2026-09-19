import 'package:firebase_auth/firebase_auth.dart';
import 'package:material_ui/material_ui.dart';

import '../recurring/recurring_repository.dart';
import '../recurring/recurring_schedule.dart';
import '../timetable/day_timetable_resolver.dart';
import '../timetable/timetable_repository.dart';
import 'belongings.dart';
import 'belongings_repository.dart';

BelongingsRepository _repo() =>
    BelongingsRepository(uid: FirebaseAuth.instance.currentUser!.uid);

/// 持ち物を1つ入力するダイアログ
Future<String?> _askItem(BuildContext context, String title) {
  final c = TextEditingController();
  return showDialog<String>(
    context: context,
    builder: (d) => AlertDialog(
      title: Text(title),
      content: TextField(
        controller: c,
        autofocus: true,
        decoration: const InputDecoration(hintText: '例：体操服'),
        onSubmitted: (v) => Navigator.of(d).pop(v.trim()),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(d).pop(),
          child: const Text('キャンセル'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(d).pop(c.text.trim()),
          child: const Text('追加'),
        ),
      ],
    ),
  );
}

/// 見出し＋持ち物のチップ（× で削除、＋で追加）
class _ItemRow extends StatelessWidget {
  const _ItemRow({
    required this.title,
    required this.items,
    required this.onChanged,
  });

  final String title;
  final List<String> items;
  final ValueChanged<List<String>> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: Theme.of(context).textTheme.labelLarge),
          const SizedBox(height: 4),
          Wrap(
            spacing: 6,
            runSpacing: 4,
            children: [
              for (final x in items)
                InputChip(
                  label: Text(x),
                  onDeleted: () => onChanged([...items]..remove(x)),
                ),
              ActionChip(
                avatar: const Icon(Icons.add, size: 16),
                label: const Text('追加'),
                onPressed: () async {
                  final v = await _askItem(context, '$title の持ち物');
                  if (v != null && v.isNotEmpty && !items.contains(v)) {
                    onChanged([...items, v]);
                  }
                },
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// 持ち物の設定
class BelongingsSettingsPage extends StatefulWidget {
  const BelongingsSettingsPage({super.key});

  @override
  State<BelongingsSettingsPage> createState() => _BelongingsSettingsPageState();
}

class _BelongingsSettingsPageState extends State<BelongingsSettingsPage> {
  late final String _uid = FirebaseAuth.instance.currentUser!.uid;
  late final _timetable = TimetableRepository(uid: _uid).watch();
  late final _recurring = RecurringRepository(uid: _uid).watch();
  late final _settings = _repo().watchSettings();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('持ち物')),
      body: StreamBuilder<TimetableData>(
        stream: _timetable,
        builder: (context, ts) => StreamBuilder<List<RecurringSchedule>>(
          stream: _recurring,
          builder: (context, rs) => StreamBuilder<BelongingSettings>(
            stream: _settings,
            builder: (context, ss) {
              if (!ts.hasData || !ss.hasData) {
                return const Center(child: CircularProgressIndicator());
              }
              final s = ss.data!;
              void save(BelongingSettings n) => _repo().saveSettings(n);

              // 今の時間割にある科目（＋持ち物が登録されている科目）
              final subjects = <String>[
                for (final x in ts.data!.slotsForDate(DateTime.now()))
                  x.subject,
                ...s.bySubject.keys,
              ].toSet().toList()..sort();

              Widget header(String t) => Padding(
                padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
                child: Text(t, style: Theme.of(context).textTheme.titleSmall),
              );

              return ListView(
                padding: const EdgeInsets.only(bottom: 32),
                children: [
                  header('毎日（学校がある日）'),
                  _ItemRow(
                    title: '毎日',
                    items: s.daily,
                    onChanged: (v) => save(s.copyWith(daily: v)),
                  ),
                  header('科目ごと'),
                  for (final name in subjects)
                    _ItemRow(
                      title: name,
                      items: s.bySubject[name] ?? const [],
                      onChanged: (v) => save(
                        s.copyWith(bySubject: {...s.bySubject, name: v}),
                      ),
                    ),
                  header('定期の予定ごと'),
                  for (final r in rs.data ?? const <RecurringSchedule>[])
                    if (r.id != null)
                      _ItemRow(
                        title: '${r.title}（${r.weekdayText}）',
                        items: s.byRecurring[r.id] ?? const [],
                        onChanged: (v) => save(
                          s.copyWith(byRecurring: {...s.byRecurring, r.id!: v}),
                        ),
                      ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

/// ホームの「明日の持ち物」
class TomorrowBelongingsCard extends StatefulWidget {
  const TomorrowBelongingsCard({
    super.key,
    required this.data,
    required this.recurring,
  });

  final TimetableData data;
  final List<RecurringSchedule> recurring;

  @override
  State<TomorrowBelongingsCard> createState() => _TomorrowBelongingsCardState();
}

class _TomorrowBelongingsCardState extends State<TomorrowBelongingsCard> {
  late final _settings = _repo().watchSettings();

  /// 明日（明日が休みなら次の登校日。7日先まで）
  DateTime get _target {
    final now = DateTime.now();
    for (var i = 1; i <= 7; i++) {
      final d = DateTime(now.year, now.month, now.day + i);
      if (widget.data.resolver.resolve(d).status == DayStatus.school) return d;
    }
    return DateTime(now.year, now.month, now.day + 1);
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final target = _target;
    final isTomorrow =
        target.difference(DateTime.now()).inHours < 48 &&
        target.day == DateTime.now().add(const Duration(days: 1)).day;

    return StreamBuilder<BelongingSettings>(
      stream: _settings,
      builder: (context, ss) {
        final items = belongingsFor(
          day: widget.data.resolver.resolve(target),
          recurring: widget.recurring,
          settings: ss.data ?? const BelongingSettings(),
        );
        return StreamBuilder<Set<String>>(
          stream: _repo().watchChecked(target),
          builder: (context, cs2) {
            final checked = cs2.data ?? const <String>{};
            final done = items.where(checked.contains).length;
            return Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            '${isTomorrow ? '明日' : '次の登校日'}の持ち物'
                            '（${target.month}/${target.day}）',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                        ),
                        if (items.isNotEmpty) Text('$done/${items.length}'),
                      ],
                    ),
                    if (items.isEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text(
                          '設定 ⚙ →「持ち物」から登録できます',
                          style: TextStyle(color: cs.outline),
                        ),
                      )
                    else
                      for (final x in items)
                        CheckboxListTile(
                          dense: true,
                          contentPadding: EdgeInsets.zero,
                          controlAffinity: ListTileControlAffinity.leading,
                          value: checked.contains(x),
                          title: Text(x),
                          onChanged: (v) =>
                              _repo().setChecked(target, x, v ?? false),
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
