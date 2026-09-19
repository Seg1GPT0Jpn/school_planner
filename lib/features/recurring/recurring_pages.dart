import 'package:firebase_auth/firebase_auth.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/date_format.dart';
import '../events/calendar_event.dart';
import '../events/event_category.dart';
import '../events/event_category_repository.dart';
import '../timetable/school_periods.dart';
import 'recurring_repository.dart';
import 'recurring_schedule.dart';

RecurringRepository _repo() =>
    RecurringRepository(uid: FirebaseAuth.instance.currentUser!.uid);

/// 定期の予定の一覧を開く
void openRecurringList(BuildContext context) {
  Navigator.of(
    context,
    rootNavigator: true,
  ).push(MaterialPageRoute<void>(builder: (_) => const RecurringListPage()));
}

/// カレンダーで定期の予定をタップしたとき
void showRecurringInstanceSheet(BuildContext context, CalendarEvent event) {
  final parsed = parseRecurringInstance(event);
  if (parsed == null) return;
  final (id, date) = parsed;

  showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    builder: (c) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(event.title, style: Theme.of(c).textTheme.headlineSmall),
            const SizedBox(height: 8),
            Text(
              '${formatDateJa(date)}  ${_hm(event.start)}〜${_hm(event.end)}',
            ),
            if (event.location != null) Text(event.location!),
            const Divider(),
            TextButton.icon(
              onPressed: () {
                Navigator.of(c).pop();
                _repo().setSkipped(id, date, true);
              },
              icon: const Icon(Icons.event_busy),
              label: const Text('この日だけ休みにする'),
            ),
            TextButton.icon(
              onPressed: () {
                Navigator.of(c).pop();
                openRecurringList(context);
              },
              icon: const Icon(Icons.list),
              label: const Text('定期の予定の一覧を開く'),
            ),
          ],
        ),
      ),
    ),
  );
}

String _hm(DateTime d) => '${d.hour}:${d.minute.toString().padLeft(2, '0')}';

String _dateText(DateTime? d, String empty) =>
    d == null ? empty : formatDateJa(d);

/// 一覧
class RecurringListPage extends StatefulWidget {
  const RecurringListPage({super.key});

  @override
  State<RecurringListPage> createState() => _RecurringListPageState();
}

class _RecurringListPageState extends State<RecurringListPage> {
  late final Stream<List<RecurringSchedule>> _stream = _repo().watch();

  void _edit([RecurringSchedule? s]) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => RecurringEditPage(schedule: s)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('定期の予定')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _edit,
        icon: const Icon(Icons.add),
        label: const Text('追加'),
      ),
      body: StreamBuilder<List<RecurringSchedule>>(
        stream: _stream,
        builder: (context, snapshot) {
          final list = [...?snapshot.data]
            ..sort((a, b) {
              final w = a.weekday.compareTo(b.weekday);
              return w != 0
                  ? w
                  : a.start.totalMinutes.compareTo(b.start.totalMinutes);
            });
          if (list.isEmpty) {
            return const Center(child: Text('右下の「追加」から登録してください'));
          }
          return ListView(
            padding: const EdgeInsets.only(bottom: 88),
            children: [
              for (final s in list)
                ListTile(
                  leading: CircleAvatar(child: Text(weekdayLabel(s.weekday))),
                  title: Text(s.title),
                  subtitle: Text(
                    '${s.start}〜${s.end}　'
                    '${_dateText(s.validFrom, '')}'
                    '${s.validFrom == null && s.validUntil == null ? '' : '〜'}'
                    '${_dateText(s.validUntil, '')}',
                  ),
                  onTap: () => _edit(s),
                ),
            ],
          );
        },
      ),
    );
  }
}

/// 追加・編集
class RecurringEditPage extends StatefulWidget {
  const RecurringEditPage({super.key, this.schedule});

  final RecurringSchedule? schedule;

  @override
  State<RecurringEditPage> createState() => _RecurringEditPageState();
}

class _RecurringEditPageState extends State<RecurringEditPage> {
  late final _title = TextEditingController(text: widget.schedule?.title);
  late final _location = TextEditingController(text: widget.schedule?.location);
  late int _weekday = widget.schedule?.weekday ?? DateTime.monday;
  late ClockTime _start = widget.schedule?.start ?? ClockTime(19, 40);
  late ClockTime _end = widget.schedule?.end ?? ClockTime(21, 40);
  late DateTime? _from = widget.schedule?.validFrom;
  late DateTime? _until = widget.schedule?.validUntil;
  late String _categoryId =
      widget.schedule?.categoryId ?? EventCategory.otherId;
  late final _categories = EventCategoryRepository(
    uid: FirebaseAuth.instance.currentUser!.uid,
  ).watch();
  String? _error;

  Future<ClockTime?> _pickTime(ClockTime t) async {
    final p = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(
        hour: t.totalMinutes ~/ 60,
        minute: t.totalMinutes % 60,
      ),
    );
    return p == null ? null : ClockTime(p.hour, p.minute);
  }

  Future<DateTime?> _pickDate(DateTime? d) => showDatePicker(
    context: context,
    initialDate: d ?? DateTime.now(),
    firstDate: DateTime(2020),
    lastDate: DateTime(2035, 12, 31),
  );

  Future<void> _save() async {
    final s = RecurringSchedule(
      id: widget.schedule?.id,
      title: _title.text,
      weekday: _weekday,
      start: _start,
      end: _end,
      validFrom: _from,
      validUntil: _until,
      categoryId: _categoryId,
      location: _location.text,
      skippedDates: widget.schedule?.skippedDates ?? const {},
    );
    final error = s.validate();
    if (error != null) return setState(() => _error = error);
    await _repo().save(s);
    if (mounted) Navigator.of(context).pop();
  }

  Future<void> _delete() async {
    await _repo().delete(widget.schedule!.id!);
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final skipped = [...?widget.schedule?.skippedDates]..sort();
    final label = Theme.of(context).textTheme.labelLarge;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.schedule == null ? '定期の予定を追加' : '定期の予定を編集'),
        actions: [
          if (widget.schedule != null)
            IconButton(
              icon: const Icon(Icons.delete_outline),
              tooltip: '削除',
              onPressed: _delete,
            ),
          TextButton(onPressed: _save, child: const Text('保存')),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(
            controller: _title,
            decoration: const InputDecoration(labelText: '名前（例：塾 英語）'),
          ),
          const SizedBox(height: 16),
          Text('曜日', style: label),
          Wrap(
            spacing: 6,
            children: [
              for (var w = 1; w <= 7; w++)
                ChoiceChip(
                  label: Text(weekdayLabel(w)),
                  selected: _weekday == w,
                  onSelected: (_) => setState(() => _weekday = w),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Text('時刻', style: label),
              const Spacer(),
              TextButton(
                onPressed: () async {
                  final t = await _pickTime(_start);
                  if (t != null) setState(() => _start = t);
                },
                child: Text('$_start'),
              ),
              const Text('〜'),
              TextButton(
                onPressed: () async {
                  final t = await _pickTime(_end);
                  if (t != null) setState(() => _end = t);
                },
                child: Text('$_end'),
              ),
            ],
          ),
          Row(
            children: [
              Text('期間', style: label),
              const Spacer(),
              TextButton(
                onPressed: () async {
                  final d = await _pickDate(_from);
                  if (d != null) setState(() => _from = d);
                },
                child: Text(_dateText(_from, '最初から')),
              ),
              const Text('〜'),
              TextButton(
                onPressed: () async {
                  final d = await _pickDate(_until);
                  if (d != null) setState(() => _until = d);
                },
                child: Text(_dateText(_until, 'ずっと')),
              ),
              IconButton(
                icon: const Icon(Icons.clear),
                tooltip: '期間をなしにする',
                onPressed: () => setState(() => _from = _until = null),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text('カテゴリ', style: label),
          StreamBuilder<List<EventCategory>>(
            stream: _categories,
            builder: (context, snap) => Wrap(
              spacing: 6,
              children: [
                for (final c in snap.data ?? const <EventCategory>[])
                  ChoiceChip(
                    avatar: CircleAvatar(
                      radius: 6,
                      backgroundColor: Color(c.colorValue),
                    ),
                    label: Text(c.name),
                    selected: _categoryId == c.id,
                    onSelected: (_) => setState(() => _categoryId = c.id),
                  ),
              ],
            ),
          ),
          TextField(
            controller: _location,
            decoration: const InputDecoration(labelText: '場所'),
          ),
          if (skipped.isNotEmpty) ...[
            const SizedBox(height: 16),
            Text('休みにした日（× で戻す）', style: label),
            Wrap(
              spacing: 6,
              children: [
                for (final k in skipped)
                  InputChip(
                    label: Text(k),
                    onDeleted: () async {
                      final p = k.split('-').map(int.parse).toList();
                      await _repo().setSkipped(
                        widget.schedule!.id!,
                        DateTime(p[0], p[1], p[2]),
                        false,
                      );
                      if (mounted) Navigator.of(context).pop();
                    },
                  ),
              ],
            ),
          ],
          if (_error != null) ...[
            const SizedBox(height: 16),
            Text(
              _error!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ],
        ],
      ),
    );
  }
}
