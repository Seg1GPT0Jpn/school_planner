/// チューナー・解析画面に埋め込む、コンパクトなメトロノーム
///
/// 本格的な設定（リズムパターン・テンポ自動変化・プリセット保存など）は
/// 「練習ツール」内のメトロノーム画面で行う想定。ここでは、音程を聞きながら
/// すぐ使える最小限の操作（拍子・BPM・開始/停止）だけを提供する。
library;

import 'dart:async';
import 'dart:typed_data';

import 'package:audioplayers/audioplayers.dart';
import 'package:material_ui/material_ui.dart';

import '../tone_synth.dart';
import 'accent.dart';
import 'bpm_input_dialog.dart';
import 'metronome_engine.dart';
import 'rhythm_pattern.dart';
import 'time_signature.dart';

class MiniMetronome extends StatefulWidget {
  const MiniMetronome({super.key});

  @override
  State<MiniMetronome> createState() => _MiniMetronomeState();
}

class _MiniMetronomeState extends State<MiniMetronome> {
  late final MetronomeEngine _engine = MetronomeEngine(
    onBeat: _handleBeat,
    onStop: () {
      if (mounted) setState(() => _running = false);
    },
  );

  int _bpm = 100;
  TimeSignature _timeSignature = commonTimeSignatures[2]; // 4/4
  bool _running = false;
  bool _expanded = false;
  BeatEvent? _lastEvent;
  final _taps = <DateTime>[];

  final Map<String, Uint8List> _clickCache = {};
  final List<AudioPlayer> _playerPool = List.generate(4, (_) => AudioPlayer());
  int _playerIndex = 0;

  static const _timbre = ClickTimbre.classic;

  @override
  void initState() {
    super.initState();
    for (final p in _playerPool) {
      unawaited(p.setPlayerMode(PlayerMode.lowLatency));
    }
  }

  @override
  void dispose() {
    _engine.stop();
    for (final p in _playerPool) {
      unawaited(p.dispose());
    }
    super.dispose();
  }

  // --- 音のキャッシュ（メトロノーム本体タブと同じ方式） ---

  String _pitchVariantFor(BeatEvent e) {
    if (e.isCountIn) return 'countIn';
    if (e.beatIndex == 0 && e.slotIndex == 0) return 'bar';
    if (e.isGroupStart) return 'group';
    if (e.slotIndex == 0) return 'beat';
    return 'sub';
  }

  double _pitchMultiplierFor(String variant) => switch (variant) {
    'countIn' => 1.3,
    'bar' => 1.6,
    'group' => 1.3,
    'beat' => 1.0,
    'sub' => 0.7,
    _ => 1.0,
  };

  Uint8List _clickFor(BeatEvent e) {
    final variant = _pitchVariantFor(e);
    final key = '${_timbre.name}_${variant}_${e.level.name}';
    return _clickCache.putIfAbsent(
      key,
      () => generateTimbredClick(
        _timbre,
        gain: e.level.gain,
        pitchMultiplier: _pitchMultiplierFor(variant),
      ),
    );
  }

  void _playClick(BeatEvent e) {
    if (e.muted || e.level == DynamicLevel.mute) return;
    final bytes = _clickFor(e);
    final player = _playerPool[_playerIndex];
    _playerIndex = (_playerIndex + 1) % _playerPool.length;
    unawaited(player.play(BytesSource(bytes)));
  }

  void _handleBeat(BeatEvent e) {
    _playClick(e);
    if (!mounted) return;
    setState(() => _lastEvent = e);
  }

  void _applyConfig() {
    _engine
      ..startBpm = _bpm
      ..timeSignature = _timeSignature
      ..pattern = RhythmPattern(beats: _timeSignature.beats, subdivision: 1);
  }

  void _restartIfRunning() {
    if (!_running) return;
    _engine.stop();
    _applyConfig();
    _engine.start();
  }

  void _toggle() {
    if (_running) {
      _engine.stop();
      setState(() {
        _running = false;
        _lastEvent = null;
      });
    } else {
      _applyConfig();
      _engine.start();
      setState(() => _running = true);
    }
  }

  void _setBpm(int v) {
    setState(() => _bpm = v.clamp(30, 300).toInt());
    _restartIfRunning();
  }

  void _setTimeSignature(TimeSignature ts) {
    setState(() => _timeSignature = ts);
    _restartIfRunning();
  }

  Future<void> _openBpmInput() async {
    final v = await showBpmInputDialog(context, current: _bpm);
    if (v != null) _setBpm(v);
  }

  void _tapTempo() {
    final now = DateTime.now();
    _taps.removeWhere((t) => now.difference(t) > const Duration(seconds: 2));
    _taps.add(now);
    if (_taps.length >= 2) {
      final intervals = [
        for (var i = 1; i < _taps.length; i++)
          _taps[i].difference(_taps[i - 1]).inMilliseconds,
      ];
      final avg = intervals.reduce((a, b) => a + b) / intervals.length;
      if (avg > 0) _setBpm((60000 / avg).round());
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final e = _lastEvent;
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.av_timer, color: cs.primary),
                const SizedBox(width: 8),
                Text('メトロノーム', style: Theme.of(context).textTheme.labelLarge),
                const Spacer(),
                IconButton(
                  visualDensity: VisualDensity.compact,
                  onPressed: () => setState(() => _expanded = !_expanded),
                  icon: Icon(_expanded ? Icons.expand_less : Icons.expand_more),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                IconButton.filledTonal(
                  visualDensity: VisualDensity.compact,
                  onPressed: () => _setBpm(_bpm - 1),
                  icon: const Icon(Icons.remove),
                ),
                Expanded(
                  child: InkWell(
                    onTap: _openBpmInput,
                    child: Column(
                      children: [
                        Text(
                          '$_bpm',
                          style: Theme.of(
                            context,
                          ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
                        ),
                        const Text('BPM（タップで入力）', style: TextStyle(fontSize: 10)),
                      ],
                    ),
                  ),
                ),
                IconButton.filledTonal(
                  visualDensity: VisualDensity.compact,
                  onPressed: () => _setBpm(_bpm + 1),
                  icon: const Icon(Icons.add),
                ),
                const SizedBox(width: 12),
                FilledButton.icon(
                  onPressed: _toggle,
                  icon: Icon(_running ? Icons.stop : Icons.play_arrow),
                  label: Text(_running ? '停止' : '開始'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              children: [
                for (var i = 0; i < _timeSignature.beats; i++)
                  Container(
                    width: 14,
                    height: 14,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: (e != null && !e.isCountIn && i == e.beatIndex)
                          ? (i == 0 ? cs.error : cs.primary)
                          : cs.outlineVariant,
                    ),
                  ),
              ],
            ),
            if (_expanded) ...[
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _tapTempo,
                      icon: const Icon(Icons.touch_app_outlined),
                      label: const Text('TAP（連打でテンポ設定）'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text('拍子', style: Theme.of(context).textTheme.labelMedium),
              const SizedBox(height: 6),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  for (final ts in commonTimeSignatures)
                    ChoiceChip(
                      label: Text(ts.display),
                      selected: _timeSignature == ts,
                      onSelected: (_) => _setTimeSignature(ts),
                    ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}
