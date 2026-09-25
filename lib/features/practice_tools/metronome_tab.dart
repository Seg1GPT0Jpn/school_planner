/// メトロノーム
///
/// タイミングは「絶対時刻方式」のエンジン（metronome/metronome_engine.dart）で
/// 管理していて、Timer.periodicのコールバック時刻そのものを拍の基準にしない
/// ことで、鳴らし続けてもズレが積み重ならないようにしている。
///
/// ・拍子：2〜12拍子、任意のグループ分け（7/8の2+2+3など）
/// ・リズムパターンエディタ：拍をさらに分割し、マスごとにON/OFF・強弱を編集
/// ・カウントイン／無音小節（リズムトレーナー）／ループ／自動テンポ変化
/// ・曲ごとのプリセット保存
/// ・ジェスチャー操作（タップ＝開始/停止、長押し＝タップテンポ、スワイプ＝BPM調整）
library;

import 'dart:async';
import 'dart:typed_data';

import 'package:audioplayers/audioplayers.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/services.dart' show SystemChrome, SystemUiMode, DeviceOrientation;
import 'package:material_ui/material_ui.dart';

import '../review/review_widgets.dart';
import 'metronome/accent.dart';
import 'metronome/bpm_input_dialog.dart';
import 'metronome/metronome_engine.dart';
import 'metronome/preset.dart';
import 'metronome/preset_repository.dart';
import 'metronome/rhythm_pattern.dart';
import 'metronome/tempo_marking.dart';
import 'metronome/tempo_ramp.dart';
import 'metronome/time_signature.dart';
import 'metronome/stage_view.dart';
import 'tone_synth.dart';

class MetronomeTab extends StatefulWidget {
  const MetronomeTab({super.key});

  @override
  State<MetronomeTab> createState() => _MetronomeTabState();
}

class _MetronomeTabState extends State<MetronomeTab>
    with TickerProviderStateMixin {
  late final MetronomeEngine _engine = MetronomeEngine(
    onBeat: _handleBeat,
    onStop: () {
      if (mounted) setState(() => _running = false);
    },
  );

  int _bpm = 100;
  TimeSignature _timeSignature = commonTimeSignatures[2];
  RhythmPattern _pattern = RhythmPattern(beats: 4, subdivision: 1);
  ClickTimbre _timbre = ClickTimbre.classic;
  int _countInBars = 0;
  bool _muteEnabled = false;
  int _muteOnBars = 4;
  int _muteOffBars = 2;
  TempoRamp _tempoRamp = const TempoRamp();
  int? _loopStartBar;
  int? _loopEndBar;
  bool _loopRepeat = false;

  bool _running = false;
  BeatEvent? _lastEvent;
  bool _settingsExpanded = false;
  bool _stageMode = false;

  final Map<String, Uint8List> _clickCache = {};
  final List<AudioPlayer> _playerPool = List.generate(4, (_) => AudioPlayer());
  int _playerIndex = 0;

  final _taps = <DateTime>[];

  late final AnimationController _pendulum = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 500),
  );
  Animation<double> _swing = const AlwaysStoppedAnimation(0);
  bool _swingToRight = true;

  bool _screenFlashEnabled = true;
  late final AnimationController _flash = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 250),
  );
  Animation<double> _flashOpacity = const AlwaysStoppedAnimation(0);
  Color _flashColor = Colors.white;

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
    _pendulum.dispose();
    _flash.dispose();
    for (final p in _playerPool) {
      unawaited(p.dispose());
    }
    if (_stageMode) {
      unawaited(SystemChrome.setPreferredOrientations(DeviceOrientation.values));
      unawaited(SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge));
    }
    super.dispose();
  }

  // --- 音のキャッシュ ---

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
    if (e.isMainBeat && !e.muted) {
      _swingPendulum();
    }
    if (_screenFlashEnabled && !e.muted) {
      _flashScreen(isDownbeat: e.beatIndex == 0 && e.slotIndex == 0);
    }
  }

  void _flashScreen({required bool isDownbeat}) {
    final cs = Theme.of(context).colorScheme;
    _flashColor = isDownbeat ? cs.error : cs.primary;
    _flashOpacity = Tween<double>(begin: isDownbeat ? 0.55 : 0.3, end: 0.0).animate(
      CurvedAnimation(parent: _flash, curve: Curves.easeOut),
    );
    _flash.forward(from: 0);
  }

  void _swingPendulum() {
    final intervalMs = (60000 / (_lastEvent?.currentBpm ?? _bpm)).round();
    _pendulum.duration = Duration(milliseconds: intervalMs);
    final from = _swingToRight ? -1.0 : 1.0;
    final to = _swingToRight ? 1.0 : -1.0;
    _swing = Tween<double>(
      begin: from,
      end: to,
    ).animate(CurvedAnimation(parent: _pendulum, curve: Curves.easeInOut));
    _pendulum.forward(from: 0);
    _swingToRight = !_swingToRight;
  }

  // --- 再生制御 ---

  void _applyEngineConfig() {
    _engine.startBpm = _bpm;
    _engine.timeSignature = _timeSignature;
    _engine.pattern = _pattern;
    _engine.countInBars = _countInBars;
    _engine.muteEnabled = _muteEnabled;
    _engine.muteOnBars = _muteOnBars;
    _engine.muteOffBars = _muteOffBars;
    _engine.tempoRamp = _tempoRamp;
    _engine.loopStartBar = _loopStartBar;
    _engine.loopEndBar = _loopEndBar;
    _engine.loopRepeat = _loopRepeat;
  }

  void _start() {
    _applyEngineConfig();
    setState(() {
      _running = true;
      _lastEvent = null;
    });
    _engine.start();
  }

  void _stop() {
    _engine.stop();
    setState(() {
      _running = false;
      _lastEvent = null;
    });
  }

  void _restartIfRunning() {
    if (_running) {
      _engine.stop();
      _start();
    }
  }

  void _setBpm(int v) {
    setState(() => _bpm = v.clamp(30, 300).toInt());
    _restartIfRunning();
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

  Future<void> _openBpmInput() async {
    final v = await showBpmInputDialog(context, current: _bpm);
    if (v != null) _setBpm(v);
  }

  void _showTempoMarkingTable() {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) {
        final cs = Theme.of(context).colorScheme;
        final current = tempoMarkingFor(_bpm);
        return SafeArea(
          child: ListView(
            shrinkWrap: true,
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            children: [
              Text('速度記号の目安', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 4),
              Text(
                'チューナー等の裏面によくある対応表です。曲についている速度記号から、'
                'だいたいのBPMを決めるときの目安にしてください。',
                style: TextStyle(color: cs.outline, fontSize: 12),
              ),
              const SizedBox(height: 8),
              for (final m in tempoMarkings)
                ListTile(
                  selected: m == current,
                  selectedTileColor: cs.primaryContainer,
                  dense: true,
                  title: Text('${m.name}（${m.reading}）'),
                  subtitle: Text('${m.description}　${m.minBpm}〜${m.maxBpm} BPM'),
                  trailing: m == current ? Icon(Icons.check, color: cs.primary) : null,
                  onTap: () {
                    Navigator.pop(context);
                    _setBpm(((m.minBpm + m.maxBpm) / 2).round());
                  },
                ),
            ],
          ),
        );
      },
    );
  }

  void _setTimeSignature(TimeSignature ts) {
    setState(() {
      _timeSignature = ts;
      _pattern = _pattern.withBeats(ts.beats);
    });
    _restartIfRunning();
  }

  void _setSubdivision(int sub) {
    setState(() => _pattern = _pattern.withSubdivision(sub));
    _restartIfRunning();
  }

  void _applyAccentPreset(AccentPreset preset) {
    setState(() {
      _pattern = _pattern.withAccentPreset(
        preset,
        isGroupStart: _timeSignature.isGroupStart,
      );
    });
    _restartIfRunning();
  }

  void _toggleStageMode(bool on) {
    setState(() => _stageMode = on);
    if (on) {
      unawaited(SystemChrome.setPreferredOrientations([
        DeviceOrientation.landscapeLeft,
        DeviceOrientation.landscapeRight,
      ]));
      unawaited(SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky));
    } else {
      unawaited(SystemChrome.setPreferredOrientations(DeviceOrientation.values));
      unawaited(SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge));
    }
  }

  // --- ジェスチャー ---

  void _onHorizontalSwipe(DragEndDetails d) {
    final v = d.primaryVelocity ?? 0;
    if (v.abs() < 150) return;
    _setBpm(_bpm + (v > 0 ? -1 : 1));
  }

  void _onVerticalSwipe(DragEndDetails d) {
    final v = d.primaryVelocity ?? 0;
    if (v.abs() < 150) return;
    _setBpm(_bpm + (v > 0 ? -5 : 5));
  }

  // --- プリセット ---

  Future<void> _savePresetDialog() async {
    final controller = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('プリセットとして保存'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(labelText: '曲名・メモ'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c), child: const Text('キャンセル')),
          FilledButton(
            onPressed: () => Navigator.pop(c, controller.text.trim()),
            child: const Text('保存'),
          ),
        ],
      ),
    );
    if (name == null || name.isEmpty) return;
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    final repo = MetronomePresetRepository(uid: uid);
    await repo.save(
      MetronomePreset(
        id: repo.newId(),
        name: name,
        bpm: _bpm,
        timeSignature: _timeSignature,
        pattern: _pattern,
        timbre: _timbre,
        countInBars: _countInBars,
        muteEnabled: _muteEnabled,
        muteOnBars: _muteOnBars,
        muteOffBars: _muteOffBars,
        tempoRamp: _tempoRamp,
        updatedAt: DateTime.now(),
      ),
    );
  }

  void _loadPreset(MetronomePreset p) {
    setState(() {
      _bpm = p.bpm;
      _timeSignature = p.timeSignature;
      _pattern = p.pattern;
      _timbre = p.timbre;
      _countInBars = p.countInBars;
      _muteEnabled = p.muteEnabled;
      _muteOnBars = p.muteOnBars;
      _muteOffBars = p.muteOffBars;
      _tempoRamp = p.tempoRamp;
    });
    _restartIfRunning();
  }

  Widget _flashOverlay() => Positioned.fill(
    child: IgnorePointer(
      child: AnimatedBuilder(
        animation: _flashOpacity,
        builder: (context, _) => Container(
          color: _flashColor.withValues(alpha: _flashOpacity.value),
        ),
      ),
    ),
  );

  @override
  Widget build(BuildContext context) {
    if (_stageMode) {
      return Stack(
        children: [
          MetronomeStageView(
            bpm: _lastEvent?.currentBpm ?? _bpm,
            timeSignature: _timeSignature,
            currentBeat: _lastEvent,
            running: _running,
            swing: _swing,
            onExit: () => _toggleStageMode(false),
            onToggle: _running ? _stop : _start,
          ),
          _flashOverlay(),
        ],
      );
    }
    final cs = Theme.of(context).colorScheme;
    return Stack(
      children: [
        _mainContent(cs),
        _flashOverlay(),
      ],
    );
  }

  Widget _mainContent(ColorScheme cs) {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        GestureDetector(
          onTap: () => _running ? _stop() : _start(),
          onLongPress: _tapTempo,
          onHorizontalDragEnd: _onHorizontalSwipe,
          onVerticalDragEnd: _onVerticalSwipe,
          child: Column(
            children: [
              Text(
                '$_bpm',
                textAlign: TextAlign.center,
                style: Theme.of(
                  context,
                ).textTheme.displayLarge?.copyWith(fontWeight: FontWeight.bold),
              ),
              Text('BPM', textAlign: TextAlign.center, style: TextStyle(color: cs.outline)),
              const SizedBox(height: 4),
              Faint(
                _running
                    ? 'タップで停止・上下スワイプで±5・左右スワイプで±1'
                    : 'タップで開始・スワイプでBPM調整',
              ),
            ],
          ),
        ),
        const SizedBox(height: 4),
        Center(
          child: InkWell(
            borderRadius: BorderRadius.circular(8),
            onTap: _showTempoMarkingTable,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '${tempoMarkingFor(_bpm).name}（${tempoMarkingFor(_bpm).description}）',
                    style: TextStyle(color: cs.primary, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(width: 4),
                  Icon(Icons.info_outline, size: 16, color: cs.primary),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            IconButton.filledTonal(
              onPressed: () => _setBpm(_bpm - 5),
              icon: const Icon(Icons.remove),
            ),
            const SizedBox(width: 8),
            IconButton.filledTonal(
              tooltip: 'BPMを数値で入力',
              onPressed: _openBpmInput,
              icon: const Icon(Icons.edit_outlined),
            ),
            const SizedBox(width: 8),
            OutlinedButton(
              onPressed: _tapTempo,
              child: const Text('TAP', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
            const SizedBox(width: 8),
            IconButton.filledTonal(
              onPressed: () => _setBpm(_bpm + 5),
              icon: const Icon(Icons.add),
            ),
          ],
        ),
        Slider(
          value: _bpm.toDouble(),
          min: 30,
          max: 300,
          onChanged: (v) => _setBpm(v.round()),
        ),
        const SizedBox(height: 12),
        Center(
          child: SizedBox(
            height: 110,
            width: 160,
            child: AnimatedBuilder(
              animation: _swing,
              builder: (context, _) => CustomPaint(
                painter: _PendulumPainter(
                  angle: _swing.value,
                  color: cs.primary,
                  baseColor: cs.outlineVariant,
                ),
              ),
            ),
          ),
        ),
        if (_lastEvent != null) ...[
          const SizedBox(height: 4),
          Center(
            child: Text(
              _lastEvent!.isCountIn
                  ? 'カウントイン'
                  : '小節 ${_lastEvent!.barIndex + 1}　拍 ${_lastEvent!.beatIndex + 1}/${_timeSignature.beats}',
              style: TextStyle(color: cs.outline),
            ),
          ),
        ],
        const SizedBox(height: 16),
        _beatDots(cs),
        const SizedBox(height: 16),
        Center(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              FilledButton.icon(
                onPressed: _running ? _stop : _start,
                icon: Icon(_running ? Icons.stop : Icons.play_arrow),
                label: Text(_running ? '止める' : '開始'),
              ),
              const SizedBox(width: 8),
              IconButton(
                tooltip: 'ステージ表示',
                onPressed: () => _toggleStageMode(true),
                icon: const Icon(Icons.stay_current_landscape_outlined),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        _SettingsSection(
          expanded: _settingsExpanded,
          onExpandedChanged: (v) => setState(() => _settingsExpanded = v),
          timeSignature: _timeSignature,
          onTimeSignatureChanged: _setTimeSignature,
          subdivision: _pattern.subdivision,
          onSubdivisionChanged: _setSubdivision,
          pattern: _pattern,
          onPatternChanged: (p) {
            setState(() => _pattern = p);
            _restartIfRunning();
          },
          onAccentPreset: _applyAccentPreset,
          timbre: _timbre,
          onTimbreChanged: (t) {
            setState(() => _timbre = t);
            _clickCache.clear();
          },
          screenFlashEnabled: _screenFlashEnabled,
          onScreenFlashChanged: (v) => setState(() => _screenFlashEnabled = v),
          countInBars: _countInBars,
          onCountInChanged: (v) => setState(() => _countInBars = v),
          muteEnabled: _muteEnabled,
          onMuteEnabledChanged: (v) => setState(() => _muteEnabled = v),
          muteOnBars: _muteOnBars,
          onMuteOnBarsChanged: (v) => setState(() => _muteOnBars = v),
          muteOffBars: _muteOffBars,
          onMuteOffBarsChanged: (v) => setState(() => _muteOffBars = v),
          tempoRamp: _tempoRamp,
          onTempoRampChanged: (r) => setState(() => _tempoRamp = r),
          loopStartBar: _loopStartBar,
          loopEndBar: _loopEndBar,
          loopRepeat: _loopRepeat,
          onLoopChanged: (start, end, repeat) => setState(() {
            _loopStartBar = start;
            _loopEndBar = end;
            _loopRepeat = repeat;
          }),
          onSavePreset: _savePresetDialog,
          onLoadPreset: _loadPreset,
        ),
      ],
    );
  }

  Widget _beatDots(ColorScheme cs) {
    final e = _lastEvent;
    return Wrap(
      alignment: WrapAlignment.center,
      spacing: 6,
      runSpacing: 6,
      children: [
        for (var i = 0; i < _timeSignature.beats; i++)
          Container(
            width: 16,
            height: 16,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: (e != null && !e.isCountIn && i == e.beatIndex && e.slotIndex == 0)
                  ? (i == 0
                        ? cs.error
                        : (_timeSignature.isGroupStart(i) ? cs.tertiary : cs.primary))
                  : cs.outlineVariant,
            ),
          ),
      ],
    );
  }
}

class _PendulumPainter extends CustomPainter {
  _PendulumPainter({required this.angle, required this.color, required this.baseColor});
  final double angle;
  final Color color;
  final Color baseColor;
  static const _maxAngle = 0.55;

  @override
  void paint(Canvas canvas, Size size) {
    final pivot = Offset(size.width / 2, size.height - 8);
    final needleLength = size.height - 20;
    final basePaint = Paint()..color = baseColor;
    final basePath = Path()
      ..moveTo(pivot.dx - 30, size.height)
      ..lineTo(pivot.dx + 30, size.height)
      ..lineTo(pivot.dx + 8, pivot.dy)
      ..lineTo(pivot.dx - 8, pivot.dy)
      ..close();
    canvas.drawPath(basePath, basePaint);
    canvas.save();
    canvas.translate(pivot.dx, pivot.dy);
    canvas.rotate(angle * _maxAngle);
    final needlePaint = Paint()
      ..color = color
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(Offset.zero, Offset(0, -needleLength), needlePaint);
    canvas.drawCircle(Offset(0, -needleLength * 0.7), 6, Paint()..color = color);
    canvas.restore();
    canvas.drawCircle(pivot, 5, Paint()..color = color);
  }

  @override
  bool shouldRepaint(covariant _PendulumPainter oldDelegate) =>
      oldDelegate.angle != angle || oldDelegate.color != color;
}

class _SettingsSection extends StatelessWidget {
  const _SettingsSection({
    required this.expanded,
    required this.onExpandedChanged,
    required this.timeSignature,
    required this.onTimeSignatureChanged,
    required this.subdivision,
    required this.onSubdivisionChanged,
    required this.pattern,
    required this.onPatternChanged,
    required this.onAccentPreset,
    required this.timbre,
    required this.onTimbreChanged,
    required this.screenFlashEnabled,
    required this.onScreenFlashChanged,
    required this.countInBars,
    required this.onCountInChanged,
    required this.muteEnabled,
    required this.onMuteEnabledChanged,
    required this.muteOnBars,
    required this.onMuteOnBarsChanged,
    required this.muteOffBars,
    required this.onMuteOffBarsChanged,
    required this.tempoRamp,
    required this.onTempoRampChanged,
    required this.loopStartBar,
    required this.loopEndBar,
    required this.loopRepeat,
    required this.onLoopChanged,
    required this.onSavePreset,
    required this.onLoadPreset,
  });

  final bool expanded;
  final ValueChanged<bool> onExpandedChanged;
  final TimeSignature timeSignature;
  final ValueChanged<TimeSignature> onTimeSignatureChanged;
  final int subdivision;
  final ValueChanged<int> onSubdivisionChanged;
  final RhythmPattern pattern;
  final ValueChanged<RhythmPattern> onPatternChanged;
  final ValueChanged<AccentPreset> onAccentPreset;
  final ClickTimbre timbre;
  final ValueChanged<ClickTimbre> onTimbreChanged;
  final bool screenFlashEnabled;
  final ValueChanged<bool> onScreenFlashChanged;
  final int countInBars;
  final ValueChanged<int> onCountInChanged;
  final bool muteEnabled;
  final ValueChanged<bool> onMuteEnabledChanged;
  final int muteOnBars;
  final ValueChanged<int> onMuteOnBarsChanged;
  final int muteOffBars;
  final ValueChanged<int> onMuteOffBarsChanged;
  final TempoRamp tempoRamp;
  final ValueChanged<TempoRamp> onTempoRampChanged;
  final int? loopStartBar;
  final int? loopEndBar;
  final bool loopRepeat;
  final void Function(int? start, int? end, bool repeat) onLoopChanged;
  final VoidCallback onSavePreset;
  final ValueChanged<MetronomePreset> onLoadPreset;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      child: Column(
        children: [
          ListTile(
            leading: const Icon(Icons.tune),
            title: const Text('メトロノームの設定'),
            subtitle: Text('${timeSignature.display}・${timbre.label}'),
            trailing: Icon(expanded ? Icons.expand_less : Icons.expand_more),
            onTap: () => onExpandedChanged(!expanded),
          ),
          if (expanded)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('拍子', style: Theme.of(context).textTheme.labelLarge),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final ts in commonTimeSignatures)
                        ChoiceChip(
                          label: Text(ts.display),
                          selected: timeSignature == ts,
                          onSelected: (_) => onTimeSignatureChanged(ts),
                        ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Text('裏打ち（1拍の分割）', style: Theme.of(context).textTheme.labelLarge),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 8,
                    children: [
                      for (final s in const [1, 2, 3, 4])
                        ChoiceChip(
                          label: Text(switch (s) {
                            1 => 'なし',
                            2 => '2連',
                            3 => '3連符',
                            _ => '4連',
                          }),
                          selected: subdivision == s,
                          onSelected: (_) => onSubdivisionChanged(s),
                        ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Text('リズムパターン（タップでON/OFF）', style: Theme.of(context).textTheme.labelLarge),
                  const SizedBox(height: 6),
                  _RhythmGrid(pattern: pattern, onChanged: onPatternChanged),
                  const SizedBox(height: 16),
                  Text('強弱プリセット', style: Theme.of(context).textTheme.labelLarge),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final p in accentPresets)
                        ActionChip(label: Text(p.name), onPressed: () => onAccentPreset(p)),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Text('クリック音', style: Theme.of(context).textTheme.labelLarge),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final t in ClickTimbre.values)
                        ChoiceChip(
                          label: Text(t.label),
                          selected: timbre == t,
                          onSelected: (_) => onTimbreChanged(t),
                        ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('画面フラッシュ'),
                    subtitle: const Text('拍に合わせて画面が光ります（周りの音が大きい合奏中でも見て取れます）'),
                    value: screenFlashEnabled,
                    onChanged: onScreenFlashChanged,
                  ),
                  const SizedBox(height: 16),
                  Text('カウントイン', style: Theme.of(context).textTheme.labelLarge),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 8,
                    children: [
                      for (final n in const [0, 1, 2, 4, 8])
                        ChoiceChip(
                          label: Text(n == 0 ? 'なし' : '$n小節'),
                          selected: countInBars == n,
                          onSelected: (_) => onCountInChanged(n),
                        ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('無音小節（リズムトレーナー）'),
                    subtitle: Text('$muteOnBars小節鳴らして、$muteOffBars小節だけ無音にします'),
                    value: muteEnabled,
                    onChanged: onMuteEnabledChanged,
                  ),
                  if (muteEnabled) ...[
                    Row(
                      children: [
                        const Text('鳴らす　'),
                        Expanded(
                          child: Slider(
                            value: muteOnBars.toDouble(),
                            min: 1,
                            max: 16,
                            divisions: 15,
                            label: '$muteOnBars',
                            onChanged: (v) => onMuteOnBarsChanged(v.round()),
                          ),
                        ),
                      ],
                    ),
                    Row(
                      children: [
                        const Text('無音　　'),
                        Expanded(
                          child: Slider(
                            value: muteOffBars.toDouble(),
                            min: 1,
                            max: 16,
                            divisions: 15,
                            label: '$muteOffBars',
                            onChanged: (v) => onMuteOffBarsChanged(v.round()),
                          ),
                        ),
                      ],
                    ),
                  ],
                  const SizedBox(height: 16),
                  Text('自動テンポ変化', style: Theme.of(context).textTheme.labelLarge),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final m in TempoRampMode.values)
                        ChoiceChip(
                          label: Text(m.label),
                          selected: tempoRamp.mode == m,
                          onSelected: (_) => onTempoRampChanged(tempoRamp.copyWith(mode: m)),
                        ),
                    ],
                  ),
                  if (tempoRamp.mode != TempoRampMode.off) ...[
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        const Text('ステップ　'),
                        Expanded(
                          child: Slider(
                            value: tempoRamp.stepBpm.toDouble(),
                            min: 1,
                            max: 20,
                            divisions: 19,
                            label: '${tempoRamp.stepBpm} BPM',
                            onChanged: (v) =>
                                onTempoRampChanged(tempoRamp.copyWith(stepBpm: v.round())),
                          ),
                        ),
                      ],
                    ),
                    Row(
                      children: [
                        const Text('間隔　　'),
                        Expanded(
                          child: Slider(
                            value: tempoRamp.everyBars.toDouble(),
                            min: 1,
                            max: 16,
                            divisions: 15,
                            label: '${tempoRamp.everyBars}小節ごと',
                            onChanged: (v) =>
                                onTempoRampChanged(tempoRamp.copyWith(everyBars: v.round())),
                          ),
                        ),
                      ],
                    ),
                    Row(
                      children: [
                        const Text('範囲　　'),
                        Expanded(
                          child: RangeSlider(
                            values: RangeValues(
                              tempoRamp.minBpm.toDouble(),
                              tempoRamp.maxBpm.toDouble(),
                            ),
                            min: 30,
                            max: 300,
                            labels: RangeLabels('${tempoRamp.minBpm}', '${tempoRamp.maxBpm}'),
                            onChanged: (v) => onTempoRampChanged(
                              tempoRamp.copyWith(
                                minBpm: v.start.round(),
                                maxBpm: v.end.round(),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                  const SizedBox(height: 16),
                  Text('ループ（練習範囲）', style: Theme.of(context).textTheme.labelLarge),
                  const SizedBox(height: 6),
                  _LoopEditor(
                    startBar: loopStartBar,
                    endBar: loopEndBar,
                    repeat: loopRepeat,
                    onChanged: onLoopChanged,
                  ),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      OutlinedButton.icon(
                        onPressed: onSavePreset,
                        icon: const Icon(Icons.save_outlined),
                        label: const Text('プリセット保存'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  _PresetList(onLoad: onLoadPreset),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _RhythmGrid extends StatelessWidget {
  const _RhythmGrid({required this.pattern, required this.onChanged});
  final RhythmPattern pattern;
  final ValueChanged<RhythmPattern> onChanged;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Column(
      children: [
        for (var b = 0; b < pattern.beats; b++)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 2),
            child: Row(
              children: [
                SizedBox(width: 28, child: Text('${b + 1}')),
                for (var s = 0; s < pattern.subdivision; s++)
                  Padding(
                    padding: const EdgeInsets.only(right: 4),
                    child: GestureDetector(
                      onTap: () {
                        final slot = pattern.slotAt(b, s);
                        onChanged(
                          pattern.withSlot(b, s, slot.copyWith(active: !slot.active)),
                        );
                      },
                      onLongPress: () {
                        final slot = pattern.slotAt(b, s);
                        final next = slot.level == DynamicLevel.f
                            ? DynamicLevel.p
                            : slot.level.louder;
                        onChanged(pattern.withSlot(b, s, slot.copyWith(level: next)));
                      },
                      child: Container(
                        width: 26,
                        height: 26,
                        decoration: BoxDecoration(
                          color: pattern.slotAt(b, s).active
                              ? cs.primary.withValues(
                                  alpha: 0.3 + pattern.slotAt(b, s).level.gain * 0.7,
                                )
                              : cs.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: cs.outlineVariant),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        const SizedBox(height: 4),
        Faint('タップ：ON/OFF　長押し：強弱を1段階上げる'),
      ],
    );
  }
}

class _LoopEditor extends StatefulWidget {
  const _LoopEditor({
    required this.startBar,
    required this.endBar,
    required this.repeat,
    required this.onChanged,
  });
  final int? startBar;
  final int? endBar;
  final bool repeat;
  final void Function(int? start, int? end, bool repeat) onChanged;

  @override
  State<_LoopEditor> createState() => _LoopEditorState();
}

class _LoopEditorState extends State<_LoopEditor> {
  late bool _enabled = widget.endBar != null;
  late final _startController = TextEditingController(
    text: '${(widget.startBar ?? 0) + 1}',
  );
  late final _endController = TextEditingController(
    text: '${(widget.endBar ?? 15) + 1}',
  );

  void _apply() {
    if (!_enabled) {
      widget.onChanged(null, null, false);
      return;
    }
    final start = (int.tryParse(_startController.text) ?? 1) - 1;
    final end = (int.tryParse(_endController.text) ?? 16) - 1;
    widget.onChanged(start.clamp(0, 9999).toInt(), end.clamp(start, 9999).toInt(), widget.repeat);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('範囲を指定する'),
          subtitle: const Text('指定した小節を過ぎると停止（くり返しONならループ）'),
          value: _enabled,
          onChanged: (v) {
            setState(() => _enabled = v);
            _apply();
          },
        ),
        if (_enabled) ...[
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _startController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: '開始小節'),
                  onChanged: (_) => _apply(),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextField(
                  controller: _endController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: '終了小節'),
                  onChanged: (_) => _apply(),
                ),
              ),
            ],
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('くり返し（ループ）'),
            value: widget.repeat,
            onChanged: (v) {
              widget.onChanged(widget.startBar, widget.endBar, v);
            },
          ),
        ],
      ],
    );
  }
}

class _PresetList extends StatelessWidget {
  const _PresetList({required this.onLoad});
  final ValueChanged<MetronomePreset> onLoad;

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return const SizedBox.shrink();
    final cs = Theme.of(context).colorScheme;
    return StreamBuilder<List<MetronomePreset>>(
      stream: MetronomePresetRepository(uid: uid).watchAll(),
      builder: (context, snapshot) {
        final presets = snapshot.data ?? const [];
        if (presets.isEmpty) {
          return const Faint('保存したプリセットはまだありません');
        }
        return Column(
          children: [
            for (final p in presets)
              ListTile(
                contentPadding: EdgeInsets.zero,
                dense: true,
                title: Text(p.name),
                subtitle: Text('${p.bpm} BPM・${p.timeSignature.display}'),
                trailing: IconButton(
                  icon: Icon(Icons.delete_outline, color: cs.outline),
                  onPressed: () => MetronomePresetRepository(uid: uid).delete(p.id),
                ),
                onTap: () => onLoad(p),
              ),
          ],
        );
      },
    );
  }
}
