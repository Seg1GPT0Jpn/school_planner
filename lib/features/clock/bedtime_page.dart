/// お休み時間機能
library;

import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:file_picker/file_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:material_ui/material_ui.dart';

import '../timetable/school_periods.dart' show ClockTime;
import 'alarm_page.dart' show rescheduleAlarms;
import 'alarm_repository.dart';
import 'clock_models.dart';
import 'clock_settings_repository.dart';

class BedtimeTab extends StatefulWidget {
  const BedtimeTab({super.key});

  @override
  State<BedtimeTab> createState() => _BedtimeTabState();
}

class _BedtimeTabState extends State<BedtimeTab> {
  late final _settingsRepo = ClockSettingsRepository(
    uid: FirebaseAuth.instance.currentUser!.uid,
  );
  late final _alarmRepo = AlarmRepository(
    uid: FirebaseAuth.instance.currentUser!.uid,
  );
  ClockSettings _settings = const ClockSettings();
  BedtimeSchedule get _bedtime => _settings.bedtime;
  bool _loaded = false;

  final _player = AudioPlayer();
  bool _preview = false;

  @override
  void initState() {
    super.initState();
    _settingsRepo.load().then((s) {
      if (!mounted) return;
      setState(() {
        _settings = s;
        _loaded = true;
      });
    });
  }

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }

  Future<void> _update(BedtimeSchedule Function(BedtimeSchedule) f) async {
    final next = _settings.copyWith(bedtime: f(_bedtime));
    setState(() => _settings = next);
    await _settingsRepo.save(next);
    await _syncWakeAlarm(next.bedtime);
  }

  /// お休み時間の「起きる時間」を、専用のアラームとして自動でつくる・更新する
  Future<void> _syncWakeAlarm(BedtimeSchedule b) async {
    final alarms = await _alarmRepo.watch().first;
    Alarm? linked;
    for (final a in alarms) {
      if (a.bedtimeLinked) linked = a;
    }
    if (!b.enabled) {
      if (linked != null) await _alarmRepo.delete(linked.id!);
      await rescheduleAlarms();
      return;
    }
    final next = (linked ?? Alarm(time: b.wakeTime, kind: AlarmKind.wakeUp)).copyWith(
      time: b.wakeTime,
      kind: AlarmKind.wakeUp,
      weekdays: b.days,
      bedtimeLinked: true,
      label: 'おはよう',
    );
    await _alarmRepo.save(next);
    await rescheduleAlarms();
  }

  Future<void> _pickTime({required bool isBedTime}) async {
    final t = isBedTime ? _bedtime.bedTime : _bedtime.wakeTime;
    final p = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: t.hour, minute: t.minute),
    );
    if (p == null) return;
    final time = ClockTime(p.hour, p.minute);
    await _update(
      (b) => isBedTime ? b.copyWith(bedTime: time) : b.copyWith(wakeTime: time),
    );
  }

  Future<void> _pickSound() async {
    final f = await FilePicker.pickFile(
      type: FileType.custom,
      allowedExtensions: const ['mp3', 'wav', 'm4a', 'aac', 'ogg', 'flac'],
    );
    if (f == null || f.path == null) return;
    await _update((b) => b.copyWith(sleepSoundPath: f.path, sleepSoundName: f.name));
  }

  Future<void> _togglePreview() async {
    if (_preview) {
      await _player.stop();
      setState(() => _preview = false);
      return;
    }
    final path = _bedtime.sleepSoundPath;
    if (path == null) return;
    try {
      await _player.setReleaseMode(ReleaseMode.loop);
      await _player.play(DeviceFileSource(path));
      setState(() => _preview = true);
    } catch (_) {}
  }

  /// お休み時間の何分前から、安眠サウンドを流せる状態になるか
  DateTime? get _soundAvailableFrom {
    if (_bedtime.sleepSoundPath == null) return null;
    final now = DateTime.now();
    final bed = DateTime(now.year, now.month, now.day, _bedtime.bedTime.hour, _bedtime.bedTime.minute);
    final target = bed.isBefore(now) ? bed.add(const Duration(days: 1)) : bed;
    return target.subtract(Duration(minutes: _bedtime.sleepSoundStartsMinutesBefore));
  }

  @override
  Widget build(BuildContext context) {
    if (!_loaded) return const Center(child: CircularProgressIndicator());
    final label = Theme.of(context).textTheme.labelLarge;
    final b = _bedtime;
    final soundFrom = _soundAvailableFrom;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('お休み時間を使う'),
          subtitle: const Text('起きる時間には、専用の起床アラームが自動でセットされます'),
          value: b.enabled,
          onChanged: (v) => _update((x) => x.copyWith(enabled: v)),
        ),
        const Divider(height: 24),
        Text('スケジュール', style: label),
        Row(
          children: [
            Expanded(
              child: ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.bedtime_outlined),
                title: const Text('寝る時間'),
                subtitle: Text('${b.bedTime}'),
                onTap: () => _pickTime(isBedTime: true),
              ),
            ),
            Expanded(
              child: ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.wb_sunny_outlined),
                title: const Text('起きる時間'),
                subtitle: Text('${b.wakeTime}'),
                onTap: () => _pickTime(isBedTime: false),
              ),
            ),
          ],
        ),
        Text('睡眠時間の目安：${b.sleepDurationText}'),
        const SizedBox(height: 12),
        Text('曜日', style: label),
        Wrap(
          spacing: 6,
          children: [
            for (var w = 1; w <= 7; w++)
              FilterChip(
                label: Text(clockWeekdayLabel(w)),
                selected: b.days.contains(w),
                onSelected: (on) => _update((x) {
                  final days = {...x.days};
                  on ? days.add(w) : days.remove(w);
                  return x.copyWith(days: days);
                }),
              ),
          ],
        ),
        const Divider(height: 32),
        Text('安眠サウンド', style: label),
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.music_note_outlined),
          title: Text(b.sleepSoundName ?? '音が選ばれていません'),
          subtitle: Text('お休み時間の${b.sleepSoundStartsMinutesBefore}分前から流せます'),
          trailing: Wrap(
            spacing: 4,
            children: [
              if (b.sleepSoundPath != null)
                IconButton(
                  icon: Icon(_preview ? Icons.stop_circle_outlined : Icons.play_circle_outline),
                  onPressed: _togglePreview,
                ),
              TextButton(onPressed: _pickSound, child: const Text('選ぶ')),
            ],
          ),
        ),
        Row(
          children: [
            const Text('何分前から流せるか　'),
            const Spacer(),
            for (final m in const [5, 10, 15, 20, 30])
              Padding(
                padding: const EdgeInsets.only(left: 4),
                child: ChoiceChip(
                  label: Text('$m分'),
                  selected: b.sleepSoundStartsMinutesBefore == m,
                  onSelected: (_) =>
                      _update((x) => x.copyWith(sleepSoundStartsMinutesBefore: m)),
                ),
              ),
          ],
        ),
        if (soundFrom != null)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              '今日は ${soundFrom.hour.toString().padLeft(2, '0')}:'
              '${soundFrom.minute.toString().padLeft(2, '0')} から流せます',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
        const Divider(height: 32),
        Text('今後の予定', style: label),
        for (var i = 0; i < 3; i++) _UpcomingNight(bedtime: b, daysFromNow: i),
      ],
    );
  }
}

class _UpcomingNight extends StatelessWidget {
  const _UpcomingNight({required this.bedtime, required this.daysFromNow});

  final BedtimeSchedule bedtime;
  final int daysFromNow;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final day = DateTime(now.year, now.month, now.day + daysFromNow);
    if (!bedtime.enabled || !bedtime.days.contains(day.weekday)) {
      return const SizedBox.shrink();
    }
    const wd = ['月', '火', '水', '木', '金', '土', '日'];
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: const Icon(Icons.nights_stay_outlined),
      title: Text('${day.month}/${day.day}(${wd[day.weekday - 1]})'),
      subtitle: Text('${bedtime.bedTime} 就寝 → ${bedtime.wakeTime} 起床'),
    );
  }
}
