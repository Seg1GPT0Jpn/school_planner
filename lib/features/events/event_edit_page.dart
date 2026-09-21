import 'dart:async';

import 'package:material_ui/material_ui.dart';

import '../../core/maps.dart';
import '../growth_log/growth_log_entry_page.dart';
import '../growth_log/growth_log_repository.dart';
import '../review/school_event_page.dart';
import '../settings/app_settings.dart';
import '../settings/settings_scope.dart';
import '../timetable/school_periods.dart';
import '../travel/geocoder.dart';
import '../travel/travel.dart';
import '../travel/travel_card.dart';
import 'calendar_event.dart';
import 'category_manage_page.dart';
import 'event_category.dart';
import 'event_category_repository.dart';
import 'event_repository.dart';

/// 予定の追加・編集画面
class EventEditPage extends StatefulWidget {
  const EventEditPage({
    super.key,
    required this.repository,
    required this.categoryRepository,
    this.event,
    this.initialStart,
    this.initialAllDay = false,
  });

  final EventRepository repository;
  final EventCategoryRepository categoryRepository;

  /// 編集する予定（新しく追加するときは null）
  final CalendarEvent? event;

  /// 新しく追加するときの開始日時
  final DateTime? initialStart;

  /// 新しく追加するときに、最初から終日にするか
  final bool initialAllDay;

  @override
  State<EventEditPage> createState() => _EventEditPageState();
}

class _EventEditPageState extends State<EventEditPage> {
  late final TextEditingController _titleController;
  late final TextEditingController _locationController;
  late final TextEditingController _memoController;
  late final TextEditingController _belongingInputController;
  late final Stream<List<EventCategory>> _categoryStream;

  late DateTime _start;
  late DateTime _end;
  late bool _isAllDay;
  late String _categoryId;
  late List<String> _belongings;
  String? _mood;
  late final GrowthLogRepository _growthLogRepository;
  StreamSubscription<List<EventCategory>>? _categorySub;
  List<EventCategory> _categories = const [];

  bool _isSaving = false;
  String? _errorMessage;

  bool get _isEditing => widget.event != null;

  /// いま選んでいるカテゴリで成長ログを使えるか
  bool get _growthLogAvailable {
    for (final c in _categories) {
      if (c.id == _categoryId) return c.growthLogEnabled;
    }
    return false;
  }

  @override
  void initState() {
    super.initState();
    final e = widget.event;
    _titleController = TextEditingController(text: e?.title ?? '');
    _locationController = TextEditingController(text: e?.location ?? '');
    _memoController = TextEditingController(text: e?.memo ?? '');
    _belongingInputController = TextEditingController();
    _isAllDay = e?.isAllDay ?? widget.initialAllDay;
    _categoryId = e?.categoryId ?? EventCategory.otherId;
    _belongings = List<String>.from(e?.belongings ?? const []);
    _mood = e?.mood;
    _categoryStream = widget.categoryRepository.watch();
    _growthLogRepository = GrowthLogRepository(
      uid: widget.repository.uid,
    );
    _categorySub = _categoryStream.listen((v) {
      if (mounted) setState(() => _categories = v);
    });

    if (e != null) {
      _start = e.start;
      _end = e.end;
    } else {
      final s = widget.initialStart ?? DateTime.now();
      _start = DateTime(s.year, s.month, s.day, s.hour, s.minute);
      _end = _isAllDay ? _start : _start.add(const Duration(hours: 1));
    }
  }

  AppSettings _settings = const AppSettings();
  bool _appliedDefaults = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _settings = SettingsScope.of(context);
    // 新しい予定のときだけ、設定した「デフォルトの長さ」を1回だけ使う
    if (!_appliedDefaults) {
      _appliedDefaults = true;
      if (widget.event == null && !_isAllDay) {
        _end = _start.add(Duration(minutes: _settings.eventMinutes));
      }
    }
  }

  @override
  void dispose() {
    _categorySub?.cancel();
    _titleController.dispose();
    _locationController.dispose();
    _memoController.dispose();
    _belongingInputController.dispose();
    super.dispose();
  }

  void _openGrowthLog() {
    final e = widget.event;
    if (e == null) return;
    openGrowthLogEntry(
      context,
      repository: _growthLogRepository,
      categoryId: _categoryId,
      eventId: e.id,
      title: _titleController.text.trim().isEmpty
          ? e.title
          : _titleController.text.trim(),
      date: _start,
      minutes: _end.difference(_start).inMinutes,
    );
  }

  String _timeText(DateTime d) => _settings.timeOf(d);

  /// 日付を選ぶ（開始を動かしたら、終了も同じだけ動かす）
  Future<void> _pickDate({required bool isStart}) async {
    final current = isStart ? _start : _end;
    final picked = await showDatePicker(
      context: context,
      initialDate: current,
      firstDate: DateTime(2020),
      lastDate: DateTime(2035, 12, 31),
    );
    if (picked == null) return;

    setState(() {
      final updated = DateTime(
        picked.year,
        picked.month,
        picked.day,
        current.hour,
        current.minute,
      );
      if (isStart) {
        final length = _end.difference(_start);
        _start = updated;
        _end = updated.add(length);
      } else {
        _end = updated;
      }
    });
  }

  /// 時刻を選ぶ（開始を動かしたら、終了も同じだけ動かす）
  Future<void> _pickTime({required bool isStart}) async {
    final current = isStart ? _start : _end;
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(current),
    );
    if (picked == null) return;

    setState(() {
      final updated = DateTime(
        current.year,
        current.month,
        current.day,
        picked.hour,
        picked.minute,
      );
      if (isStart) {
        final length = _end.difference(_start);
        _start = updated;
        _end = updated.add(length);
      } else {
        _end = updated;
      }
    });
  }

  /// その日の授業が終わる時刻（時程が無い日は null）
  ClockTime? _schoolEndTime(DateTime day) {
    final periods = SchoolPeriods.periodsFor(day.weekday);
    if (periods.isEmpty) return null;
    return periods.last.end;
  }

  /// 「放課後◯分後」を開始時刻に設定する
  Future<void> _pickAfterSchool() async {
    final end = _schoolEndTime(_start);
    if (end == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('この日は授業の時程が設定されていません')));
      return;
    }
    final minutes = await showDialog<int>(
      context: context,
      builder: (context) => const _AfterSchoolDialog(),
    );
    if (minutes == null) return;

    setState(() {
      final length = _end.difference(_start);
      final newStart = DateTime(
        _start.year,
        _start.month,
        _start.day,
        end.hour,
        end.minute,
      ).add(Duration(minutes: minutes));
      _isAllDay = false;
      _start = newStart;
      _end = newStart.add(
        length.isNegative ? const Duration(hours: 1) : length,
      );
    });
  }

  void _addBelonging() {
    final text = _belongingInputController.text.trim();
    if (text.isEmpty) return;
    setState(() {
      if (!_belongings.contains(text)) _belongings.add(text);
      _belongingInputController.clear();
    });
  }

  void _removeBelonging(String item) {
    setState(() => _belongings.remove(item));
  }

  void _openCategoryManager() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) =>
            CategoryManagePage(repository: widget.categoryRepository),
      ),
    );
  }

  Future<void> _save() async {
    // 終日の予定は、時刻を 0:00 にそろえる
    final start = _isAllDay
        ? DateTime(_start.year, _start.month, _start.day)
        : _start;
    final end = _isAllDay ? DateTime(_end.year, _end.month, _end.day) : _end;

    final event = CalendarEvent(
      id: widget.event?.id,
      title: _titleController.text,
      start: start,
      end: end,
      isAllDay: _isAllDay,
      location: _locationController.text,
      memo: _memoController.text,
      categoryId: _categoryId,
      belongings: _belongings,
      mood: _mood,
    );

    final error = event.validate();
    if (error != null) {
      setState(() => _errorMessage = error);
      return;
    }

    setState(() {
      _isSaving = true;
      _errorMessage = null;
    });
    try {
      final savedId = await widget.repository.save(event);
      await _syncTravelEvent(savedId, event);
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      setState(() => _errorMessage = '保存に失敗しました：$e');
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  /// 設定がONなら、この予定の分の「移動」の予定を作り直す。OFFや対象外なら消す。
  Future<void> _syncTravelEvent(String savedId, CalendarEvent saved) async {
    if (saved.isTravelEvent) return; // 「移動」の予定自体は対象外
    Future<void> clear() =>
        widget.repository.deleteTravelFor(savedId).catchError((_) {});

    if (!_settings.autoAddTravelEvents) return clear();
    final destText = saved.location?.trim() ?? '';
    if (destText.isEmpty || saved.isAllDay) return clear();

    final geo = await Geocoder.lookup(destText);
    if (geo == null) return clear();

    final plan = travelPlanFor(
      s: _settings,
      destination: geo.point,
      start: saved.start,
    );
    if (plan == null) return clear();

    final existing = await widget.repository.findTravelFor(savedId);
    await widget.repository.save(
      CalendarEvent(
        id: existing?.id,
        title: '${plan.origin.label}から移動（${plan.modeLabel}）',
        start: plan.departAt,
        end: saved.start,
        location: saved.location,
        memo:
            '「${saved.title}」のために自動で追加した移動の予定です。'
            '消しても、次に保存すればまた作られます。',
        categoryId: saved.categoryId,
        travelForEventId: savedId,
      ),
    );
  }

  Future<void> _delete() async {
    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('この予定を削除しますか？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('キャンセル'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('削除'),
          ),
        ],
      ),
    );
    if (shouldDelete != true) return;

    final id = widget.event!.id!;
    if (!widget.event!.isTravelEvent) {
      await widget.repository.deleteTravelFor(id).catchError((_) {});
    }
    await widget.repository.delete(id);
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.close),
          tooltip: '閉じる',
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(_isEditing ? '予定を編集' : '予定を追加'),
        actions: [
          if (_isEditing && _growthLogAvailable)
            IconButton(
              icon: const Icon(Icons.trending_up),
              tooltip: '成長ログに記録する',
              onPressed: _openGrowthLog,
            ),
          if (_isEditing)
            IconButton(
              icon: const Icon(Icons.celebration_outlined),
              tooltip: '関係する予定・ToDo・持ち物をまとめて見る',
              onPressed: () => openSchoolEventFromEvent(context, widget.event!),
            ),
          if (_isEditing)
            IconButton(
              icon: const Icon(Icons.delete_outline),
              tooltip: '削除',
              onPressed: _isSaving ? null : _delete,
            ),
          TextButton(
            onPressed: _isSaving ? null : _save,
            child: const Text('保存'),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // タイトル
              TextField(
                controller: _titleController,
                autofocus: !_isEditing,
                style: Theme.of(context).textTheme.titleLarge,
                decoration: const InputDecoration(
                  hintText: 'タイトル',
                  border: InputBorder.none,
                ),
              ),
              const Divider(),

              // 終日
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                secondary: const Icon(Icons.schedule),
                title: const Text('終日'),
                value: _isAllDay,
                onChanged: (value) => setState(() => _isAllDay = value),
              ),

              // 開始・終了
              _DateTimeRow(
                label: '開始',
                dateText: _settings.date(_start, weekday: true),
                timeText: _isAllDay ? null : _timeText(_start),
                onTapDate: () => _pickDate(isStart: true),
                onTapTime: () => _pickTime(isStart: true),
              ),
              _DateTimeRow(
                label: '終了',
                dateText: _settings.date(_end, weekday: true),
                timeText: _isAllDay ? null : _timeText(_end),
                onTapDate: () => _pickDate(isStart: false),
                onTapTime: () => _pickTime(isStart: false),
              ),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  onPressed: _pickAfterSchool,
                  icon: const Icon(Icons.directions_run, size: 18),
                  label: const Text('放課後◯分後に設定'),
                ),
              ),
              const Divider(),

              // カテゴリ
              const SizedBox(height: 8),
              Row(
                children: [
                  Text('カテゴリ', style: Theme.of(context).textTheme.labelLarge),
                  const Spacer(),
                  TextButton.icon(
                    onPressed: _openCategoryManager,
                    icon: const Icon(Icons.edit_outlined, size: 18),
                    label: const Text('編集'),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              StreamBuilder<List<EventCategory>>(
                stream: _categoryStream,
                builder: (context, snapshot) {
                  final categories = snapshot.data ?? const <EventCategory>[];
                  return Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final category in categories)
                        ChoiceChip(
                          avatar: CircleAvatar(
                            radius: 6,
                            backgroundColor: Color(category.colorValue),
                          ),
                          label: Text(category.name),
                          selected: _categoryId == category.id,
                          onSelected: (_) =>
                              setState(() => _categoryId = category.id),
                        ),
                    ],
                  );
                },
              ),
              const SizedBox(height: 16),
              const Divider(),

              // 気分（任意・選ぶだけ。設定でOFFにできる）
              if (_settings.moodTrackingEnabled) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  Text('気分', style: Theme.of(context).textTheme.labelLarge),
                  const Spacer(),
                  Row(
                    children: [
                      for (final m in eventMoods)
                        IconButton(
                          isSelected: _mood == m,
                          style: IconButton.styleFrom(
                            backgroundColor: _mood == m
                                ? colorScheme.secondaryContainer
                                : null,
                          ),
                          onPressed: () => setState(
                            () => _mood = _mood == m ? null : m,
                          ),
                          icon: Text(m, style: const TextStyle(fontSize: 18)),
                        ),
                    ],
                  ),
                ],
              ),
              const Divider(),
              ],

              // 場所（右のボタンで Google マップを開く）
              TextField(
                controller: _locationController,
                decoration: InputDecoration(
                  icon: const Icon(Icons.place_outlined),
                  hintText: '場所（施設名・住所・マップのURL）',
                  border: InputBorder.none,
                  suffixIcon: IconButton(
                    icon: const Icon(Icons.map_outlined),
                    tooltip: 'Google マップで開く',
                    onPressed: () => openMap(context, _locationController.text),
                  ),
                ),
              ),

              // 移動時間と出発時刻の目安（場所が入っているとき）
              ValueListenableBuilder<TextEditingValue>(
                valueListenable: _locationController,
                builder: (context, value, _) => TravelCard(
                  destination: value.text,
                  start: _start,
                  isAllDay: _isAllDay,
                ),
              ),

              // メモ
              TextField(
                controller: _memoController,
                minLines: 3,
                maxLines: 8,
                decoration: const InputDecoration(
                  icon: Icon(Icons.notes),
                  hintText: 'メモ',
                  border: InputBorder.none,
                ),
              ),

              const Divider(),
              const SizedBox(height: 8),
              Row(
                children: [
                  const Icon(Icons.checklist_outlined, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    'この予定の持ち物',
                    style: Theme.of(context).textTheme.labelLarge,
                  ),
                ],
              ),
              const SizedBox(height: 8),
              if (_belongings.isNotEmpty)
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final item in _belongings)
                      InputChip(
                        label: Text(item),
                        onDeleted: () => _removeBelonging(item),
                      ),
                  ],
                ),
              const SizedBox(height: 4),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _belongingInputController,
                      decoration: const InputDecoration(
                        hintText: '持ち物を追加（例：傘）',
                        border: InputBorder.none,
                      ),
                      onSubmitted: (_) => _addBelonging(),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.add_circle_outline),
                    tooltip: '追加',
                    onPressed: _addBelonging,
                  ),
                ],
              ),

              if (_errorMessage != null) ...[
                const SizedBox(height: 16),
                Text(
                  _errorMessage!,
                  style: TextStyle(color: colorScheme.error),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// 「開始」「終了」の行
class _DateTimeRow extends StatelessWidget {
  const _DateTimeRow({
    required this.label,
    required this.dateText,
    required this.timeText,
    required this.onTapDate,
    required this.onTapTime,
  });

  final String label;
  final String dateText;

  /// 終日のときは null（時刻を出さない）
  final String? timeText;

  final VoidCallback onTapDate;
  final VoidCallback onTapTime;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(width: 40, child: Text(label)),
        const Spacer(),
        TextButton(onPressed: onTapDate, child: Text(dateText)),
        if (timeText != null)
          TextButton(onPressed: onTapTime, child: Text(timeText!)),
      ],
    );
  }
}

/// 「放課後◯分後」の分数を入力するダイアログ
class _AfterSchoolDialog extends StatefulWidget {
  const _AfterSchoolDialog();

  @override
  State<_AfterSchoolDialog> createState() => _AfterSchoolDialogState();
}

class _AfterSchoolDialogState extends State<_AfterSchoolDialog> {
  final _controller = TextEditingController(text: '0');

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final minutes = int.tryParse(_controller.text.trim()) ?? 0;
    Navigator.of(context).pop(minutes);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('放課後◯分後'),
      content: TextField(
        controller: _controller,
        autofocus: true,
        keyboardType: TextInputType.number,
        decoration: const InputDecoration(
          labelText: '放課後から何分後か',
          suffixText: '分後',
        ),
        onSubmitted: (_) => _submit(),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('キャンセル'),
        ),
        FilledButton(onPressed: _submit, child: const Text('設定')),
      ],
    );
  }
}
