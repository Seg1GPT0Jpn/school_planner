/// 開発者向けツール：精度テスト・スペクトラム・遅延の内訳
///
/// 「精度が高そう」ではなく、測定できるようにする。
/// ・精度テスト：既知の周波数を人工的に作り、検出値とのズレを自動計算する
/// ・スペクトラム：マイク入力のFFTと、検出した基音を重ねて見る（誤検出の原因調査用）
/// ・遅延：バッファの理論遅延と、検出処理の実測時間を分けて表示する
///   （マイクそのものの取り込み遅延はOS・端末依存で、Dartだけでは測れないため、
///   ここでは「バッファ遅延」と「処理時間」だけを扱う）
library;

import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:material_ui/material_ui.dart';
import 'package:record/record.dart';

import '../instruments/instrument_profile.dart';
import '../metronome/metronome_engine.dart';
import '../metronome/rhythm_pattern.dart';
import '../metronome/time_signature.dart';
import '../pitch/pitch_algorithms.dart';
import 'spectrum_fft.dart';

class DevToolsTab extends StatefulWidget {
  const DevToolsTab({super.key});

  @override
  State<DevToolsTab> createState() => _DevToolsTabState();
}

class _AccuracyResult {
  const _AccuracyResult({
    required this.label,
    required this.expectedFreq,
    required this.detectedFreq,
    required this.errorCents,
    required this.elapsedMicros,
  });
  final String label;
  final double expectedFreq;
  final double? detectedFreq;
  final double? errorCents;
  final int elapsedMicros;
}

Uint8List _syntheticPcm16(
  double freq, {
  int sampleRate = 44100,
  int samples = 4096,
  double amplitude = 0.5,
  List<double> harmonicAmps = const [],
}) {
  final buf = ByteData(samples * 2);
  for (var i = 0; i < samples; i++) {
    final t = i / sampleRate;
    var v = amplitude * math.sin(2 * math.pi * freq * t);
    for (var h = 0; h < harmonicAmps.length; h++) {
      v += harmonicAmps[h] * amplitude * math.sin(2 * math.pi * freq * (h + 2) * t);
    }
    final s = (v.clamp(-1.0, 1.0) * 32000).round();
    buf.setInt16(i * 2, s, Endian.little);
  }
  return buf.buffer.asUint8List();
}

class _DevToolsTabState extends State<DevToolsTab> {
  static const _sampleRate = 44100;
  static const _windowBytes = 4096;

  PitchAlgorithm _algorithm = PitchAlgorithm.yin;
  List<_AccuracyResult> _results = [];
  bool _running = false;

  final _recorder = AudioRecorder();
  StreamSubscription<Uint8List>? _sub;
  final List<int> _pending = [];
  bool _listening = false;
  List<double>? _spectrum;
  double? _detectedFreq;
  final List<int> _processMicrosHistory = [];

  final List<TimingSample> _timingSamples = [];
  bool _timingTestRunning = false;
  int _timingTestBpm = 120;
  int _timingTestSeconds = 10;
  MetronomeEngine? _timingEngine;
  Timer? _timingStopTimer;

  void _runAccuracyTests() {
    setState(() => _running = true);
    const a4 = 440.0;
    double cents(double c) => a4 * math.pow(2, c / 1200);
    final cases = <(String, double, double, List<double>)>[
      ('A4 440Hz（低ノイズ）', a4, 0.5, const []),
      ('A4 +1¢', cents(1), 0.5, const []),
      ('A4 -1¢', cents(-1), 0.5, const []),
      ('A4 +5¢', cents(5), 0.5, const []),
      ('A4 -5¢', cents(-5), 0.5, const []),
      ('低音 E2 82Hz', 82.41, 0.5, const []),
      ('中音 A4 440Hz', a4, 0.5, const []),
      ('高音 A6 1760Hz', 1760.0, 0.5, const []),
      ('小音量 A4', a4, 0.08, const []),
      ('大音量 A4', a4, 0.95, const []),
      ('2倍音が強いA4（金管想定）', a4, 0.5, [0.9]),
      ('倍音を多く含む複合音', a4, 0.5, [0.4, 0.3, 0.2]),
    ];
    final results = <_AccuracyResult>[];
    for (final c in cases) {
      final pcm = _syntheticPcm16(c.$2, amplitude: c.$3, harmonicAmps: c.$4);
      final sw = Stopwatch()..start();
      final candidate = detectPitchCandidate(
        pcm,
        sampleRate: _sampleRate,
        algorithm: _algorithm,
        minFreqOverride: 40,
        maxFreqOverride: 2500,
      );
      sw.stop();
      final detected = candidate?.frequency;
      final errCents = detected == null
          ? null
          : 1200 * (math.log(detected / c.$2) / math.ln2);
      results.add(
        _AccuracyResult(
          label: c.$1,
          expectedFreq: c.$2,
          detectedFreq: detected,
          errorCents: errCents,
          elapsedMicros: sw.elapsedMicroseconds,
        ),
      );
    }
    setState(() {
      _results = results;
      _running = false;
    });
  }

  Future<void> _toggleSpectrum() async {
    if (_listening) {
      await _sub?.cancel();
      _sub = null;
      try {
        await _recorder.stop();
      } catch (_) {}
      setState(() {
        _listening = false;
        _spectrum = null;
      });
      return;
    }
    if (!await _recorder.hasPermission()) return;
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
      final window = Uint8List.fromList(_pending.sublist(_pending.length - _windowBytes));
      _pending.clear();
      final sw = Stopwatch()..start();
      final candidate = detectPitchCandidate(
        window,
        sampleRate: _sampleRate,
        algorithm: _algorithm,
      );
      sw.stop();
      final spec = magnitudeSpectrum(window, fftSize: _windowBytes ~/ 2);
      if (!mounted) return;
      setState(() {
        _spectrum = spec;
        _detectedFreq = candidate?.frequency;
        _processMicrosHistory.add(sw.elapsedMicroseconds);
        while (_processMicrosHistory.length > 30) {
          _processMicrosHistory.removeAt(0);
        }
      });
    });
  }

  void _runTimingTest() {
    _timingSamples.clear();
    setState(() => _timingTestRunning = true);
    final engine = MetronomeEngine(onBeat: (_) {}, onSample: _timingSamples.add)
      ..startBpm = _timingTestBpm
      ..timeSignature = const TimeSignature(beats: 4, denominator: 4, grouping: [4])
      ..pattern = RhythmPattern(beats: 4, subdivision: 1)
      ..collectAccuracySamples = true;
    _timingEngine = engine;
    engine.start();
    _timingStopTimer = Timer(Duration(seconds: _timingTestSeconds), () {
      engine.stop();
      if (mounted) setState(() => _timingTestRunning = false);
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
    unawaited(_recorder.dispose());
    _timingStopTimer?.cancel();
    _timingEngine?.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final bufferLatencyMs = _windowBytes / 2 / _sampleRate * 1000;
    final avgProcessMs = _processMicrosHistory.isEmpty
        ? null
        : _processMicrosHistory.reduce((a, b) => a + b) / _processMicrosHistory.length / 1000;

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Text('開発者向けツール', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 4),
        Text(
          '「精度が高そう」ではなく、実測して確認するためのページです。',
          style: TextStyle(color: cs.outline),
        ),
        const SizedBox(height: 16),
        Wrap(
          spacing: 8,
          children: [
            for (final a in PitchAlgorithm.values)
              ChoiceChip(
                label: Text(a == PitchAlgorithm.yin ? 'YIN法' : '自己相関法'),
                selected: _algorithm == a,
                onSelected: (_) => setState(() => _algorithm = a),
              ),
          ],
        ),
        const SizedBox(height: 20),
        Text('① 精度テスト（既知の周波数との比較）', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        FilledButton.icon(
          onPressed: _running ? null : _runAccuracyTests,
          icon: const Icon(Icons.science_outlined),
          label: Text(_running ? '計測中…' : 'テストを実行'),
        ),
        const SizedBox(height: 12),
        if (_results.isNotEmpty)
          Table(
            columnWidths: const {
              0: FlexColumnWidth(2.2),
              1: FlexColumnWidth(1),
              2: FlexColumnWidth(1),
            },
            children: [
              TableRow(
                children: [
                  _th('テストケース'),
                  _th('誤差(¢)'),
                  _th('処理時間'),
                ],
              ),
              for (final r in _results)
                TableRow(
                  children: [
                    _td(r.label),
                    _td(
                      r.errorCents == null
                          ? '未検出'
                          : '${r.errorCents!.toStringAsFixed(2)}¢',
                      color: r.errorCents == null
                          ? cs.error
                          : (r.errorCents!.abs() < 2 ? cs.primary : cs.error),
                    ),
                    _td('${(r.elapsedMicros / 1000).toStringAsFixed(2)}ms'),
                  ],
                ),
            ],
          ),
        const SizedBox(height: 28),
        Text('② スペクトラム（マイク入力・基音の確認）', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          onPressed: _toggleSpectrum,
          icon: Icon(_listening ? Icons.stop : Icons.graphic_eq),
          label: Text(_listening ? '止める' : 'スペクトラムを見る'),
        ),
        const SizedBox(height: 8),
        if (_spectrum != null) ...[
          Text(
            _detectedFreq == null ? '検出：なし' : '検出した基音：${_detectedFreq!.toStringAsFixed(1)} Hz',
          ),
          const SizedBox(height: 4),
          SizedBox(
            height: 180,
            child: CustomPaint(
              painter: _SpectrumPainter(
                spectrum: _spectrum!,
                sampleRate: _sampleRate,
                fundamental: _detectedFreq,
                barColor: cs.primary,
                markerColor: cs.error,
              ),
              child: const SizedBox.expand(),
            ),
          ),
        ],
        const SizedBox(height: 28),
        Text('③ 遅延の内訳', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        _statLine('バッファ遅延（理論値）', '${bufferLatencyMs.toStringAsFixed(1)} ms'),
        _statLine(
          '検出処理の平均時間（実測・スペクトラム表示中）',
          avgProcessMs == null ? '（②を実行すると計測されます）' : '${avgProcessMs.toStringAsFixed(2)} ms',
        ),
        Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Text(
            'マイクの取り込み自体の遅延（OS・端末に依存）は、Dartの中だけでは正確に測れません。'
            '体感の遅延を追い込むには、ネイティブ側での計測が必要です（今回は未実装）。',
            style: TextStyle(color: cs.outline, fontSize: 12),
          ),
        ),
        const SizedBox(height: 28),
        Text('④ メトロノームの精度テスト', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 4),
        Text(
          '絶対時刻方式のタイミングエンジンが、実際にどれくらいズレるかを実測します。',
          style: TextStyle(color: cs.outline, fontSize: 12),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          children: [
            for (final b in const [80, 120, 180, 240])
              ChoiceChip(
                label: Text('$b BPM'),
                selected: _timingTestBpm == b,
                onSelected: _timingTestRunning
                    ? null
                    : (_) => setState(() => _timingTestBpm = b),
              ),
          ],
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          children: [
            for (final s in const [10, 30, 60, 300])
              ChoiceChip(
                label: Text(s < 60 ? '$s秒' : '${s ~/ 60}分'),
                selected: _timingTestSeconds == s,
                onSelected: _timingTestRunning
                    ? null
                    : (_) => setState(() => _timingTestSeconds = s),
              ),
          ],
        ),
        const SizedBox(height: 12),
        FilledButton.icon(
          onPressed: _timingTestRunning ? null : _runTimingTest,
          icon: const Icon(Icons.speed_outlined),
          label: Text(_timingTestRunning ? '計測中…（音は鳴りません）' : 'テストを実行'),
        ),
        const SizedBox(height: 12),
        if (_timingSamples.isNotEmpty) ..._timingResultRows(cs),
        const SizedBox(height: 12),
        Text(
          '対象楽器一覧（実用音域の目安）',
          style: Theme.of(context).textTheme.titleSmall,
        ),
        for (final p in instrumentProfiles)
          Text(
            '${p.name}：${p.minFreq.toStringAsFixed(0)}〜${p.maxFreq.toStringAsFixed(0)}Hz'
            '（${p.transpositionLabel}）',
            style: TextStyle(color: cs.outline, fontSize: 12),
          ),
      ],
    );
  }

  Widget _th(String s) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 6),
    child: Text(s, style: const TextStyle(fontWeight: FontWeight.bold)),
  );

  Widget _td(String s, {Color? color}) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: Text(s, style: TextStyle(color: color, fontSize: 12)),
  );

  List<Widget> _timingResultRows(ColorScheme cs) {
    final errors = [for (final s in _timingSamples) s.errorMs];
    final absErrors = [for (final e in errors) e.abs()];
    final avgAbs = absErrors.reduce((a, b) => a + b) / absErrors.length;
    final maxAbs = absErrors.reduce((a, b) => a > b ? a : b);
    final meanErr = errors.reduce((a, b) => a + b) / errors.length;
    var sq = 0.0;
    for (final e in errors) {
      sq += (e - meanErr) * (e - meanErr);
    }
    final jitter = sq > 0 ? (sq / errors.length) : 0.0;
    final jitterMs = jitter > 0 ? math.sqrt(jitter) : 0.0;
    final slotMs = 60000 / _timingTestBpm;
    final missed = absErrors.where((e) => e > slotMs / 2).length;

    return [
      _statLine('サンプル数', '${_timingSamples.length}拍'),
      _statLine('平均誤差', '${avgAbs.toStringAsFixed(2)} ms'),
      _statLine('最大誤差', '${maxAbs.toStringAsFixed(2)} ms'),
      _statLine('ジッター（誤差のばらつき）', '${jitterMs.toStringAsFixed(2)} ms'),
      _statLine('取りこぼし（半拍以上ズレた回数）', '$missed拍'),
    ];
  }

  Widget _statLine(String label, String value) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 3),
    child: Row(
      children: [
        Expanded(child: Text(label)),
        Text(value, style: const TextStyle(fontWeight: FontWeight.bold)),
      ],
    ),
  );
}

class _SpectrumPainter extends CustomPainter {
  _SpectrumPainter({
    required this.spectrum,
    required this.sampleRate,
    required this.fundamental,
    required this.barColor,
    required this.markerColor,
  });

  final List<double> spectrum;
  final int sampleRate;
  final double? fundamental;
  final Color barColor;
  final Color markerColor;

  @override
  void paint(Canvas canvas, Size size) {
    // 0〜2000Hzくらいを表示範囲にする（楽器の基音〜低次倍音が見える範囲）
    const maxDisplayFreq = 2000.0;
    final binHz = sampleRate / (spectrum.length * 2);
    final maxBin = (maxDisplayFreq / binHz).round().clamp(1, spectrum.length - 1).toInt();
    final maxMag = spectrum.take(maxBin).fold<double>(1, math.max);

    final barPaint = Paint()..color = barColor;
    final barWidth = size.width / maxBin;
    for (var i = 0; i < maxBin; i++) {
      final h = (spectrum[i] / maxMag).clamp(0.0, 1.0) * size.height;
      canvas.drawRect(
        Rect.fromLTWH(i * barWidth, size.height - h, barWidth * 0.9, h),
        barPaint,
      );
    }
    if (fundamental != null && fundamental! > 0) {
      final x = (fundamental! / binHz) * barWidth;
      canvas.drawLine(
        Offset(x, 0),
        Offset(x, size.height),
        Paint()
          ..color = markerColor
          ..strokeWidth = 2,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _SpectrumPainter oldDelegate) => true;
}
