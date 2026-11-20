/// 空き時間さがし
///
/// 予定が入っていない時間（授業中や既存の予定をのぞいた、すき間）を
/// 日ごとに一覧で出す。
library;

import 'package:material_ui/material_ui.dart';

import '../events/calendar_event.dart';
import '../events/event_category_repository.dart';
import '../events/event_edit_page.dart';
import '../events/event_repository.dart';
import '../settings/settings_scope.dart';
import '../timetable/day_timetable_resolver.dart';
import 'free_time.dart';

void openFreeTime(
  BuildContext context, {
  required EventRepository repository,
  required EventCategoryRepository categoryRepository,
  required DayTimetableResolver resolver,
  required List<CalendarEvent> events,
  DateTime? day,
}) {
  Navigator.of(context, rootNavigator: true).push(
    MaterialPageRoute<void>(
      builder: (_) => FreeTimePage(
        repository: repository,
        categoryRepository: categoryRepository,
        resolver: resolver,
        events: events,
        initialDay: day,
      ),
    ),
  );
}

const _minMinutesChoices = [15, 30, 60, 90];

class FreeTimePage extends StatefulWidget {
  const FreeTimePage({
    super.key,
    required this.repository,
    required this.categoryRepository,
    required this.resolver,
    required this.events,
    this.initialDay,
  });

  final EventRepository repository;
  final EventCategoryRepository categoryRepository;
  final DayTimetableResolver resolver;
  final List<CalendarEvent> events;
  final DateTime? initialDay;

  @override
  State<FreeTimePage> createState() => _FreeTimePageState();
}

class _FreeTimePageState extends State<FreeTimePage> {
  late DateTime _day;
  int _minMinutes = 30;

  @override
  void initState() {
    super.initState();
    final d = widget.initialDay ?? DateTime.now();
    _day = DateTime(d.year, d.month, d.day);
  }

  void _shiftDay(int deltaDays) {
    setState(() => _day = DateTime(_day.year, _day.month, _day.day + deltaDays));
  }

  void _addAt(FreeSlot slot) {
    Navigator.of(context, rootNavigator: true).push(
      MaterialPageRoute<void>(
        fullscreenDialog: true,
        builder: (_) => EventEditPage(
          repository: widget.repository,
          categoryRepository: widget.categoryRepository,
          initialStart: slot.start,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = SettingsScope.of(context);
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final timetable = widget.resolver.resolve(_day);
    final slots = findFreeSlots(
      day: _day,
      timetable: timetable,
      events: widget.events,
      minMinutes: _minMinutes,
    );
    final totalMinutes = slots.fold<int>(0, (sum, x) => sum + x.minutes);

    return Scaffold(
      appBar: AppBar(title: const Text('空き時間さがし')),
      body: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
            children: [
              Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.chevron_left),
                    onPressed: () => _shiftDay(-1),
                  ),
                  Expanded(
                    child: Center(
                      child: Text(
                        s.date(_day, weekday: true),
                        style: tt.titleMedium,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.chevron_right),
                    onPressed: () => _shiftDay(1),
                  ),
                ],
              ),
              Align(
                alignment: Alignment.center,
                child: TextButton(
                  onPressed: () {
                    final now = DateTime.now();
                    setState(
                      () => _day = DateTime(now.year, now.month, now.day),
                    );
                  },
                  child: const Text('今日にもどる'),
                ),
              ),
              const SizedBox(height: 8),
              Text('これ以上の長さの空きだけ表示', style: tt.labelLarge),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: [
                  for (final m in _minMinutesChoices)
                    ChoiceChip(
                      label: Text(m < 60 ? '$m分' : '${m ~/ 60}時間'),
                      selected: _minMinutes == m,
                      onSelected: (_) => setState(() => _minMinutes = m),
                    ),
                ],
              ),
              const SizedBox(height: 16),
              if (slots.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 24),
                  child: Center(
                    child: Text(
                      'この日は、これ以上の空き時間が見つかりませんでした',
                      style: TextStyle(color: cs.outline),
                    ),
                  ),
                )
              else ...[
                Text(
                  '空き時間の合計：'
                  '${totalMinutes ~/ 60 > 0 ? '${totalMinutes ~/ 60}時間' : ''}'
                  '${totalMinutes % 60 > 0 ? '${totalMinutes % 60}分' : ''}'
                  '（${slots.length}件）',
                  style: tt.bodyMedium?.copyWith(color: cs.outline),
                ),
                const SizedBox(height: 8),
                for (final slot in slots)
                  Card(
                    child: ListTile(
                      leading: const Icon(Icons.event_available_outlined),
                      title: Text(
                        '${s.timeOf(slot.start)}〜${s.timeOf(slot.end)}',
                      ),
                      subtitle: Text(slot.lengthLabel),
                      trailing: TextButton.icon(
                        icon: const Icon(Icons.add, size: 18),
                        label: const Text('予定を追加'),
                        onPressed: () => _addAt(slot),
                      ),
                    ),
                  ),
              ],
              const SizedBox(height: 8),
              Text(
                '授業（空きコマ・カットされたコマは除く）と、すでにある予定を'
                'のぞいた「7:00〜23:00」の中のすき間です。',
                style: tt.bodySmall?.copyWith(color: cs.outline),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
