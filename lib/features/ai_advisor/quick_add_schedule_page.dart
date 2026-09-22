/// 「サクッと予定入力」― 自然文をヒントに予定の下書きを作る画面
///
/// まず端末内のルールベースの解析（nl_schedule_parser.dart）で即座に下書きを作り、
/// 設定で生成AI（Gemini）がONのときは、入力が少し止まったあと（約0.7秒後）に
/// Gemini による読み取り結果に置き換える。Geminiが使えない・失敗したときは
/// ルールベースの結果のまま。どちらの場合も、読み取った内容は必ずこの画面で
/// 確認・修正してから保存する（自動保存はしない）。
library;

import 'dart:async';

import 'package:material_ui/material_ui.dart';

import '../events/calendar_event.dart';
import '../events/event_repository.dart';
import '../settings/settings_scope.dart';
import 'gemini_advisor.dart';
import 'nl_schedule_parser.dart';

class QuickAddSchedulePage extends StatefulWidget {
  const QuickAddSchedulePage({super.key, required this.repository});

  final EventRepository repository;

  @override
  State<QuickAddSchedulePage> createState() => _QuickAddSchedulePageState();
}

class _QuickAddSchedulePageState extends State<QuickAddSchedulePage> {
  final _inputController = TextEditingController();
  final _titleController = TextEditingController();
  DateTime _date = _day(DateTime.now());
  TimeOfDayValue? _start;
  TimeOfDayValue? _end;
  bool _isAllDay = true;
  List<String> _notes = const [];
  bool _saving = false;

  Timer? _debounce;
  bool _aiParsing = false;
  int _requestSeq = 0;

  static DateTime _day(DateTime d) => DateTime(d.year, d.month, d.day);

  void _applyParsed(ParsedSchedule p) {
    setState(() {
      _titleController.text = p.title;
      _date = p.date;
      _start = p.startTime;
      _end =
          p.endTime ??
          (p.startTime == null
              ? null
              : TimeOfDayValue(
                  (p.startTime!.hour + 1) % 24,
                  p.startTime!.minute,
                ));
      _isAllDay = p.startTime == null;
      _notes = p.notes;
    });
  }

  void _onChanged(String text) {
    _debounce?.cancel();
    if (text.trim().isEmpty) {
      setState(() => _aiParsing = false);
      return;
    }

    // まずはルールベースで即座に下書きを作る（体感の速さのため）
    _applyParsed(parseScheduleText(text, now: DateTime.now()));

    final useAi = SettingsScope.of(context).generativeAiEnabled;
    if (!useAi) return;

    final seq = ++_requestSeq;
    setState(() => _aiParsing = true);
    _debounce = Timer(const Duration(milliseconds: 700), () async {
      final result = await parseScheduleWithGemini(text, now: DateTime.now());
      if (!mounted || seq != _requestSeq) return;
      setState(() => _aiParsing = false);
      if (result != null) _applyParsed(result);
    });
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(_date.year - 1),
      lastDate: DateTime(_date.year + 2),
    );
    if (picked != null) setState(() => _date = _day(picked));
  }

  Future<void> _pickTime(bool isStart) async {
    final initial = (isStart ? _start : _end) ?? const TimeOfDayValue(9, 0);
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: initial.hour, minute: initial.minute),
    );
    if (picked == null) return;
    setState(() {
      final v = TimeOfDayValue(picked.hour, picked.minute);
      if (isStart) {
        _start = v;
      } else {
        _end = v;
      }
      _isAllDay = false;
    });
  }

  Future<void> _save() async {
    final title = _titleController.text.trim();
    if (title.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('タイトルを入力してください')));
      return;
    }

    DateTime start;
    DateTime end;
    if (_isAllDay || _start == null) {
      start = _date;
      end = _date;
    } else {
      start = DateTime(
        _date.year,
        _date.month,
        _date.day,
        _start!.hour,
        _start!.minute,
      );
      final e =
          _end ?? TimeOfDayValue((_start!.hour + 1) % 24, _start!.minute);
      end = DateTime(_date.year, _date.month, _date.day, e.hour, e.minute);
      if (!end.isAfter(start)) {
        end = start.add(const Duration(hours: 1));
      }
    }

    final event = CalendarEvent(
      title: title,
      start: start,
      end: end,
      isAllDay: _isAllDay,
    );
    final problem = event.validate();
    if (problem != null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(problem)));
      return;
    }

    setState(() => _saving = true);
    try {
      await widget.repository.save(event);
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('保存できませんでした: $e')));
      }
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _inputController.dispose();
    _titleController.dispose();
    super.dispose();
  }

  String _dateLabel(DateTime d) => '${d.month}/${d.day}';

  String _timeLabel(TimeOfDayValue? t) => t == null
      ? '未設定'
      : '${t.hour.toString().padLeft(2, '0')}:'
            '${t.minute.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    final generativeAiEnabled = SettingsScope.of(context).generativeAiEnabled;
    return Scaffold(
      appBar: AppBar(title: const Text('サクッと予定入力')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            '文章で入力すると、日付・時刻・タイトルを読み取ります'
            '（例：「明日15時から16時 数学の宿題」）。\n'
            '読み取った内容は下で必ず確認・修正してから保存してください。'
            '${generativeAiEnabled ? '\n生成AIがONなので、より柔軟な言い回しも読み取れます。' : ''}',
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _inputController,
            decoration: const InputDecoration(
              labelText: '文章で入力',
              border: OutlineInputBorder(),
            ),
            maxLines: 2,
            onChanged: _onChanged,
          ),
          if (_aiParsing)
            const Padding(
              padding: EdgeInsets.only(top: 6),
              child: Row(
                children: [
                  SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                  SizedBox(width: 8),
                  Text('AIが読み取り中…', style: TextStyle(fontSize: 12)),
                ],
              ),
            ),
          const SizedBox(height: 20),
          if (_notes.isNotEmpty)
            Card(
              color: Theme.of(context).colorScheme.secondaryContainer,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [for (final n in _notes) Text('⚠️ $n')],
                ),
              ),
            ),
          const SizedBox(height: 8),
          TextField(
            controller: _titleController,
            decoration: const InputDecoration(
              labelText: 'タイトル',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('日付'),
            trailing: TextButton(
              onPressed: _pickDate,
              child: Text(_dateLabel(_date)),
            ),
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('終日'),
            value: _isAllDay,
            onChanged: (v) => setState(() {
              _isAllDay = v;
              if (!v) {
                _start ??= const TimeOfDayValue(9, 0);
                _end ??= const TimeOfDayValue(10, 0);
              }
            }),
          ),
          if (!_isAllDay) ...[
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('開始'),
              trailing: TextButton(
                onPressed: () => _pickTime(true),
                child: Text(_timeLabel(_start)),
              ),
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('終了'),
              trailing: TextButton(
                onPressed: () => _pickTime(false),
                child: Text(_timeLabel(_end)),
              ),
            ),
          ],
          const SizedBox(height: 24),
          FilledButton(
            onPressed: _saving ? null : _save,
            child: Text(_saving ? '保存中…' : '予定として保存'),
          ),
        ],
      ),
    );
  }
}
