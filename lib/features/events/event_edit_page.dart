import 'package:material_ui/material_ui.dart';

import '../../core/date_format.dart';
import 'calendar_event.dart';
import 'event_colors.dart';
import 'event_repository.dart';

/// 予定の追加・編集画面
class EventEditPage extends StatefulWidget {
  const EventEditPage({
    super.key,
    required this.repository,
    this.event,
    this.initialStart,
    this.initialAllDay = false,
  });

  final EventRepository repository;

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

  late DateTime _start;
  late DateTime _end;
  late bool _isAllDay;
  late EventCategory _category;

  bool _isSaving = false;
  String? _errorMessage;

  bool get _isEditing => widget.event != null;

  @override
  void initState() {
    super.initState();
    final e = widget.event;
    _titleController = TextEditingController(text: e?.title ?? '');
    _locationController = TextEditingController(text: e?.location ?? '');
    _memoController = TextEditingController(text: e?.memo ?? '');
    _isAllDay = e?.isAllDay ?? widget.initialAllDay;
    _category = e?.category ?? EventCategory.other;

    if (e != null) {
      _start = e.start;
      _end = e.end;
    } else {
      final s = widget.initialStart ?? DateTime.now();
      _start = DateTime(s.year, s.month, s.day, s.hour, s.minute);
      _end = _isAllDay ? _start : _start.add(const Duration(hours: 1));
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _locationController.dispose();
    _memoController.dispose();
    super.dispose();
  }

  String _timeText(DateTime d) =>
      '${d.hour}:${d.minute.toString().padLeft(2, '0')}';

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
      category: _category,
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
      await widget.repository.save(event);
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      setState(() => _errorMessage = '保存に失敗しました：$e');
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
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

    await widget.repository.delete(widget.event!.id!);
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
                dateText: formatDateJa(_start),
                timeText: _isAllDay ? null : _timeText(_start),
                onTapDate: () => _pickDate(isStart: true),
                onTapTime: () => _pickTime(isStart: true),
              ),
              _DateTimeRow(
                label: '終了',
                dateText: formatDateJa(_end),
                timeText: _isAllDay ? null : _timeText(_end),
                onTapDate: () => _pickDate(isStart: false),
                onTapTime: () => _pickTime(isStart: false),
              ),
              const Divider(),

              // カテゴリ
              const SizedBox(height: 8),
              Text('カテゴリ', style: Theme.of(context).textTheme.labelLarge),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final category in EventCategory.values)
                    ChoiceChip(
                      avatar: CircleAvatar(
                        radius: 6,
                        backgroundColor: eventCategoryColor(category),
                      ),
                      label: Text(category.label),
                      selected: _category == category,
                      onSelected: (_) => setState(() => _category = category),
                    ),
                ],
              ),
              const SizedBox(height: 16),
              const Divider(),

              // 場所・メモ
              TextField(
                controller: _locationController,
                decoration: const InputDecoration(
                  icon: Icon(Icons.place_outlined),
                  hintText: '場所',
                  border: InputBorder.none,
                ),
              ),
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
