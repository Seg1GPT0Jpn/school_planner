/// タイマー機能
library;

import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:file_picker/file_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/services.dart' show HapticFeedback;
import 'package:material_ui/material_ui.dart';

import '../notifications/notification_service.dart';
import 'clock_models.dart';
import 'clock_settings_repository.dart';

/// タイマーの通知に使う ID（アプリ内で1つだけ動かす想定）
const int _timerNotificationId = 959999;

class TimerTab extends StatefulWidget {
  const TimerTab({super.key});

  @override
  State<TimerTab> createState() => _TimerTabState();
}

class _TimerTabState extends State<TimerTab> {
  Duration _selected = const Duration(minutes: 5);
  Duration? _remaining;
  DateTime? _endAt;
  Timer? _ticker;
  bool _ringing = false;

  final _player = AudioPlayer();
  Timer? _volumeTimer;
  Timer? _vibrateTimer;

  ClockSettings _settings = const ClockSettings();
  late final _settingsRepo = ClockSettingsRepository(
    uid: FirebaseAuth.instance.currentUser!.uid,
  );
  StreamSubscription<ClockSettings>? _settingsSub;

  @override
  void initState() {
    super.initState();
    _settingsSub = _settingsRepo.watch().listen((s) {
      if (mounted) setState(() => _settings = s);
    });
  }

  bool get _running => _endAt != null && !_ringing;

  void _start() {
    final now = DateTime.now();
    setState(() {
      _endAt = now.add(_remaining ?? _selected);
      _remaining = null;
    });
    _ticker?.cancel();
    _ticker = Timer.periodic(const Duration(milliseconds: 250), (_) => _tick());
    unawaited(
      NotificationService.instance.scheduleOneOff(
        id: _timerNotificationId,
        title: 'タイマー終了',
        body: '設定した時間になりました',
        at: _endAt!,
      ),
    );
  }

  void _pause() {
    _ticker?.cancel();
    setState(() {
      _remaining = _endAt!.difference(DateTime.now());
      _endAt = null;
    });
    unawaited(NotificationService.instance.cancelOneOff(_timerNotificationId));
  }

  void _reset() {
    _ticker?.cancel();
    _stopRinging();
    unawaited(NotificationService.instance.cancelOneOff(_timerNotificationId));
    setState(() {
      _endAt = null;
      _remaining = null;
    });
  }

  void _addMinute() {
    if (_endAt != null) {
      setState(() => _endAt = _endAt!.add(const Duration(minutes: 1)));
    } else {
      setState(
        () => _remaining = (_remaining ?? _selected) + const Duration(minutes: 1),
      );
    }
  }

  void _tick() {
    if (_endAt == null) return;
    final left = _endAt!.difference(DateTime.now());
    if (left <= Duration.zero) {
      _ticker?.cancel();
      setState(() {
        _remaining = Duration.zero;
        _endAt = null;
      });
      _startRinging();
      return;
    }
    setState(() {});
  }

  Future<void> _startRinging() async {
    setState(() => _ringing = true);
    if (_settings.timerVibrate) {
      _vibrateTimer = Timer.periodic(
        const Duration(milliseconds: 900),
        (_) => HapticFeedback.vibrate(),
      );
    }
    final path = _settings.timerSoundPath;
    if (path != null) {
      try {
        await _player.setReleaseMode(ReleaseMode.loop);
        final startVolume = _settings.timerGradualVolume ? 0.2 : 1.0;
        await _player.setVolume(startVolume);
        await _player.play(DeviceFileSource(path));
        if (_settings.timerGradualVolume) {
          var v = startVolume;
          _volumeTimer = Timer.periodic(const Duration(seconds: 2), (t) {
            v = (v + 0.15).clamp(0, 1.0);
            _player.setVolume(v);
            if (v >= 1.0) t.cancel();
          });
        }
      } catch (_) {}
    }
  }

  void _stopRinging() {
    _volumeTimer?.cancel();
    _vibrateTimer?.cancel();
    _player.stop();
    if (mounted) setState(() => _ringing = false);
  }

  Future<void> _configureSound() async {
    final f = await FilePicker.pickFile(
      type: FileType.custom,
      allowedExtensions: const ['mp3', 'wav', 'm4a', 'aac', 'ogg', 'flac'],
    );
    if (f == null || f.path == null) return;
    final next = _settings.copyWith(timerSoundPath: f.path, timerSoundName: f.name);
    await _settingsRepo.save(next);
  }

  @override
  void dispose() {
    _ticker?.cancel();
    _volumeTimer?.cancel();
    _vibrateTimer?.cancel();
    _settingsSub?.cancel();
    _player.dispose();
    super.dispose();
  }

  String _fmt(Duration d) {
    final h = d.inHours;
    final m = d.inMinutes.remainder(60);
    final s = d.inSeconds.remainder(60);
    final mm = m.toString().padLeft(2, '0');
    final ss = s.toString().padLeft(2, '0');
    return h > 0 ? '$h:$mm:$ss' : '$mm:$ss';
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final left = _endAt != null
        ? _endAt!.difference(DateTime.now())
        : (_remaining ?? _selected);

    if (_ringing) {
      return Container(
        color: cs.primaryContainer,
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.timer, size: 64, color: cs.onPrimaryContainer),
              const SizedBox(height: 16),
              Text('タイマー終了', style: Theme.of(context).textTheme.headlineMedium),
              const SizedBox(height: 32),
              FilledButton(
                onPressed: () {
                  _stopRinging();
                  _reset();
                },
                child: const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 32, vertical: 12),
                  child: Text('停止'),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 24),
            child: Text(
              _fmt(left < Duration.zero ? Duration.zero : left),
              style: Theme.of(context).textTheme.displayLarge,
            ),
          ),
        ),
        if (_endAt == null && _remaining == null) ...[
          Text('よく使う長さ', style: Theme.of(context).textTheme.labelLarge),
          Wrap(
            spacing: 8,
            children: [
              for (final m in timerQuickPicks)
                ChoiceChip(
                  label: Text('$m分'),
                  selected: _selected.inMinutes == m,
                  onSelected: (_) => setState(() => _selected = Duration(minutes: m)),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton(
                icon: const Icon(Icons.remove_circle_outline),
                onPressed: () => setState(() {
                  final m = (_selected.inMinutes - 1).clamp(1, 180);
                  _selected = Duration(minutes: m);
                }),
              ),
              Text('${_selected.inMinutes}分'),
              IconButton(
                icon: const Icon(Icons.add_circle_outline),
                onPressed: () => setState(() {
                  final m = (_selected.inMinutes + 1).clamp(1, 180);
                  _selected = Duration(minutes: m);
                }),
              ),
            ],
          ),
        ],
        const SizedBox(height: 24),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (_endAt != null || _remaining != null) ...[
              OutlinedButton(onPressed: _reset, child: const Text('リセット')),
              const SizedBox(width: 16),
              OutlinedButton(onPressed: _addMinute, child: const Text('+1分')),
              const SizedBox(width: 16),
            ],
            FilledButton(
              onPressed: _running ? _pause : _start,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
                child: Text(_running ? '一時停止' : (_remaining != null ? '再開' : '開始')),
              ),
            ),
          ],
        ),
        const Divider(height: 40),
        Text('設定', style: Theme.of(context).textTheme.labelLarge),
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.music_note_outlined),
          title: Text(_settings.timerSoundName ?? '音が選ばれていません'),
          trailing: TextButton(onPressed: _configureSound, child: const Text('選ぶ')),
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('徐々に音量を上げる'),
          value: _settings.timerGradualVolume,
          onChanged: (v) =>
              _settingsRepo.save(_settings.copyWith(timerGradualVolume: v)),
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('バイブレーション'),
          value: _settings.timerVibrate,
          onChanged: (v) => _settingsRepo.save(_settings.copyWith(timerVibrate: v)),
        ),
      ],
    );
  }
}
