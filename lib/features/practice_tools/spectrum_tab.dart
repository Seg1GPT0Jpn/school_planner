/// スペクトラム：マイク入力の周波数成分を、リアルタイムでグラフに見る
///
/// 「開発者向けツール」にあった簡易版を、ちゃんと使える機能として独立させたもの。
/// ・検出した基音（音名・Hz）を大きく表示
/// ・倍音（2倍音・3倍音・4倍音）の位置を重ねて表示できる
///   （倍音の混じり方・音色の違いを見るのに使う）
/// ・表示範囲（周波数の上限）を切り替えられる
library;

import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:material_ui/material_ui.dart';
import 'package:record/record.dart';

import 'dev/spectrum_fft.dart';
import 'instruments/instrument_profile.dart';
import 'music_theory.dart';
import 'pitch/pitch_algorithms.dart';
import 'pitch/pitch_tracker.dart';

class SpectrumTab extends StatefulWidget {
  const SpectrumTab({super.key});

  @override
  State<SpectrumTab> createState() => _SpectrumTabState();
}

class _SpectrumTabState extends State<SpectrumTab> {
  static const _sampleRate = 44100;
  static const _windowBytes = 4096; // = 2048サンプル（FFTサイズ）

  final _recorder = AudioRecorder();
  StreamSubscription<Uint8List>? _sub;
  final List<int> _pending = [];
  final _tracker = PitchTracker();

  bool _listening = false;
  String? _error;
  List<double>? _spectrum;
  TrackedPitch? _tracked;
  TunedNote? _note;

  InstrumentProfile _instrument = instrumentProfiles.first;
  final double _referenceHz = 442;
  double _displayMaxFreq = 2000;
  bool _showHarmonics = true;

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
          algorithm: PitchAlgorithm.yin,
          instrument: _instrument,
        );
        final tracked = _tracker.push(candidate);
        final spec = magnitudeSpectrum(window, fftSize: _windowBytes ~/ 2);
        if (!mounted) return;
        setState(() {
          _spectrum = spec;
          _tracked = tracked;
          _note = (tracked != null && tracked.certain)
              ? nearestTunedNote(
                  tracked.frequency,
                  referenceHz: _referenceHz,
                  temperament: Temperament.equal,
                )
              : null;
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
        _spectrum = null;
        _tracked = null;
        _note = null;
      });
    }
  }

  @override
  void dispose() {
    _sub?.cancel();
    unawaited(_recorder.dispose());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final note = _note;
    final candidateButUncertain = _tracked != null && !_tracked!.certain;

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        const Text(
          '音を出しながら、周波数成分（どの高さの音がどれくらい混ざっているか）を見られます。'
          '赤い縦線が検出した基音、点線が倍音の位置です。',
        ),
        const SizedBox(height: 12),
        Card(
          margin: EdgeInsets.zero,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('楽器', style: Theme.of(context).textTheme.labelLarge),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final m in instrumentProfiles)
                      ChoiceChip(
                        label: Text(m.name),
                        selected: _instrument.id == m.id,
                        onSelected: (_) => setState(() => _instrument = m),
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                Text('表示する周波数の範囲', style: Theme.of(context).textTheme.labelLarge),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 8,
                  children: [
                    for (final f in const [500.0, 1000.0, 2000.0, 4000.0])
                      ChoiceChip(
                        label: Text('〜${f.toStringAsFixed(0)}Hz'),
                        selected: _displayMaxFreq == f,
                        onSelected: (_) => setState(() => _displayMaxFreq = f),
                      ),
                  ],
                ),
                const SizedBox(height: 4),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('倍音の位置を表示'),
                  subtitle: const Text('基音の2倍・3倍・4倍の周波数に点線を重ねます'),
                  value: _showHarmonics,
                  onChanged: (v) => setState(() => _showHarmonics = v),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        Center(
          child: Text(
            note != null
                ? note.label(NotationSystem.english)
                : (candidateButUncertain
                      ? '検出不確実…'
                      : (_listening ? '（音を聞いています…）' : '—')),
            style: Theme.of(
              context,
            ).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold),
          ),
        ),
        Center(
          child: Text(
            _tracked == null ? ' ' : '${_tracked!.frequency.toStringAsFixed(1)} Hz',
            style: TextStyle(color: cs.outline),
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 240,
          child: CustomPaint(
            painter: _SpectrumPainter(
              spectrum: _spectrum,
              sampleRate: _sampleRate,
              maxDisplayFreq: _displayMaxFreq,
              fundamental: _tracked?.frequency,
              referenceHz: _referenceHz,
              showHarmonics: _showHarmonics,
              barColor: cs.primary,
              markerColor: cs.error,
              harmonicColor: cs.tertiary,
              gridColor: cs.outlineVariant,
              textColor: cs.outline,
            ),
            child: Container(
              decoration: BoxDecoration(
                border: Border.all(color: cs.outlineVariant),
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
        ),
        if (_error != null) ...[
          const SizedBox(height: 16),
          Text(_error!, style: TextStyle(color: cs.error)),
        ],
        const SizedBox(height: 28),
        Center(
          child: FilledButton.icon(
            onPressed: _listening ? _stop : _start,
            icon: Icon(_listening ? Icons.stop : Icons.graphic_eq),
            label: Text(_listening ? '止める' : 'スペクトラムを見る'),
          ),
        ),
      ],
    );
  }
}

class _SpectrumPainter extends CustomPainter {
  _SpectrumPainter({
    required this.spectrum,
    required this.sampleRate,
    required this.maxDisplayFreq,
    required this.fundamental,
    required this.referenceHz,
    required this.showHarmonics,
    required this.barColor,
    required this.markerColor,
    required this.harmonicColor,
    required this.gridColor,
    required this.textColor,
  });

  final List<double>? spectrum;
  final int sampleRate;
  final double maxDisplayFreq;
  final double? fundamental;
  final double referenceHz;
  final bool showHarmonics;
  final Color barColor;
  final Color markerColor;
  final Color harmonicColor;
  final Color gridColor;
  final Color textColor;

  void _label(Canvas canvas, String text, Offset at) {
    final tp = TextPainter(
      text: TextSpan(text: text, style: TextStyle(color: textColor, fontSize: 10)),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, at);
  }

  @override
  void paint(Canvas canvas, Size size) {
    // 横軸（Hz）の目盛り。範囲に応じて、きりのいい間隔にする。
    final step = maxDisplayFreq <= 500
        ? 100.0
        : (maxDisplayFreq <= 1000 ? 200.0 : (maxDisplayFreq <= 2000 ? 500.0 : 1000.0));
    for (var f = 0.0; f <= maxDisplayFreq; f += step) {
      final x = size.width * f / maxDisplayFreq;
      canvas.drawLine(
        Offset(x, 0),
        Offset(x, size.height),
        Paint()
          ..color = gridColor.withValues(alpha: 0.5)
          ..strokeWidth = 1,
      );
      _label(canvas, f.toStringAsFixed(0), Offset(x + 2, size.height - 14));
    }

    final spec = spectrum;
    if (spec == null || spec.isEmpty) return;

    final binHz = sampleRate / (spec.length * 2);
    final maxBin = (maxDisplayFreq / binHz).round().clamp(1, spec.length - 1).toInt();
    final maxMag = spec.take(maxBin).fold<double>(1, math.max);

    final barPaint = Paint()..color = barColor;
    final barWidth = size.width / maxBin;
    for (var i = 0; i < maxBin; i++) {
      final h = (spec[i] / maxMag).clamp(0.0, 1.0) * (size.height - 18);
      canvas.drawRect(
        Rect.fromLTWH(i * barWidth, size.height - 18 - h, barWidth * 0.9, h),
        barPaint,
      );
    }

    void drawSolidMarker(double freq, Color color, String label) {
      if (freq <= 0 || freq > maxDisplayFreq) return;
      final x = size.width * freq / maxDisplayFreq;
      canvas.drawLine(
        Offset(x, 0),
        Offset(x, size.height - 18),
        Paint()
          ..color = color
          ..strokeWidth = 2,
      );
      _label(canvas, label, Offset(x + 3, 2));
    }

    void drawDashedMarker(double freq, Color color, String label) {
      if (freq <= 0 || freq > maxDisplayFreq) return;
      final x = size.width * freq / maxDisplayFreq;
      const dashHeight = 5.0;
      const gapHeight = 4.0;
      var y = 0.0;
      final paint = Paint()
        ..color = color
        ..strokeWidth = 2;
      while (y < size.height - 18) {
        canvas.drawLine(Offset(x, y), Offset(x, math.min(y + dashHeight, size.height - 18)), paint);
        y += dashHeight + gapHeight;
      }
      _label(canvas, label, Offset(x + 3, 2));
    }

    String noteNameForFreq(double freq) => nearestTunedNote(
      freq,
      referenceHz: referenceHz,
      temperament: Temperament.equal,
    ).label(NotationSystem.english);

    final f0 = fundamental;
    if (f0 != null && f0 > 0) {
      drawSolidMarker(f0, markerColor, '基音 ${noteNameForFreq(f0)}');
      if (showHarmonics) {
        for (final n in const [2, 3, 4]) {
          final hf = f0 * n;
          drawDashedMarker(hf, harmonicColor, '×$n ${noteNameForFreq(hf)}');
        }
      }
    }
  }

  @override
  bool shouldRepaint(covariant _SpectrumPainter oldDelegate) => true;
}
