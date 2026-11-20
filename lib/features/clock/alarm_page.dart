/// アラームの一覧・追加・編集
library;

import 'package:file_picker/file_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/date_format.dart';
import '../notifications/notification_service.dart';
import '../timetable/school_periods.dart' show ClockTime;
import 'alarm_repository.dart';
import 'clock_models.dart';
import 'clock_settings_repository.dart';

AlarmRepository _repo() =>
    AlarmRepository(uid: FirebaseAuth.instance.currentUser!.uid);

/// アラーム一覧が変わるたびに、鳴動の予約をつくり直す
Future<void> rescheduleAlarms() async {
  final alarms = await _repo().watch().first;
  await NotificationService.instance.scheduleAlarms(alarms);
}

class AlarmListView extends StatefulWidget {
  const AlarmListView({super.key});

  @override
  State<AlarmListView> createState() => _AlarmListViewState();
}

class _AlarmListViewState extends State<AlarmListView> {
  late final _stream = _repo().watch();

  void _edit([Alarm? a]) {
    Navigator.of(context, rootNavigator: true).push(
      MaterialPageRoute<void>(
        fullscreenDialog: true,
        builder: (_) => AlarmEditPage(alarm: a),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      floatingActionButton: FloatingActionButton(
        tooltip: 'アラームを追加',
        onPressed: _edit,
        child: const Icon(Icons.add),
      ),
      body: StreamBuilder<List<Alarm>>(
        stream: _stream,
        builder: (context, snap) {
          if (!snap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final now = DateTime.now();
          final list = sortAlarms(snap.data!, now);
          if (list.isEmpty) {
            return const Center(child: Text('右下の＋からアラームを追加してください'));
          }
          return ListView(
            padding: const EdgeInsets.fromLTRB(8, 8, 8, 88),
            children: [
              for (final a in list)
                Card(
                  child: ListTile(
                    leading: Icon(
                      a.kind == AlarmKind.wakeUp
                          ? Icons.wb_sunny_outlined
                          : Icons.alarm,
                    ),
                    title: Text(
                      '${a.time.hour.toString().padLeft(2, '0')}:'
                      '${a.time.minute.toString().padLeft(2, '0')}　${a.displayLabel}',
                    ),
                    subtitle: Text(
                      [
                        a.scheduleText,
                        if (a.bedtimeLinked) 'お休み時間と連動',
                      ].join('・'),
                    ),
                    trailing: Switch(
                      value: a.enabled,
                      onChanged: (v) async {
                        await _repo().setEnabled(a.id!, v);
                        await rescheduleAlarms();
                      },
                    ),
                    onTap: () => _edit(a),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

class AlarmEditPage extends StatefulWidget {
  const AlarmEditPage({super.key, this.alarm});

  final Alarm? alarm;

  @override
  State<AlarmEditPage> createState() => _AlarmEditPageState();
}

class _AlarmEditPageState extends State<AlarmEditPage> {
  late final _label = TextEditingController(text: widget.alarm?.label);
  late ClockTime _time = widget.alarm?.time ?? const ClockTime(7, 0);
  late AlarmKind _kind = widget.alarm?.kind ?? AlarmKind.normal;
  final Set<int> _weekdays = {};
  late DateTime? _specificDate = widget.alarm?.specificDate;
  late String? _soundPath = widget.alarm?.soundPath;
  late String? _soundName = widget.alarm?.soundName;
  late double _volume = widget.alarm?.volume ?? 0.85;
  late bool _gradualVolume = widget.alarm?.gradualVolume ?? true;
  late int _snoozeMinutes = widget.alarm?.snoozeMinutes ?? 5;
  late int _dismissAfterMinutes = widget.alarm?.dismissAfterMinutes ?? 15;
  late AlarmVolumeButtonAction _volumeButtonAction =
      widget.alarm?.volumeButtonAction ?? AlarmVolumeButtonAction.snooze;
  late bool _vibrate = widget.alarm?.vibrate ?? true;
  late bool _includeWeather = widget.alarm?.includeWeather ?? false;

  @override
  void initState() {
    super.initState();
    _weekdays.addAll(widget.alarm?.weekdays ?? const {});
    if (widget.alarm == null) {
      // 新規のときは「その日の音」の既定値を読んでおく
      ClockSettingsRepository(uid: FirebaseAuth.instance.currentUser!.uid)
          .load()
          .then((s) {
            if (!mounted || s.defaultAlarmSoundPath == null) return;
            setState(() {
              _soundPath = s.defaultAlarmSoundPath;
              _soundName = s.defaultAlarmSoundName;
            });
          });
    }
  }

  Future<void> _pickTime() async {
    final p = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: _time.hour, minute: _time.minute),
    );
    if (p != null) setState(() => _time = ClockTime(p.hour, p.minute));
  }

  Future<void> _pickDate() async {
    final d = await showDatePicker(
      context: context,
      initialDate: _specificDate ?? DateTime.now(),
      firstDate: DateTime.now().subtract(const Duration(days: 1)),
      lastDate: DateTime(2035, 12, 31),
    );
    if (d != null) setState(() => _specificDate = d);
  }

  Future<void> _pickSound() async {
    final f = await FilePicker.pickFile(
      type: FileType.custom,
      allowedExtensions: const ['mp3', 'wav', 'm4a', 'aac', 'ogg', 'flac'],
    );
    if (f == null || f.path == null) return;
    setState(() {
      _soundPath = f.path;
      _soundName = f.name;
    });
  }

  Future<void> _save() async {
    final a = Alarm(
      id: widget.alarm?.id,
      time: _time,
      label: _label.text,
      kind: _kind,
      weekdays: _weekdays,
      specificDate: _weekdays.isEmpty ? _specificDate : null,
      soundPath: _soundPath,
      soundName: _soundName,
      volume: _volume,
      gradualVolume: _gradualVolume,
      snoozeMinutes: _snoozeMinutes,
      dismissAfterMinutes: _dismissAfterMinutes,
      volumeButtonAction: _volumeButtonAction,
      vibrate: _vibrate,
      includeWeather: _includeWeather,
      bedtimeLinked: widget.alarm?.bedtimeLinked ?? false,
    );
    final nav = Navigator.of(context);
    await AlarmRepository(
      uid: FirebaseAuth.instance.currentUser!.uid,
    ).save(a);
    await rescheduleAlarms();
    nav.pop();
  }

  Future<void> _delete() async {
    final nav = Navigator.of(context);
    final id = widget.alarm!.id!;
    await AlarmRepository(uid: FirebaseAuth.instance.currentUser!.uid).delete(id);
    await NotificationService.instance.cancelAlarm(id);
    nav.pop();
  }

  @override
  Widget build(BuildContext context) {
    final label = Theme.of(context).textTheme.labelLarge;
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.alarm == null ? 'アラームを追加' : 'アラームを編集'),
        actions: [
          if (widget.alarm != null)
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
          Center(
            child: TextButton(
              onPressed: _pickTime,
              child: Text(
                '${_time.hour.toString().padLeft(2, '0')}:'
                '${_time.minute.toString().padLeft(2, '0')}',
                style: Theme.of(context).textTheme.displayMedium,
              ),
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _label,
            decoration: const InputDecoration(labelText: '名前（例：塾、部活）'),
          ),
          const SizedBox(height: 16),
          Text('種類', style: label),
          Wrap(
            spacing: 6,
            children: [
              for (final k in AlarmKind.values)
                ChoiceChip(
                  label: Text(k.label),
                  selected: _kind == k,
                  onSelected: (_) => setState(() => _kind = k),
                ),
            ],
          ),
          const SizedBox(height: 16),
          Text('曜日（繰り返す曜日を選ぶ。選ばなければ特定の日にち／次の1回だけ）', style: label),
          Wrap(
            spacing: 6,
            children: [
              for (var w = 1; w <= 7; w++)
                FilterChip(
                  label: Text(clockWeekdayLabel(w)),
                  selected: _weekdays.contains(w),
                  onSelected: (on) => setState(
                    () => on ? _weekdays.add(w) : _weekdays.remove(w),
                  ),
                ),
            ],
          ),
          if (_weekdays.isEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Row(
                children: [
                  Text('特定の日にち', style: label),
                  const Spacer(),
                  TextButton(
                    onPressed: _pickDate,
                    child: Text(
                      _specificDate == null
                          ? '指定しない（次の1回だけ）'
                          : formatDateJa(_specificDate!),
                    ),
                  ),
                  if (_specificDate != null)
                    IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () => setState(() => _specificDate = null),
                    ),
                ],
              ),
            ),
          const Divider(height: 32),
          Text('音', style: label),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.music_note_outlined),
            title: Text(_soundName ?? '音が選ばれていません'),
            subtitle: const Text('デバイスの音楽・音声ファイルから選べます'),
            trailing: TextButton(onPressed: _pickSound, child: const Text('選ぶ')),
          ),
          Row(
            children: [
              const Icon(Icons.volume_down),
              Expanded(
                child: Slider(
                  value: _volume,
                  onChanged: (v) => setState(() => _volume = v),
                ),
              ),
              const Icon(Icons.volume_up),
            ],
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('徐々に音量を上げる'),
            value: _gradualVolume,
            onChanged: (v) => setState(() => _gradualVolume = v),
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('バイブレーション'),
            value: _vibrate,
            onChanged: (v) => setState(() => _vibrate = v),
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('天気予報を含める'),
            subtitle: const Text('アラーム画面に、今の天気・最高／最低気温を表示します'),
            value: _includeWeather,
            onChanged: (v) => setState(() => _includeWeather = v),
          ),
          const Divider(height: 32),
          Text('消音までの時間（自動で止まるまで）', style: label),
          Wrap(
            spacing: 6,
            children: [
              for (final m in dismissMinuteChoices)
                ChoiceChip(
                  label: Text('$m分'),
                  selected: _dismissAfterMinutes == m,
                  onSelected: (_) => setState(() => _dismissAfterMinutes = m),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Text('スヌーズの長さ', style: label),
          Wrap(
            spacing: 6,
            children: [
              for (final m in snoozeMinuteChoices)
                ChoiceChip(
                  label: Text('$m分'),
                  selected: _snoozeMinutes == m,
                  onSelected: (_) => setState(() => _snoozeMinutes = m),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Text('鳴動中の音量ボタンの動作', style: label),
          const Padding(
            padding: EdgeInsets.only(bottom: 4),
            child: Text(
              '※ アラーム画面がいちばん手前にあるときだけ働きます（画面ロック中は、'
              'ふつうのアプリには音量ボタンを横取りする権限がないため反応できません）',
              style: TextStyle(fontSize: 12),
            ),
          ),
          RadioGroup<AlarmVolumeButtonAction>(
            groupValue: _volumeButtonAction,
            onChanged: (v2) => setState(() => _volumeButtonAction = v2!),
            child: Column(
              children: [
                for (final v in AlarmVolumeButtonAction.values)
                  RadioListTile<AlarmVolumeButtonAction>(
                    contentPadding: EdgeInsets.zero,
                    dense: true,
                    value: v,
                    title: Text(v.label),
                    subtitle: Text(v.description),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
