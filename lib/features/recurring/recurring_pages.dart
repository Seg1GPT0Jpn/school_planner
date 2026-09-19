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

void openRecurringList(BuildContext context) {
  Navigator.of(
    context,
    rootNavigator: true,
  ).push(MaterialPageRoute<void>(builder: (_) => const RecurringListPage()));
}

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
            Text(event.title, style: Theme.of(c).textTheme.titleLarge),
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

int _firstDay(RecurringSchedule s) =>
    s.weekdays.isEmpty ? 8 : s.weekdays.reduce((a, b) => a < b ? a : b);

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
              final w = _firstDay(a).compareTo(_firstDay(b));
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
                  leading: CircleAvatar(
                    child: Text(
                      s.weekdayText,
                      style: const TextStyle(fontSize: 11),
                    ),
                  ),
                  title: Text(
                    s.test == null ? s.title : '${s.title}（${s.test!.title}）',
                  ),
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

class RecurringEditPage extends StatefulWidget {
  const RecurringEditPage({super.key, this.schedule});

  final RecurringSchedule? schedule;

  @override
  State<RecurringEditPage> createState() => _RecurringEditPageState();
}

class _RecurringEditPageState extends State<RecurringEditPage> {
  late final RecurringTestConfig? _t0 = widget.schedule?.test;

  late final _title = TextEditingController(text: widget.schedule?.title);
  late final _location = TextEditingController(text: widget.schedule?.location);
  late final Set<int> _weekdays = {
    ...?widget.schedule?.weekdays,
    if (widget.schedule == null) DateTime.monday,
  };
  late ClockTime _start = widget.schedule?.start ?? ClockTime(19, 40);
  late ClockTime _end = widget.schedule?.end ?? ClockTime(21, 40);
  late DateTime? _from = widget.schedule?.validFrom;
  late DateTime? _until = widget.schedule?.validUntil;
  late String _categoryId =
      widget.schedule?.categoryId ?? EventCategory.otherId;
  late final _categories = EventCategoryRepository(
    uid: FirebaseAuth.instance.currentUser!.uid,
  ).watch();

  // ミニテスト
  late bool _hasTest = _t0 != null;
  late final _testTitle = TextEditingController(text: _t0?.title);
  late bool _hasRange = _t0?.hasRange ?? false;
  late DateTime _baseDate = _t0?.baseDate ?? DateTime.now();
  late final _baseStart = TextEditingController(text: '${_t0?.baseStart ?? 1}');
  late final _step = TextEditingController(text: '${_t0?.step ?? 50}');
  late bool _withReview = _t0?.withReview ?? false;

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

  RecurringTestConfig? _buildTest() {
    if (!_hasTest) return null;
    return RecurringTestConfig(
      title: _testTitle.text.trim(),
      baseDate: _hasRange ? _baseDate : null,
      baseStart: _hasRange ? int.tryParse(_baseStart.text) ?? 1 : null,
      step: int.tryParse(_step.text) ?? 50,
      withReview: _hasRange && _withReview,
    );
  }

  Future<void> _save() async {
    final s = RecurringSchedule(
      id: widget.schedule?.id,
      title: _title.text,
      weekdays: {..._weekdays},
      start: _start,
      end: _end,
      validFrom: _from,
      validUntil: _until,
      categoryId: _categoryId,
      location: _location.text,
      skippedDates: widget.schedule?.skippedDates ?? const {},
      test: _buildTest(),
    );
    final error = s.validate();
    if (error != null) return setState(() => _error = error);
    final nav = Navigator.of(context);
    await _repo().save(s);
    nav.pop();
  }

  Future<void> _delete() async {
    final nav = Navigator.of(context);
    await _repo().delete(widget.schedule!.id!);
    nav.pop();
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
            decoration: const InputDecoration(labelText: '名前（例：塾 英語、部活）'),
          ),
          const SizedBox(height: 16),
          Text('曜日（複数選べます）', style: label),
          Wrap(
            spacing: 6,
            children: [
              for (var w = 1; w <= 7; w++)
                FilterChip(
                  label: Text(weekdayLabel(w)),
                  selected: _weekdays.contains(w),
                  onSelected: (on) => setState(
                    () => on ? _weekdays.add(w) : _weekdays.remove(w),
                  ),
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

          // ---------------- 毎回のミニテスト ----------------
          const Divider(height: 32),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('毎回のミニテスト'),
            value: _hasTest,
            onChanged: (v) => setState(() => _hasTest = v),
          ),
          if (_hasTest) ...[
            TextField(
              controller: _testTitle,
              decoration: const InputDecoration(labelText: 'テストの名前（例：EEVI）'),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('範囲を自動で進める'),
              value: _hasRange,
              onChanged: (v) => setState(() => _hasRange = v),
            ),
            if (_hasRange) ...[
              Row(
                children: [
                  TextButton(
                    onPressed: () async {
                      final d = await _pickDate(_baseDate);
                      if (d != null) setState(() => _baseDate = d);
                    },
                    child: Text(formatDateJa(_baseDate)),
                  ),
                  const Text('の範囲が'),
                  const SizedBox(width: 8),
                  SizedBox(
                    width: 72,
                    child: TextField(
                      controller: _baseStart,
                      keyboardType: TextInputType.number,
                    ),
                  ),
                  const Text(' から'),
                ],
              ),
              Row(
                children: [
                  const Text('1回で進む数'),
                  const SizedBox(width: 8),
                  SizedBox(
                    width: 72,
                    child: TextField(
                      controller: _step,
                      keyboardType: TextInputType.number,
                    ),
                  ),
                ],
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('前回の範囲も出す'),
                value: _withReview,
                onChanged: (v) => setState(() => _withReview = v),
              ),
            ],
          ],

          if (skipped.isNotEmpty) ...[
            const Divider(height: 32),
            Text('休みにした日（× で戻す）', style: label),
            Wrap(
              spacing: 6,
              children: [
                for (final k in skipped)
                  InputChip(
                    label: Text(k),
                    onDeleted: () async {
                      final nav = Navigator.of(context);
                      final p = k.split('-').map(int.parse).toList();
                      await _repo().setSkipped(
                        widget.schedule!.id!,
                        DateTime(p[0], p[1], p[2]),
                        false,
                      );
                      nav.pop();
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
