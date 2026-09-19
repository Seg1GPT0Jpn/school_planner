import 'package:firebase_auth/firebase_auth.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/date_format.dart';
import 'school_periods.dart';
import 'school_settings_repository.dart';
import 'timetable_models.dart';
import 'timetable_repository.dart';

/// 学校の設定（休業日・特別な日課）
class SchoolSettingsPage extends StatefulWidget {
  const SchoolSettingsPage({super.key});

  @override
  State<SchoolSettingsPage> createState() => _SchoolSettingsPageState();
}

class _SchoolSettingsPageState extends State<SchoolSettingsPage> {
  late final Stream<TimetableData> _stream;
  late final SchoolSettingsRepository _repository;

  @override
  void initState() {
    super.initState();
    final uid = FirebaseAuth.instance.currentUser!.uid;
    _stream = TimetableRepository(uid: uid).watch();
    _repository = SchoolSettingsRepository(uid: uid);
  }

  Future<bool> _confirm(String title) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text(title),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(c).pop(false),
            child: const Text('キャンセル'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(c).pop(true),
            child: const Text('削除'),
          ),
        ],
      ),
    );
    return ok == true;
  }

  /// 休業日を追加：期間を選ぶ → 名前を入れる
  Future<void> _addClosure() async {
    final range = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime(2035, 12, 31),
    );
    if (range == null || !mounted) return;

    final controller = TextEditingController();
    final title = await showDialog<String>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('休業日の名前'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(hintText: '例：夏休み、臨時休校'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(c).pop(),
            child: const Text('キャンセル'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(c).pop(controller.text.trim()),
            child: const Text('追加'),
          ),
        ],
      ),
    );
    if (title == null || title.isEmpty) return;

    await _repository.addClosure(
      SchoolClosure(start: range.start, end: range.end, title: title),
    );
  }

  /// 短縮日課・試験日課の日を追加：日付を選ぶ → 日課とメモ
  Future<void> _addSchedule() async {
    final date = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2035, 12, 31),
    );
    if (date == null || !mounted) return;

    var schedule = DaySchedule.shortened;
    final noteController = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => StatefulBuilder(
        builder: (c, setDialogState) => AlertDialog(
          title: Text(formatDateJa(date)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SegmentedButton<DaySchedule>(
                segments: const [
                  ButtonSegment(
                    value: DaySchedule.shortened,
                    label: Text('短縮日課'),
                  ),
                  ButtonSegment(value: DaySchedule.exam, label: Text('試験日課')),
                ],
                selected: {schedule},
                onSelectionChanged: (s) =>
                    setDialogState(() => schedule = s.first),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: noteController,
                decoration: const InputDecoration(labelText: 'メモ（例：後期期末試験）'),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(c).pop(false),
              child: const Text('キャンセル'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(c).pop(true),
              child: const Text('追加'),
            ),
          ],
        ),
      ),
    );
    if (ok != true) return;

    await _repository.setSchedule(date, schedule, noteController.text);
  }

  Widget _header(String title, VoidCallback onAdd) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 8, 0),
      child: Row(
        children: [
          Expanded(
            child: Text(title, style: Theme.of(context).textTheme.titleMedium),
          ),
          TextButton.icon(
            onPressed: onAdd,
            icon: const Icon(Icons.add),
            label: const Text('追加'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('学校の設定')),
      body: StreamBuilder<TimetableData>(
        stream: _stream,
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final data = snapshot.data!;
          final closures = [...data.closures]
            ..sort((a, b) => a.start.compareTo(b.start));
          final schedules = [
            for (final o in data.dayOverrides)
              if (o.schedule != null) o,
          ]..sort((a, b) => a.date.compareTo(b.date));

          return Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 560),
              child: ListView(
                children: [
                  _header('学校休業日', _addClosure),
                  for (final c in closures)
                    ListTile(
                      title: Text(c.title),
                      subtitle: Text(
                        '${formatDateJa(c.start)} 〜 ${formatDateJa(c.end)}',
                      ),
                      trailing: IconButton(
                        icon: const Icon(Icons.delete_outline),
                        tooltip: '削除',
                        onPressed: () async {
                          if (await _confirm('「${c.title}」を削除しますか？')) {
                            await _repository.deleteClosure(c);
                          }
                        },
                      ),
                    ),
                  const Divider(),
                  _header('短縮日課・試験日課の日', _addSchedule),
                  for (final o in schedules)
                    ListTile(
                      title: Text(
                        '${formatDateJa(o.date)}　${o.schedule!.label}',
                      ),
                      subtitle: o.note == null ? null : Text(o.note!),
                      trailing: IconButton(
                        icon: const Icon(Icons.delete_outline),
                        tooltip: '通常日課に戻す',
                        onPressed: () async {
                          if (await _confirm('通常日課に戻しますか？')) {
                            await _repository.clearSchedule(o.date);
                          }
                        },
                      ),
                    ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
