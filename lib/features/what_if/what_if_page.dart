/// 「もしも予定がこうなったら？」シミュレーター
///
/// 今日・明日のどれか1つの予定の時間が延びる／縮んだら、その日の後の予定が
/// どれだけずれるかをプレビューするだけの画面。実際の予定は変えない。
/// 本当にずらしたいときは既存の「リカバリーモード」を使う。
library;

import 'package:firebase_auth/firebase_auth.dart';
import 'package:material_ui/material_ui.dart';

import '../events/calendar_event.dart';
import '../events/event_repository.dart';
import 'what_if.dart';

class WhatIfPage extends StatefulWidget {
  const WhatIfPage({super.key});

  @override
  State<WhatIfPage> createState() => _WhatIfPageState();
}

class _WhatIfPageState extends State<WhatIfPage> {
  late final String _uid = FirebaseAuth.instance.currentUser!.uid;
  late final _events = EventRepository(uid: _uid).watchAll();

  DateTime _day = DateTime.now();
  String? _selectedId;
  int _delayMinutes = 30;

  bool _isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  String _time(DateTime d) =>
      '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';

  void _pickDay(DateTime d) {
    setState(() {
      _day = d;
      _selectedId = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('もしも予定シミュレーター')),
      body: StreamBuilder<List<CalendarEvent>>(
        stream: _events,
        builder: (context, snap) {
          if (!snap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final all = snap.data!;
          final today = DateTime(_day.year, _day.month, _day.day);

          final dayEvents =
              [
                for (final e in all)
                  if (!e.isAllDay &&
                      !e.isTravelEvent &&
                      e.id != null &&
                      e.occursOn(today))
                    e,
              ]..sort((a, b) => a.start.compareTo(b.start));

          CalendarEvent? selected;
          for (final e in dayEvents) {
            if (e.id == _selectedId) {
              selected = e;
              break;
            }
          }

          final shifted = selected == null
              ? const <ShiftedEvent>[]
              : simulateDelay(
                  dayEvents: dayEvents,
                  changedEventId: selected.id!,
                  newEnd: selected.end.add(Duration(minutes: _delayMinutes)),
                );

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              const Text('どの日で試しますか？'),
              const SizedBox(height: 8),
              Row(
                children: [
                  ChoiceChip(
                    label: const Text('今日'),
                    selected: _isSameDay(_day, DateTime.now()),
                    onSelected: (_) => _pickDay(DateTime.now()),
                  ),
                  const SizedBox(width: 8),
                  ChoiceChip(
                    label: const Text('明日'),
                    selected: _isSameDay(
                      _day,
                      DateTime.now().add(const Duration(days: 1)),
                    ),
                    onSelected: (_) =>
                        _pickDay(DateTime.now().add(const Duration(days: 1))),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              if (dayEvents.isEmpty)
                const Text('この日には（終日でない）予定がありません')
              else ...[
                const Text('どの予定を変えますか？'),
                const SizedBox(height: 4),
                for (final e in dayEvents)
                  RadioListTile<String>(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    value: e.id!,
                    groupValue: _selectedId,
                    onChanged: (v) => setState(() => _selectedId = v),
                    title: Text(e.title),
                    subtitle: Text('${_time(e.start)}〜${_time(e.end)}'),
                  ),
                if (selected != null) ...[
                  const SizedBox(height: 16),
                  Text('「${selected.title}」が延びる／縮むと？'),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final m in [-30, -15, 15, 30, 60, 90])
                        ChoiceChip(
                          label: Text(m > 0 ? '+$m分' : '$m分'),
                          selected: _delayMinutes == m,
                          onSelected: (_) => setState(() => _delayMinutes = m),
                        ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Text(
                    _delayMinutes > 0
                        ? 'もしも$_delayMinutes分延びたら'
                        : 'もしも${-_delayMinutes}分早く終わったら',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  if (shifted.isEmpty)
                    const Text('この変更で、後の予定への影響はありません')
                  else
                    Card(
                      child: Column(
                        children: [
                          for (final s in shifted)
                            ListTile(
                              dense: true,
                              leading: Icon(
                                s.event.id == selected.id
                                    ? Icons.edit_calendar
                                    : Icons.schedule,
                                size: 20,
                              ),
                              title: Text(s.event.title),
                              subtitle: Text(
                                '${_time(s.event.start)}〜${_time(s.event.end)}'
                                ' → ${_time(s.newStart)}〜${_time(s.newEnd)}',
                              ),
                            ),
                        ],
                      ),
                    ),
                  const SizedBox(height: 12),
                  Text(
                    'これはシミュレーションだけで、実際の予定は変わりません。'
                    '本当にずらしたいときは「リカバリーモード」を使ってください。',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.outline,
                      fontSize: 12,
                    ),
                  ),
                ],
              ],
            ],
          );
        },
      ),
    );
  }
}
