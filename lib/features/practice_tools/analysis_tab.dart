/// 解析（音程の時間変化をグラフで見る）
///
/// 録音しながら、音の高さのずれ（セント）を時系列グラフに描く。
/// ロングトーンの安定度や、ビブラートのかかり方などの確認に使う。
library;

import 'dart:async';
import 'dart:collection';
import 'dart:typed_data';

import 'package:material_ui/material_ui.dart';
import 'package:record/record.dart';

import 'instruments/instrument_profile.dart';
import 'metronome/mini_metronome.dart';
import 'music_theory.dart';
import 'pitch/pitch_algorithms.dart';
import 'pitch/pitch_tracker.dart';
import 'tuner_displays.dart';

class _Sample {
  const _Sample(this.t, this.cents, {required this.silence});
  final double t; // 秒（グラフの左端からの経過時間）
  final double cents;

  /// 無音（音の候補がない、または不確実）で、centsが「0」の代用値であることを示す
  final bool silence;
}

class AnalysisTab extends StatefulWidget {
  const AnalysisTab({super.key});

  @override
  State<AnalysisTab> createState() => _AnalysisTabState();
}

class _AnalysisTabState extends State<AnalysisTab> {
  static const _sampleRate = 44100;
  static const _windowBytes = 3600; // 短めの窓で、細かい変化を追う
  static const _windowSeconds = 8.0; // グラフに表示する時間の幅

  final _recorder = AudioRecorder();
  StreamSubscription<Uint8List>? _sub;
  final List<int> _pending = [];
  final _stopwatch = Stopwatch();

  final Queue<_Sample> _samples = Queue();
  final _tracker = PitchTracker();
  TunedNote? _lastNote;
  TrackedPitch? _lastTracked;

  bool _listening = false;
  String? _error;

  InstrumentProfile _instrument = instrumentProfiles.first;
  double _referenceHz = 442;
  TunerPrecision _precision = TunerPrecision.medium;

  Future<void> _start() async {
    setState(() => _error = null);
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
      _samples.clear();
      _tracker.reset();
      _stopwatch
        ..reset()
        ..start();
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
        if (!mounted) return;
        final t = _stopwatch.elapsedMilliseconds / 1000;
        setState(() {
          _lastTracked = tracked;
          if (tracked != null && tracked.certain) {
            final note = nearestTunedNote(
              tracked.frequency,
              referenceHz: _referenceHz,
              temperament: Temperament.equal,
            );
            _lastNote = note;
            _samples.add(
              _Sample(t, note.cents.clamp(-50, 50).toDouble(), silence: false),
            );
          } else {
            // 何も音が聞こえていない（＝無音）ときは、グラフを途切れさせず
            // 「0」として記録する（見た目は薄い色・無音として区別する）。
            _lastNote = null;
            _samples.add(_Sample(t, 0, silence: true));
          }
          while (_samples.isNotEmpty && t - _samples.first.t > _windowSeconds) {
            _samples.removeFirst();
          }
        });
      });
    } catch (e) {
      setState(() => _error = '開始できませんでした（$e）');
    }
  }

  Future<void> _stop() async {
    await _sub?.cancel();
    _sub = null;
    _stopwatch.stop();
    try {
      await _recorder.stop();
    } catch (_) {}
    if (mounted) {
      setState(() {
        _listening = false;
        _lastTracked = null;
        _lastNote = null;
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
    final note = _lastNote;
    // 聞いている最中で、音の候補すらない＝無音。無音は「0」として、
    // グラフも途切れさせずに描く（薄い色で無音とわかるようにする）。
    final isSilence = _listening && note == null;
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        const Text(
          'ロングトーンなどを続けて吹く（歌う）と、音程の揺れがグラフでわかります。'
          '中央の線が「ぴったり」、上が高い・下が低いです。',
        ),
        const SizedBox(height: 12),
        const MiniMetronome(),
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
                Row(
                  children: [
                    Text('基準音　', style: Theme.of(context).textTheme.labelLarge),
                    Text('${_referenceHz.toStringAsFixed(0)} Hz'),
                    const Spacer(),
                    IconButton(
                      onPressed: () => setState(
                        () => _referenceHz = (_referenceHz - 1).clamp(415, 466).toDouble(),
                      ),
                      icon: const Icon(Icons.remove_circle_outline),
                    ),
                    IconButton(
                      onPressed: () => setState(
                        () => _referenceHz = (_referenceHz + 1).clamp(415, 466).toDouble(),
                      ),
                      icon: const Icon(Icons.add_circle_outline),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  '許容誤差（グラフの色分けの基準）',
                  style: Theme.of(context).textTheme.labelLarge,
                ),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 8,
                  children: [
                    for (final p in TunerPrecision.values)
                      ChoiceChip(
                        label: Text('${p.label}（±${p.cents}¢）'),
                        selected: _precision == p,
                        onSelected: (_) => setState(() => _precision = p),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              note?.label(NotationSystem.english) ??
                  (isSilence ? '0' : (_listening ? '（音を聞いています…）' : '—')),
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: isSilence ? cs.outline : null,
              ),
            ),
            const SizedBox(width: 12),
            if (_lastTracked != null)
              Text(
                '${_lastTracked!.frequency.toStringAsFixed(1)} Hz',
                style: TextStyle(color: cs.outline),
              )
            else if (isSilence)
              Text('無音', style: TextStyle(color: cs.outline)),
          ],
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 260,
          child: CustomPaint(
            painter: _CentsGraphPainter(
              samples: _samples.toList(),
              windowSeconds: _windowSeconds,
              preciseCents: _precision.cents,
              silenceColor: cs.outline,
              gridColor: cs.outlineVariant,
              centerColor: cs.onSurface,
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
            icon: Icon(_listening ? Icons.mic_off : Icons.mic),
            label: Text(_listening ? '止める' : '解析をはじめる'),
          ),
        ),
      ],
    );
  }
}

class _CentsGraphPainter extends CustomPainter {
  _CentsGraphPainter({
    required this.samples,
    required this.windowSeconds,
    required this.preciseCents,
    required this.silenceColor,
    required this.gridColor,
    required this.centerColor,
    required this.textColor,
  });

  final List<_Sample> samples;
  final double windowSeconds;

  /// この範囲内（±cents）なら緑、10セント以内ならオレンジ、それ以上は赤
  /// （チューナー画面の「許容誤差」と同じ考え方で、線の色を変える）
  final int preciseCents;

  /// 無音区間（cents=0の代用値）を描くときの、通常のピッチ表示と区別する色
  final Color silenceColor;
  final Color gridColor;
  final Color centerColor;
  final Color textColor;

  static const _rangeCents = 50.0; // 上下50セントまで表示

  double _yFor(double cents, Size size) {
    final t = (cents.clamp(-_rangeCents, _rangeCents) + _rangeCents) / (2 * _rangeCents);
    return size.height * (1 - t);
  }

  @override
  void paint(Canvas canvas, Size size) {
    // 横線（5セントごとに薄く、25セントごとに濃く）
    for (var c = -50; c <= 50; c += 5) {
      final y = _yFor(c.toDouble(), size);
      final isMajor = c % 25 == 0;
      final isCenter = c == 0;
      final paint = Paint()
        ..color = isCenter ? centerColor : gridColor.withValues(alpha: isMajor ? 0.9 : 0.4)
        ..strokeWidth = isCenter ? 2 : 1;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
      if (isMajor) {
        final tp = TextPainter(
          text: TextSpan(
            text: c == 0 ? '0' : (c > 0 ? '+$c' : '$c'),
            style: TextStyle(color: textColor, fontSize: 10),
          ),
          textDirection: TextDirection.ltr,
        )..layout();
        tp.paint(canvas, Offset(4, y - tp.height - 2));
      }
    }

    if (samples.length < 2) return;

    final latestT = samples.last.t;
    final startT = latestT - windowSeconds;

    double xFor(double t) => size.width * (t - startT) / windowSeconds;

    // 区間ごとに線を引く（無音をまたぐ区間は薄い色・細めにして区別する。
    // 途切れさせず「0」として描くことで、無音の間もグラフが続く）
    _Sample? prev;
    for (final s in samples) {
      if (s.t < startT) {
        prev = s;
        continue;
      }
      if (prev != null) {
        final segmentSilent = prev.silence || s.silence;
        // 精度の幅（許容誤差）に応じて、線の色を緑・オレンジ・赤に変える
        // （区間の平均のずれで判定。無音区間は今まで通り薄い色のまま）
        final color = segmentSilent
            ? silenceColor
            : centsAccuracyColor(
                (prev.cents + s.cents) / 2,
                preciseCents: preciseCents,
              );
        canvas.drawLine(
          Offset(xFor(prev.t), _yFor(prev.cents, size)),
          Offset(xFor(s.t), _yFor(s.cents, size)),
          Paint()
            ..color = color
            ..style = PaintingStyle.stroke
            ..strokeWidth = segmentSilent ? 1.5 : 2.5
            ..strokeCap = StrokeCap.round,
        );
      }
      prev = s;
    }

    // 直近の点を強調
    final last = samples.last;
    if (last.t >= startT) {
      canvas.drawCircle(
        Offset(xFor(last.t), _yFor(last.cents, size)),
        4,
        Paint()
          ..color = last.silence
              ? silenceColor
              : centsAccuracyColor(last.cents, preciseCents: preciseCents),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _CentsGraphPainter oldDelegate) =>
      !identical(oldDelegate.samples, samples) ||
      oldDelegate.preciseCents != preciseCents;
}
