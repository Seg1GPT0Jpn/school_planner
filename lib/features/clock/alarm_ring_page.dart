/// アラームが鳴っているときの画面
library;

import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/services.dart'
    show HapticFeedback, KeyDownEvent, LogicalKeyboardKey;
import 'package:material_ui/material_ui.dart';

import '../notifications/notification_service.dart';
import '../weather/weather_models.dart';
import '../weather/weather_service.dart';
import 'alarm_ring_state.dart';
import 'alarm_repository.dart';
import 'clock_models.dart';

class AlarmRingPage extends StatefulWidget {
  const AlarmRingPage({super.key, required this.alarmId});

  final String alarmId;

  @override
  State<AlarmRingPage> createState() => _AlarmRingPageState();
}

class _AlarmRingPageState extends State<AlarmRingPage> {
  Alarm? _alarm;
  bool _loading = true;
  bool _dismissed = false;

  final _player = AudioPlayer();
  Timer? _volumeTimer;
  Timer? _vibrateTimer;
  Timer? _autoDismissTimer;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    // アラームの一覧（ふだん画面で使うものと同じ Firestore コレクション）から
    // この ID のものだけ探す
    final list = await AlarmRepository(uid: uid).watch().first;
    Alarm? found;
    for (final a in list) {
      if (a.id == widget.alarmId) found = a;
    }
    if (!mounted) return;
    setState(() {
      _alarm = found;
      _loading = false;
    });
    if (found != null) _startRinging(found);
  }

  Future<void> _startRinging(Alarm a) async {
    if (a.vibrate) {
      _vibrateTimer = Timer.periodic(const Duration(milliseconds: 900), (_) {
        HapticFeedback.vibrate();
      });
    }
    if (a.soundPath != null) {
      try {
        await _player.setReleaseMode(ReleaseMode.loop);
        await _player.setAudioContext(
          AudioContext(
            android: const AudioContextAndroid(
              isSpeakerphoneOn: true,
              stayAwake: true,
              contentType: AndroidContentType.sonification,
              usageType: AndroidUsageType.alarm,
              audioFocus: AndroidAudioFocus.gain,
            ),
            iOS: AudioContextIOS(
              category: AVAudioSessionCategory.playback,
              options: const {AVAudioSessionOptions.duckOthers},
            ),
          ),
        );
        final startVolume = a.gradualVolume ? 0.15 : a.volume;
        await _player.setVolume(startVolume);
        await _player.play(DeviceFileSource(a.soundPath!));
        if (a.gradualVolume) {
          var v = startVolume;
          _volumeTimer = Timer.periodic(const Duration(seconds: 3), (t) {
            v = (v + 0.1).clamp(0, a.volume);
            _player.setVolume(v);
            if (v >= a.volume) t.cancel();
          });
        }
      } catch (_) {
        // 音の再生に失敗しても、バイブレーションと画面表示は続ける
      }
    }
    _autoDismissTimer = Timer(
      Duration(minutes: a.dismissAfterMinutes),
      () => _dismiss(),
    );
  }

  Future<void> _stopSound() async {
    _volumeTimer?.cancel();
    _vibrateTimer?.cancel();
    _autoDismissTimer?.cancel();
    try {
      await _player.stop();
    } catch (_) {}
  }

  Future<void> _dismiss() async {
    if (_dismissed) return;
    _dismissed = true;
    await _stopSound();
    final a = _alarm;
    if (a?.id != null) {
      await NotificationService.instance.cancelAlarm(a!.id!);
    }
    alarmRingState.clear();
    if (mounted) Navigator.of(context).maybePop();
  }

  Future<void> _snooze() async {
    if (_dismissed) return;
    _dismissed = true;
    await _stopSound();
    final a = _alarm;
    if (a?.id != null) {
      await NotificationService.instance.cancelAlarm(a!.id!);
      await NotificationService.instance.scheduleOneOff(
        id: NotificationService.instance.alarmNotificationId(a.id!, weekday: 0),
        title: 'スヌーズ：${a.displayLabel}',
        body: 'アラームの時間です',
        at: DateTime.now().add(Duration(minutes: a.snoozeMinutes)),
      );
    }
    alarmRingState.clear();
    if (mounted) Navigator.of(context).maybePop();
  }

  /// 鳴動中の音量ボタン（アプリがいちばん手前にあるときだけ拾える）
  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    final a = _alarm;
    if (a == null || event is! KeyDownEvent) return KeyEventResult.ignored;
    final isVolumeKey =
        event.logicalKey == LogicalKeyboardKey.audioVolumeUp ||
        event.logicalKey == LogicalKeyboardKey.audioVolumeDown;
    if (!isVolumeKey) return KeyEventResult.ignored;
    switch (a.volumeButtonAction) {
      case AlarmVolumeButtonAction.adjustVolume:
        return KeyEventResult.ignored; // ふつうの音量調節として通す
      case AlarmVolumeButtonAction.snooze:
        _snooze();
        return KeyEventResult.handled;
      case AlarmVolumeButtonAction.stop:
        _dismiss();
        return KeyEventResult.handled;
      case AlarmVolumeButtonAction.doNothing:
        return KeyEventResult.handled;
    }
  }

  @override
  void dispose() {
    _volumeTimer?.cancel();
    _vibrateTimer?.cancel();
    _autoDismissTimer?.cancel();
    _player.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final now = DateTime.now();
    final a = _alarm;

    return PopScope(
      canPop: false,
      child: Focus(
        autofocus: true,
        onKeyEvent: _onKey,
        child: Scaffold(
          backgroundColor: cs.primaryContainer,
          body: SafeArea(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          a?.kind == AlarmKind.wakeUp
                              ? Icons.wb_sunny_outlined
                              : Icons.alarm,
                          size: 64,
                          color: cs.onPrimaryContainer,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          '${now.hour.toString().padLeft(2, '0')}:'
                          '${now.minute.toString().padLeft(2, '0')}',
                          style: tt.displayLarge?.copyWith(
                            color: cs.onPrimaryContainer,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          a?.displayLabel ?? 'アラーム',
                          style: tt.headlineSmall?.copyWith(
                            color: cs.onPrimaryContainer,
                          ),
                        ),
                        if (a?.soundPath == null) ...[
                          const SizedBox(height: 8),
                          Text(
                            '音が選ばれていません（設定から選べます）',
                            style: tt.bodySmall?.copyWith(
                              color: cs.onPrimaryContainer.withValues(alpha: 0.7),
                            ),
                          ),
                        ],
                        if (a?.includeWeather ?? false) ...[
                          const SizedBox(height: 16),
                          const _WeatherStrip(),
                        ],
                        const SizedBox(height: 48),
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton(
                                onPressed: _snooze,
                                style: OutlinedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(vertical: 18),
                                  foregroundColor: cs.onPrimaryContainer,
                                  side: BorderSide(color: cs.onPrimaryContainer),
                                ),
                                child: Text('スヌーズ（${a?.snoozeMinutes ?? 5}分）'),
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: FilledButton(
                                onPressed: _dismiss,
                                style: FilledButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(vertical: 18),
                                ),
                                child: const Text('止める'),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
          ),
        ),
      ),
    );
  }
}

class _WeatherStrip extends StatelessWidget {
  const _WeatherStrip();

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return FutureBuilder<WeatherBundle>(
      future: WeatherService.instance.load(),
      builder: (context, snap) {
        final f = (snap.data ?? WeatherService.instance.cached)?.forecast;
        final c = f?.current;
        final today = f?.dayOf(DateTime.now());
        if (c == null) return const SizedBox.shrink();
        final w = weatherOf(c.code, night: !c.isDay);
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: cs.onPrimaryContainer.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            '${w.icon} ${w.label}　'
            '${c.temperature == null ? '' : '${c.temperature!.round()}°'}'
            '${today == null ? '' : '（最高${today.max?.round() ?? '—'}° / 最低${today.min?.round() ?? '—'}°）'}',
            style: TextStyle(color: cs.onPrimaryContainer),
          ),
        );
      },
    );
  }
}
