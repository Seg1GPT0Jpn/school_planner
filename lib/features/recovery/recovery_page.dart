/// リカバリーモード
///
/// 急に予定が変わったとき（時間が延びた・遅れたなど）、
/// その日の残りの予定をまとめて同じ分数だけずらして組みなおす画面。
library;

import 'package:material_ui/material_ui.dart';

import '../events/calendar_event.dart';
import '../events/event_repository.dart';
import '../settings/settings_scope.dart';

void openRecoveryMode(
  BuildContext context, {
  required EventRepository repository,
  required List<CalendarEvent> events,
  required DateTime day,
}) {
  Navigator.of(context, rootNavigator: true).push(
    MaterialPageRoute<void>(
      builder: (_) =>
          RecoveryModePage(repository: repository, events: events, day: day),
    ),
  );
}

DateTime _dayOnly(DateTime d) => DateTime(d.year, d.month, d.day);

class RecoveryModePage extends StatefulWidget {
  const RecoveryModePage({
    super.key,
    required this.repository,
    required this.events,
    required this.day,
  });

  final EventRepository repository;
  final List<CalendarEvent> events;
  final DateTime day;

  @override
  State<RecoveryModePage> createState() => _RecoveryModePageState();
}

class _RecoveryModePageState extends State<RecoveryModePage> {
  late DateTime _after;
  int _shiftMinutes = 0;
  final Set<String> _excluded = {};
  bool _applying = false;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _after = _dayOnly(widget.day) == _dayOnly(now)
        ? now
        : DateTime(widget.day.year, widget.day.month, widget.day.day);
  }

  /// その日の、時刻つき（終日でない）予定。開始が早い順
  List<CalendarEvent> get _dayEvents {
    final list = [
      for (final e in widget.events)
        if (!e.isAllDay &&
            !e.isTravelEvent &&
            _dayOnly(e.start) == _dayOnly(widget.day))
          e,
    ];
    list.sort((a, b) => a.start.compareTo(b.start));
    return list;
  }

  /// 組みなおしの対象（基準の時刻より後に始まる予定）
  List<CalendarEvent> get _targets =>
      [for (final e in _dayEvents) if (!e.start.isBefore(_after)) e];

  /// もとの予定に自動でついている「移動」の予定（あれば）
  CalendarEvent? _travelFor(CalendarEvent e) {
    for (final x in widget.events) {
      if (x.travelForEventId == e.id) return x;
    }
    return null;
  }

  Future<void> _pickAfter() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_after),
    );
    if (picked == null) return;
    setState(() {
      _after = DateTime(
        widget.day.year,
        widget.day.month,
        widget.day.day,
        picked.hour,
        picked.minute,
      );
    });
  }

  Future<void> _apply() async {
    final targets = [
      for (final e in _targets)
        if (!_excluded.contains(e.id)) e,
    ];
    if (targets.isEmpty || _shiftMinutes == 0) return;
    setState(() => _applying = true);
    final shift = Duration(minutes: _shiftMinutes);
    var count = 0;
    try {
      for (final e in targets) {
        await widget.repository.save(_shifted(e, shift));
        count++;
        final travel = _travelFor(e);
        if (travel != null) {
          await widget.repository.save(_shifted(travel, shift));
        }
      }
      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('$count件の予定を組みなおしました')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('うまくいきませんでした：$e')));
      }
    } finally {
      if (mounted) setState(() => _applying = false);
    }
  }

  CalendarEvent _shifted(CalendarEvent e, Duration shift) => CalendarEvent(
    id: e.id,
    title: e.title,
    start: e.start.add(shift),
    end: e.end.add(shift),
    isAllDay: e.isAllDay,
    location: e.location,
    memo: e.memo,
    categoryId: e.categoryId,
    belongings: e.belongings,
    travelForEventId: e.travelForEventId,
  );

  @override
  Widget build(BuildContext context) {
    final s = SettingsScope.of(context);
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final targets = _targets;

    const shiftChoices = [-60, -30, -15, -5, 5, 15, 30, 60, 90];

    return Scaffold(
      appBar: AppBar(title: const Text('リカバリーモード')),
      body: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: Column(
            children: [
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                  children: [
                    Text(
                      '急に予定が変わったとき、${s.date(widget.day, weekday: true)}の'
                      '残りの予定をまとめて同じ分数だけずらします。',
                      style: tt.bodyMedium,
                    ),
                    const SizedBox(height: 16),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.schedule),
                      title: const Text('この時刻より後の予定が対象'),
                      subtitle: Text(s.timeOf(_after)),
                      trailing: const Icon(Icons.edit_outlined, size: 18),
                      onTap: _pickAfter,
                    ),
                    const SizedBox(height: 8),
                    Text('何分ずらす？', style: tt.labelLarge),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final m in shiftChoices)
                          ChoiceChip(
                            label: Text(m > 0 ? '+$m分' : '$m分'),
                            selected: _shiftMinutes == m,
                            onSelected: (_) =>
                                setState(() => _shiftMinutes = m),
                          ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        IconButton(
                          icon: const Icon(Icons.remove_circle_outline),
                          onPressed: () =>
                              setState(() => _shiftMinutes -= 5),
                        ),
                        Text(
                          _shiftMinutes == 0
                              ? 'ずらさない'
                              : (_shiftMinutes > 0
                                    ? '+$_shiftMinutes分'
                                    : '$_shiftMinutes分'),
                          style: tt.titleMedium,
                        ),
                        IconButton(
                          icon: const Icon(Icons.add_circle_outline),
                          onPressed: () =>
                              setState(() => _shiftMinutes += 5),
                        ),
                      ],
                    ),
                    const Divider(height: 24),
                    Text(
                      '対象の予定（${targets.length}件）',
                      style: tt.labelLarge,
                    ),
                    const SizedBox(height: 4),
                    if (targets.isEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        child: Text(
                          'この時刻より後に、組みなおせる予定がありません',
                          style: TextStyle(color: cs.outline),
                        ),
                      )
                    else
                      for (final e in targets)
                        CheckboxListTile(
                          contentPadding: EdgeInsets.zero,
                          value: !_excluded.contains(e.id),
                          onChanged: (v) => setState(() {
                            if (v == false) {
                              _excluded.add(e.id!);
                            } else {
                              _excluded.remove(e.id);
                            }
                          }),
                          title: Text(e.title),
                          subtitle: Text(
                            _shiftMinutes == 0
                                ? '${s.timeOf(e.start)}〜${s.timeOf(e.end)}'
                                : '${s.timeOf(e.start)}〜${s.timeOf(e.end)}　→　'
                                      '${s.timeOf(e.start.add(Duration(minutes: _shiftMinutes)))}〜'
                                      '${s.timeOf(e.end.add(Duration(minutes: _shiftMinutes)))}',
                            style: TextStyle(
                              color: _shiftMinutes == 0
                                  ? cs.outline
                                  : cs.primary,
                              fontWeight: _shiftMinutes == 0
                                  ? null
                                  : FontWeight.bold,
                            ),
                          ),
                        ),
                    const SizedBox(height: 8),
                    Text(
                      '移動の予定が自動で付いているときは、いっしょにずらします。'
                      '組みなおしたあと、内容もあわせて確認してください。',
                      style: tt.bodySmall?.copyWith(color: cs.outline),
                    ),
                  ],
                ),
              ),
              SafeArea(
                minimum: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                child: FilledButton.icon(
                  onPressed:
                      (_applying ||
                          _shiftMinutes == 0 ||
                          targets.length == _excluded.length)
                      ? null
                      : _apply,
                  icon: _applying
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.restart_alt),
                  label: const Text('組みなおす'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
