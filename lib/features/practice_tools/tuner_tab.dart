/// チューナー（マイクの音から音の高さを推定して表示する）
///
/// ・アルゴリズム：自己相関法／YIN法を切り替え可能
/// ・楽器プロファイル（管楽器の種類ごとに音域・移調・倍音のクセを持つ）
/// ・平均律／純正律／ピタゴラス音律／カスタム音律、基準音（Hz）
/// ・表示：Needle／Bar／Strobe
/// ・Auto Mode：自信度が低いときは「検出不確実」と明示し、無理に音名を出さない
/// ・Performance Mode／Stage Mode：演奏中でも一瞬で読める、大きくシンプルな表示
library;

import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/services.dart' show SystemChrome, SystemUiMode, DeviceOrientation;
import 'package:material_ui/material_ui.dart';
import 'package:record/record.dart';

import 'custom_temperament_page.dart';
import 'instruments/instrument_profile.dart';
import 'metronome/mini_metronome.dart';
import 'music_theory.dart';
import 'pitch/pitch_algorithms.dart';
import 'pitch/pitch_tracker.dart';
import 'tuner_displays.dart';

class TunerTab extends StatefulWidget {
  const TunerTab({super.key});

  @override
  State<TunerTab> createState() => _TunerTabState();
}

class _TunerTabState extends State<TunerTab> {
  static const _sampleRate = 44100;
  static const _windowBytes = 4096;

  final _recorder = AudioRecorder();
  StreamSubscription<Uint8List>? _sub;
  final List<int> _pending = [];
  final _tracker = PitchTracker();

  bool _listening = false;
  String? _error;
  TrackedPitch? _tracked;
  TunedNote? _note;

  // --- 設定 ---
  PitchAlgorithm _algorithm = PitchAlgorithm.yin;
  InstrumentProfile _instrument = instrumentProfiles.first;
  Temperament _temperament = Temperament.equal;
  CustomTemperament _customTemperament = CustomTemperament.equalBased();
  PersonalCalibration? _personal;
  NotationSystem _notation = NotationSystem.english;
  TunerPrecision _precision = TunerPrecision.medium;
  double _referenceHz = 442;
  int _tonicPitchClass = 0;
  bool _showTransposed = false;
  TunerDisplayMode _displayMode = TunerDisplayMode.bar;
  StrobeResolution _strobeResolution = StrobeResolution.medium;
  bool _settingsExpanded = false;
  bool _stageMode = false;

  Future<void> _start() async {
    setState(() => _error = null);
    _tracker.reset();
    try {
      if (!await _recorder.hasPermission()) {
        setState(() => _error = 'マイクの権限が許可されませんでした');
        return;
      }
      final stream = await _recorder.startStream(
        const RecordConfig(
          encoder: AudioEncoder.pcm16bits,
          sampleRate: _sampleRate,
          numChannels: 1,
        ),
      );
      setState(() => _listening = true);
      _pending.clear();
      _sub = stream.listen((chunk) {
        _pending.addAll(chunk);
        if (_pending.length < _windowBytes) return;
        final window = Uint8List.fromList(
          _pending.sublist(_pending.length - _windowBytes),
        );
        _pending.clear();
        final candidate = detectPitchCandidate(
          window,
          sampleRate: _sampleRate,
          algorithm: _algorithm,
          instrument: _instrument,
        );
        final tracked = _tracker.push(candidate);
        if (!mounted) return;
        setState(() {
          _tracked = tracked;
          _note = (tracked == null || !tracked.certain)
              ? null
              : nearestTunedNote(
                  tracked.frequency,
                  referenceHz: _referenceHz,
                  temperament: _temperament,
                  tonicPitchClass: _tonicPitchClass,
                  custom: _customTemperament,
                  personal: _personal,
                );
        });
      });
    } catch (e) {
      setState(() => _error = '開始できませんでした（$e）');
    }
  }

  Future<void> _stop() async {
    await _sub?.cancel();
    _sub = null;
    try {
      await _recorder.stop();
    } catch (_) {}
    if (mounted) {
      setState(() {
        _listening = false;
        _tracked = null;
        _note = null;
      });
    }
  }

  Future<void> _setStageMode(bool on) async {
    setState(() => _stageMode = on);
    if (on) {
      await SystemChrome.setPreferredOrientations([
        DeviceOrientation.landscapeLeft,
        DeviceOrientation.landscapeRight,
      ]);
      await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    } else {
      await SystemChrome.setPreferredOrientations(DeviceOrientation.values);
      await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    }
  }

  @override
  void dispose() {
    _sub?.cancel();
    unawaited(_recorder.dispose());
    if (_stageMode) {
      unawaited(SystemChrome.setPreferredOrientations(DeviceOrientation.values));
      unawaited(SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge));
    }
    super.dispose();
  }

  Color _centsColor(double cents, ColorScheme cs) =>
      centsAccuracyColor(cents, preciseCents: _precision.cents);

  String _faceFor(double cents) {
    final a = cents.abs();
    if (a <= _precision.cents) return '😄';
    if (a <= 10) return '😐';
    return '😟';
  }

  int _displayPitchClass(TunedNote note) => _showTransposed
      ? transposedPitchClass(note.pitchClass, _instrument.transpositionSemitones)
      : note.pitchClass;

  String _displayLabel(TunedNote note) =>
      '${noteNameFor(_displayPitchClass(note), _notation)}${note.octave}';

  Widget _meterFor(double cents, Color color) => switch (_displayMode) {
    TunerDisplayMode.bar => TunerBarMeter(cents: cents, color: color),
    TunerDisplayMode.needle => TunerNeedleMeter(cents: cents, color: color),
    TunerDisplayMode.strobe => StrobeMeter(
      cents: cents,
      resolution: _strobeResolution,
      color: color,
    ),
  };

  @override
  Widget build(BuildContext context) {
    if (_stageMode) return _buildStage(context);
    final cs = Theme.of(context).colorScheme;
    final note = _note;
    final candidateButUncertain = _tracked != null && !_tracked!.certain;
    // 聞いている最中で、音の候補すらない＝無音。無音は「0」として、
    // 判定不能（検出不確実）とは見た目を分けて示す。
    final isSilence = _listening && _tracked == null;

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        const Text('まわりが静かな場所で、音を長めに伸ばすと安定します。'),
        const SizedBox(height: 12),
        const MiniMetronome(),
        const SizedBox(height: 12),
        _SettingsPanel(
          expanded: _settingsExpanded,
          onExpandedChanged: (v) => setState(() => _settingsExpanded = v),
          algorithm: _algorithm,
          onAlgorithmChanged: (v) => setState(() => _algorithm = v),
          instrument: _instrument,
          onInstrumentChanged: (v) => setState(() => _instrument = v),
          temperament: _temperament,
          onTemperamentChanged: (v) => setState(() => _temperament = v),
          notation: _notation,
          onNotationChanged: (v) => setState(() => _notation = v),
          precision: _precision,
          onPrecisionChanged: (v) => setState(() => _precision = v),
          referenceHz: _referenceHz,
          onReferenceHzChanged: (v) => setState(() => _referenceHz = v),
          tonicPitchClass: _tonicPitchClass,
          onTonicChanged: (v) => setState(() => _tonicPitchClass = v),
          showTransposed: _showTransposed,
          onShowTransposedChanged: (v) => setState(() => _showTransposed = v),
          displayMode: _displayMode,
          onDisplayModeChanged: (v) => setState(() => _displayMode = v),
          strobeResolution: _strobeResolution,
          onStrobeResolutionChanged: (v) => setState(() => _strobeResolution = v),
          personalEnabled: _personal != null,
          onPersonalEnabledChanged: (v) => setState(
            () => _personal = v ? const PersonalCalibration() : null,
          ),
          onEditCustomTemperament: () async {
            final result = await openCustomTemperamentEditor(context, _customTemperament);
            if (result != null) setState(() => _customTemperament = result);
          },
          onEnterStageMode: () => _setStageMode(true),
        ),
        const SizedBox(height: 20),
        Center(
          child: Text(
            note != null
                ? _displayLabel(note)
                : (isSilence
                      ? '0'
                      : (candidateButUncertain
                            ? '検出不確実…'
                            : (_listening ? '（音を聞いています…）' : '—'))),
            style: Theme.of(context).textTheme.displayMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: isSilence ? cs.outline : null,
            ),
          ),
        ),
        const SizedBox(height: 4),
        Center(
          child: Text(
            _tracked == null ? ' ' : '${_tracked!.frequency.toStringAsFixed(1)} Hz',
            style: TextStyle(color: cs.outline),
          ),
        ),
        const SizedBox(height: 20),
        if (note != null) ...[
          Center(
            child: Text(_faceFor(note.cents), style: const TextStyle(fontSize: 56)),
          ),
          const SizedBox(height: 8),
          _meterFor(note.cents, _centsColor(note.cents, cs)),
          const SizedBox(height: 8),
          Center(
            child: Text(
              note.cents.abs() <= _precision.cents
                  ? 'ぴったり！'
                  : (note.cents > 0
                        ? '${note.cents.toStringAsFixed(0)}セント高い'
                        : '${(-note.cents).toStringAsFixed(0)}セント低い'),
              style: TextStyle(
                color: _centsColor(note.cents, cs),
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          if (_personal != null && note.personalAdjustedCents != null)
            Center(
              child: Text(
                '個人補正後：${note.personalAdjustedCents!.toStringAsFixed(0)}¢',
                style: TextStyle(color: cs.outline, fontSize: 12),
              ),
            ),
        ] else if (isSilence) ...[
          const SizedBox(height: 8),
          Center(
            child: Text('🔈', style: TextStyle(fontSize: 56, color: cs.outline)),
          ),
          const SizedBox(height: 8),
          _meterFor(0, cs.outlineVariant),
          const SizedBox(height: 8),
          Center(
            child: Text(
              '無音',
              style: TextStyle(color: cs.outline, fontWeight: FontWeight.bold),
            ),
          ),
        ] else if (candidateButUncertain) ...[
          const SizedBox(height: 8),
          Center(
            child: Text(
              '音程が不安定で、まだ確実に判定できません',
              style: TextStyle(color: cs.outline),
            ),
          ),
          const SizedBox(height: 56),
        ] else ...[
          const SizedBox(height: 64),
        ],
        if (_error != null) ...[
          const SizedBox(height: 16),
          Text(_error!, style: TextStyle(color: cs.error)),
        ],
        const SizedBox(height: 32),
        Center(
          child: FilledButton.icon(
            onPressed: _listening ? _stop : _start,
            icon: Icon(_listening ? Icons.mic_off : Icons.mic),
            label: Text(_listening ? '止める' : '聞きはじめる'),
          ),
        ),
      ],
    );
  }

  /// ステージモード：大きな文字・高コントラスト・横向き・片手で操作できる最小限のUI
  Widget _buildStage(BuildContext context) {
    final note = _note;
    final color = note == null
        ? Colors.white70
        : _centsColor(note.cents, ColorScheme.dark());
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: GestureDetector(
          onTap: () => setState(
            () => _displayMode = TunerDisplayMode
                .values[(_displayMode.index + 1) % TunerDisplayMode.values.length],
          ),
          child: Stack(
            children: [
              Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      note != null ? _displayLabel(note) : '—',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 96,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    if (note != null)
                      Text(
                        '${note.cents >= 0 ? '+' : ''}${note.cents.toStringAsFixed(0)}¢',
                        style: TextStyle(color: color, fontSize: 40, fontWeight: FontWeight.bold),
                      ),
                    const SizedBox(height: 24),
                    SizedBox(
                      width: 320,
                      child: note == null
                          ? const SizedBox(height: 64)
                          : _meterFor(note.cents, color),
                    ),
                  ],
                ),
              ),
              Positioned(
                top: 8,
                right: 8,
                child: IconButton(
                  icon: const Icon(Icons.close, color: Colors.white70),
                  onPressed: () => _setStageMode(false),
                ),
              ),
              if (!_listening)
                Positioned(
                  bottom: 24,
                  left: 0,
                  right: 0,
                  child: Center(
                    child: FilledButton.icon(
                      onPressed: _start,
                      icon: const Icon(Icons.mic),
                      label: const Text('聞きはじめる'),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SettingsPanel extends StatelessWidget {
  const _SettingsPanel({
    required this.expanded,
    required this.onExpandedChanged,
    required this.algorithm,
    required this.onAlgorithmChanged,
    required this.instrument,
    required this.onInstrumentChanged,
    required this.temperament,
    required this.onTemperamentChanged,
    required this.notation,
    required this.onNotationChanged,
    required this.precision,
    required this.onPrecisionChanged,
    required this.referenceHz,
    required this.onReferenceHzChanged,
    required this.tonicPitchClass,
    required this.onTonicChanged,
    required this.showTransposed,
    required this.onShowTransposedChanged,
    required this.displayMode,
    required this.onDisplayModeChanged,
    required this.strobeResolution,
    required this.onStrobeResolutionChanged,
    required this.personalEnabled,
    required this.onPersonalEnabledChanged,
    required this.onEditCustomTemperament,
    required this.onEnterStageMode,
  });

  final bool expanded;
  final ValueChanged<bool> onExpandedChanged;
  final PitchAlgorithm algorithm;
  final ValueChanged<PitchAlgorithm> onAlgorithmChanged;
  final InstrumentProfile instrument;
  final ValueChanged<InstrumentProfile> onInstrumentChanged;
  final Temperament temperament;
  final ValueChanged<Temperament> onTemperamentChanged;
  final NotationSystem notation;
  final ValueChanged<NotationSystem> onNotationChanged;
  final TunerPrecision precision;
  final ValueChanged<TunerPrecision> onPrecisionChanged;
  final double referenceHz;
  final ValueChanged<double> onReferenceHzChanged;
  final int tonicPitchClass;
  final ValueChanged<int> onTonicChanged;
  final bool showTransposed;
  final ValueChanged<bool> onShowTransposedChanged;
  final TunerDisplayMode displayMode;
  final ValueChanged<TunerDisplayMode> onDisplayModeChanged;
  final StrobeResolution strobeResolution;
  final ValueChanged<StrobeResolution> onStrobeResolutionChanged;
  final bool personalEnabled;
  final ValueChanged<bool> onPersonalEnabledChanged;
  final VoidCallback onEditCustomTemperament;
  final VoidCallback onEnterStageMode;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Card(
      margin: EdgeInsets.zero,
      child: Column(
        children: [
          ListTile(
            leading: const Icon(Icons.tune),
            title: const Text('チューナーの設定'),
            subtitle: Text(
              '${instrument.name}・${temperament.label}・'
              '${referenceHz.toStringAsFixed(0)}Hz・${displayMode.label}',
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  tooltip: 'ステージモード',
                  icon: const Icon(Icons.stay_current_landscape_outlined),
                  onPressed: onEnterStageMode,
                ),
                Icon(expanded ? Icons.expand_less : Icons.expand_more),
              ],
            ),
            onTap: () => onExpandedChanged(!expanded),
          ),
          if (expanded)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('楽器', style: Theme.of(context).textTheme.labelLarge),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final p in instrumentProfiles)
                        ChoiceChip(
                          label: Text(p.name),
                          selected: instrument.id == p.id,
                          onSelected: (_) => onInstrumentChanged(p),
                        ),
                    ],
                  ),
                  if (instrument.transpositionSemitones != 0) ...[
                    const SizedBox(height: 8),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text('移調表示（${instrument.transpositionLabel}）'),
                      subtitle: const Text('ONで記譜音、OFFで実音を表示します'),
                      value: showTransposed,
                      onChanged: onShowTransposedChanged,
                    ),
                  ],
                  const SizedBox(height: 12),
                  Text('検出アルゴリズム', style: Theme.of(context).textTheme.labelLarge),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 8,
                    children: [
                      ChoiceChip(
                        label: const Text('YIN法（倍音に強い）'),
                        selected: algorithm == PitchAlgorithm.yin,
                        onSelected: (_) => onAlgorithmChanged(PitchAlgorithm.yin),
                      ),
                      ChoiceChip(
                        label: const Text('自己相関法'),
                        selected: algorithm == PitchAlgorithm.autocorrelation,
                        onSelected: (_) =>
                            onAlgorithmChanged(PitchAlgorithm.autocorrelation),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Text('音律', style: Theme.of(context).textTheme.labelLarge),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final t in Temperament.values)
                        ChoiceChip(
                          label: Text(t.label),
                          selected: temperament == t,
                          onSelected: (_) => onTemperamentChanged(t),
                        ),
                    ],
                  ),
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      temperament.description,
                      style: TextStyle(color: cs.outline, fontSize: 12),
                    ),
                  ),
                  if (temperament == Temperament.just ||
                      temperament == Temperament.pythagorean) ...[
                    const SizedBox(height: 12),
                    Text('主音', style: Theme.of(context).textTheme.labelLarge),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        for (var pc = 0; pc < 12; pc++)
                          ChoiceChip(
                            label: Text(noteNameFor(pc, notation)),
                            selected: tonicPitchClass == pc,
                            onSelected: (_) => onTonicChanged(pc),
                          ),
                      ],
                    ),
                  ],
                  if (temperament == Temperament.custom) ...[
                    const SizedBox(height: 12),
                    OutlinedButton.icon(
                      onPressed: onEditCustomTemperament,
                      icon: const Icon(Icons.edit_outlined),
                      label: const Text('カスタム音律を編集'),
                    ),
                  ],
                  const SizedBox(height: 16),
                  Text('基準音（A=${referenceHz.toStringAsFixed(0)}Hz）',
                      style: Theme.of(context).textTheme.labelLarge),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      IconButton.filledTonal(
                        onPressed: () => onReferenceHzChanged(
                          (referenceHz - 0.1).clamp(415, 466).toDouble(),
                        ),
                        icon: const Icon(Icons.remove),
                      ),
                      Expanded(
                        child: Slider(
                          value: referenceHz,
                          min: 415,
                          max: 466,
                          divisions: 510,
                          label: '${referenceHz.toStringAsFixed(1)}Hz',
                          onChanged: onReferenceHzChanged,
                        ),
                      ),
                      IconButton.filledTonal(
                        onPressed: () => onReferenceHzChanged(
                          (referenceHz + 0.1).clamp(415, 466).toDouble(),
                        ),
                        icon: const Icon(Icons.add),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text('音名の表記', style: Theme.of(context).textTheme.labelLarge),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final n in NotationSystem.values)
                        ChoiceChip(
                          label: Text(n.label),
                          selected: notation == n,
                          onSelected: (_) => onNotationChanged(n),
                        ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Text('感度（合っているとみなす範囲）',
                      style: Theme.of(context).textTheme.labelLarge),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 8,
                    children: [
                      for (final p in TunerPrecision.values)
                        ChoiceChip(
                          label: Text('${p.label}（±${p.cents}）'),
                          selected: precision == p,
                          onSelected: (_) => onPrecisionChanged(p),
                        ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Text('表示', style: Theme.of(context).textTheme.labelLarge),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 8,
                    children: [
                      for (final m in TunerDisplayMode.values)
                        ChoiceChip(
                          label: Text(m.label),
                          selected: displayMode == m,
                          onSelected: (_) => onDisplayModeChanged(m),
                        ),
                    ],
                  ),
                  if (displayMode == TunerDisplayMode.strobe) ...[
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final r in StrobeResolution.values)
                          ChoiceChip(
                            label: Text(r.label),
                            selected: strobeResolution == r,
                            onSelected: (_) => onStrobeResolutionChanged(r),
                          ),
                      ],
                    ),
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        '表示の細かさであって、検出の精度そのものではありません',
                        style: TextStyle(color: cs.outline, fontSize: 11),
                      ),
                    ),
                  ],
                  const SizedBox(height: 16),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('個人補正を使う'),
                    subtitle: const Text('自分の楽器・吹き方のクセを、標準の表示とは別に補正して見せます'),
                    value: personalEnabled,
                    onChanged: onPersonalEnabledChanged,
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
