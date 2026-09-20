import 'package:firebase_auth/firebase_auth.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/date_format.dart';
import '../../core/maps.dart';
import '../events/calendar_event.dart';
import 'google_sync.dart';

/// Google カレンダーの予定を、つづりから編集する（6-4）
class GoogleEventEditPage extends StatefulWidget {
  const GoogleEventEditPage({super.key, required this.event});

  final CalendarEvent event;

  @override
  State<GoogleEventEditPage> createState() => _GoogleEventEditPageState();
}

class _GoogleEventEditPageState extends State<GoogleEventEditPage> {
  late final _e = widget.event;
  late final _title = TextEditingController(text: _e.title);
  late final _location = TextEditingController(text: _e.location ?? '');
  late final _memo = TextEditingController(text: _e.memo ?? '');
  late bool _allDay = _e.isAllDay;
  late DateTime _start = _e.start;
  late DateTime _end = _e.end;
  bool _saving = false;
  String? _error;

  String _hm(DateTime d) => '${d.hour}:${d.minute.toString().padLeft(2, '0')}';

  Future<void> _pickDate(bool isStart) async {
    final cur = isStart ? _start : _end;
    final d = await showDatePicker(
      context: context,
      initialDate: cur,
      firstDate: DateTime(2020),
      lastDate: DateTime(2035, 12, 31),
    );
    if (d == null) return;
    setState(() {
      final v = DateTime(d.year, d.month, d.day, cur.hour, cur.minute);
      if (isStart) {
        final len = _end.difference(_start);
        _start = v;
        _end = v.add(len);
      } else {
        _end = v;
      }
    });
  }

  Future<void> _pickTime(bool isStart) async {
    final cur = isStart ? _start : _end;
    final t = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(cur),
    );
    if (t == null) return;
    setState(() {
      final v = DateTime(cur.year, cur.month, cur.day, t.hour, t.minute);
      if (isStart) {
        final len = _end.difference(_start);
        _start = v;
        _end = v.add(len);
      } else {
        _end = v;
      }
    });
  }

  Future<void> _save() async {
    final next = CalendarEvent(
      id: _e.id,
      title: _title.text.trim(),
      start: _allDay ? DateTime(_start.year, _start.month, _start.day) : _start,
      end: _allDay ? DateTime(_end.year, _end.month, _end.day) : _end,
      isAllDay: _allDay,
      location: _location.text.trim().isEmpty ? null : _location.text.trim(),
      memo: _memo.text.trim().isEmpty ? null : _memo.text.trim(),
      categoryId: _e.categoryId,
    );
    final err = next.validate();
    if (err != null) return setState(() => _error = err);

    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await GoogleSyncRepository(uid: FirebaseAuth.instance.currentUser!.uid)
          .updateGoogleEvent(_e, next);
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      setState(() => _error = '保存できませんでした：$e');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Widget _row(String label, DateTime d, bool isStart) => Row(
    children: [
      SizedBox(width: 40, child: Text(label)),
      const Spacer(),
      TextButton(
        onPressed: () => _pickDate(isStart),
        child: Text(formatDateJa(d)),
      ),
      if (!_allDay)
        TextButton(onPressed: () => _pickTime(isStart), child: Text(_hm(d))),
    ],
  );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text('Google の予定を編集'),
        actions: [
          TextButton(
            onPressed: _saving ? null : _save,
            child: const Text('保存'),
          ),
        ],
      ),
      body: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              TextField(
                controller: _title,
                style: Theme.of(context).textTheme.titleLarge,
                decoration: const InputDecoration(
                  hintText: 'タイトル',
                  border: InputBorder.none,
                ),
              ),
              const Divider(),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                secondary: const Icon(Icons.schedule),
                title: const Text('終日'),
                value: _allDay,
                onChanged: (v) => setState(() => _allDay = v),
              ),
              _row('開始', _start, true),
              _row('終了', _end, false),
              const Divider(),
              TextField(
                controller: _location,
                decoration: InputDecoration(
                  icon: const Icon(Icons.place_outlined),
                  hintText: '場所',
                  border: InputBorder.none,
                  suffixIcon: IconButton(
                    icon: const Icon(Icons.map_outlined),
                    tooltip: 'Google マップで開く',
                    onPressed: () => openMap(context, _location.text),
                  ),
                ),
              ),
              TextField(
                controller: _memo,
                minLines: 2,
                maxLines: 6,
                decoration: const InputDecoration(
                  icon: Icon(Icons.notes),
                  hintText: 'メモ',
                  border: InputBorder.none,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '保存すると Google カレンダーの予定も書き換わります。',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.outline,
                  fontSize: 12,
                ),
              ),
              if (_error != null) ...[
                const SizedBox(height: 12),
                Text(
                  _error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
