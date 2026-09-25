/// ロングトーン分析：音を伸ばして、平均・安定度・立ち上がりからの変化を見る
///
/// 管楽器奏者向けの専用練習モード。伸ばし終えたら結果を保存でき、
/// 「イントネーションマップ」「練習履歴」にたまっていく。
library;

import 'dart:async';
import 'dart:typed_data';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:material_ui/material_ui.dart';
import 'package:record/record.dart';

import '../review/review_widgets.dart';
import 'analysis/intonation_map.dart';
import 'analysis/long_tone_analysis.dart';
import 'analysis/vibrato_analysis.dart';
import 'instruments/instrument_profile.dart';
import 'music_theory.dart';
import 'pitch/pitch_algorithms.dart';
import 'pitch/pitch_tracker.dart';
import 'practice/practice_history_repository.dart';

class LongToneTab extends StatefulWidget {
  const LongToneTab({super.key});

  @override
  State<LongToneTab> createState() => _LongToneTabState();
}

class _LongToneTabState extends State<LongToneTab> {
  static const _sampleRate = 44100;
  static const _windowBytes = 3600;

  final _recorder = AudioRecorder();
  StreamSubscription<Uint8List>? _sub;
  final List<int> _pending = [];
  final _stopwatch = Stopwatch();
  final List<TimedCents> _samples = [];
  final _tracker = PitchTracker();

  InstrumentProfile _instrument = instrumentProfiles.first;
  final double _referenceHz = 442;

  bool _listening = false;
  TunedNote? _liveNote;

  /// このセッション中に最後に「確実」と判定された音。止める直前に一瞬
  /// 検出が不確実になっても（息が抜けた・音が揺れた等）消えないようにして、
  /// 記録（保存）で使う「どの音を伸ばしたか」を確定させるための値。
  TunedNote? _sessionNote;
  LongToneStats? _result;
  VibratoStats? _vibrato;
  String? _error;
  bool _saving = false;
  bool _saved = false;

  Future<void> _start() async {
    setState(() {
      _error = null;
      _result = null;
      _vibrato = null;
      _saved = false;
      _samples.clear();
      _liveNote = null;
      _sessionNote = null;
    });
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
          if (tracked == null || !tracked.certain) {
            _liveNote = null;
            return;
          }
          final note = nearestTunedNote(
            tracked.frequency,
            referenceHz: _referenceHz,
            temperament: Temperament.equal,
          );
          _liveNote = note;
          _sessionNote = note;
          _samples.add(TimedCents(t, note.cents));
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
    final stats = analyzeLongTone(_samples);
    final vib = analyzeVibrato(_samples);
    if (mounted) {
      setState(() {
        _listening = false;
        _result = stats;
        _vibrato = vib;
      });
    }
  }

  Future<void> _save() async {
    final stats = _result;
    final note = _sessionNote;
    if (stats == null || note == null) {
      if (stats != null && note == null && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('音の高さを判定できなかったため記録できませんでした。もう一度、音を安定して伸ばしてから止めてください。'),
          ),
        );
      }
      return;
    }
    setState(() => _saving = true);
    try {
      final uid = FirebaseAuth.instance.currentUser!.uid;
      final histRepo = PracticeHistoryRepository(uid: uid);
      await histRepo.save(
        LongToneSessionRecord(
          id: histRepo.newId(),
          date: DateTime.now(),
          instrumentId: _instrument.id,
          pitchClass: note.pitchClass,
          octave: note.octave,
          meanCents: stats.mean,
          stabilityPercent: stats.stabilityPercent,
          holdSeconds: stats.holdSeconds,
        ),
      );
      await IntonationMapRepository(
        uid: uid,
        instrumentId: _instrument.id,
      ).record(note.pitchClass, stats.mean);
      if (mounted) setState(() => _saved = true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('保存できませんでした（$e）')));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
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
    final r = _result;
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        const Text('音を1つ選んで、できるだけ長く・まっすぐ伸ばしてください。止めると分析結果が出ます。'),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final p in instrumentProfiles)
              ChoiceChip(
                label: Text(p.name),
                selected: _instrument.id == p.id,
                onSelected: _listening
                    ? null
                    : (_) => setState(() => _instrument = p),
              ),
          ],
        ),
        const SizedBox(height: 20),
        if (!_listening && r == null) ...[
          const SizedBox(height: 40),
          Center(
            child: Text(
              '準備ができたら開始',
              style: TextStyle(color: cs.outline),
            ),
          ),
          const SizedBox(height: 40),
        ],
        if (_listening) ...[
          Center(
            child: Text(
              _liveNote?.label(NotationSystem.english) ?? '（音を待っています…）',
              style: Theme.of(
                context,
              ).textTheme.displayMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
          ),
          if (_liveNote != null)
            Center(
              child: Text(
                _liveNote!.cents > 0
                    ? '+${_liveNote!.cents.toStringAsFixed(0)}¢'
                    : '${_liveNote!.cents.toStringAsFixed(0)}¢',
                style: TextStyle(color: cs.outline),
              ),
            ),
          const SizedBox(height: 8),
          Center(
            child: Text(
              '${(_stopwatch.elapsedMilliseconds / 1000).toStringAsFixed(1)} 秒',
            ),
          ),
        ],
        if (r != null) ...[
          Card(
            margin: EdgeInsets.zero,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${_sessionNote?.label(NotationSystem.english) ?? ''}（${_instrument.name}）',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 8),
                  _statRow('平均', '${r.mean >= 0 ? '+' : ''}${r.mean.toStringAsFixed(1)}¢'),
                  _statRow('最低', '${r.min >= 0 ? '+' : ''}${r.min.toStringAsFixed(1)}¢'),
                  _statRow('最高', '${r.max >= 0 ? '+' : ''}${r.max.toStringAsFixed(1)}¢'),
                  _statRow('標準偏差', '${r.stdDev.toStringAsFixed(1)}¢'),
                  _statRow('安定時間', '${r.holdSeconds.toStringAsFixed(1)}秒'),
                  _statRow('安定度', '${r.stabilityPercent.round()}%（${r.stabilityComment}）'),
                  const Divider(height: 24),
                  _statRow('開始時', '${r.startCents >= 0 ? '+' : ''}${r.startCents.toStringAsFixed(1)}¢'),
                  _statRow('中央', '${r.midCents >= 0 ? '+' : ''}${r.midCents.toStringAsFixed(1)}¢'),
                  _statRow('終了時', '${r.endCents >= 0 ? '+' : ''}${r.endCents.toStringAsFixed(1)}¢'),
                  const SizedBox(height: 8),
                  Text(r.levelComment, style: TextStyle(color: cs.primary)),
                  Text(r.trend, style: TextStyle(color: cs.primary)),
                  const SizedBox(height: 12),
                  Text(
                    _vibrato == null
                        ? 'ビブラートは検出されませんでした（判定できるほど規則的な揺れがなかった、または短すぎました）'
                        : 'ビブラート：${_vibrato!.description}',
                    style: TextStyle(color: cs.outline, fontSize: 12),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Center(
            child: _saved
                ? const Chip(label: Text('記録しました ✓'))
                : FilledButton.icon(
                    onPressed: _saving ? null : _save,
                    icon: const Icon(Icons.save_outlined),
                    label: Text(_saving ? '保存中…' : '記録する（練習履歴・イントネーションマップへ）'),
                  ),
          ),
          if (_saved && _sessionNote != null) ...[
            const SizedBox(height: 20),
            Text('この音の練習履歴', style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 6),
            StreamBuilder<List<LongToneSessionRecord>>(
              stream: PracticeHistoryRepository(
                uid: FirebaseAuth.instance.currentUser!.uid,
              ).watchFor(
                instrumentId: _instrument.id,
                pitchClass: _sessionNote!.pitchClass,
                octave: _sessionNote!.octave,
              ),
              builder: (context, snapshot) {
                final records = snapshot.data ?? const [];
                if (records.isEmpty) {
                  return const Faint('この音の記録はまだこれが初めてです');
                }
                return Column(
                  children: [
                    for (final rec in records.take(10))
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 2),
                        child: Row(
                          children: [
                            SizedBox(
                              width: 96,
                              child: Text(
                                '${rec.date.year}/${rec.date.month}/${rec.date.day}',
                                style: TextStyle(color: cs.outline, fontSize: 12),
                              ),
                            ),
                            Text(
                              '${rec.meanCents >= 0 ? '+' : ''}${rec.meanCents.toStringAsFixed(1)}¢'
                              '・安定度${rec.stabilityPercent.round()}%',
                            ),
                          ],
                        ),
                      ),
                  ],
                );
              },
            ),
          ],
        ],
        if (_error != null) ...[
          const SizedBox(height: 16),
          Text(_error!, style: TextStyle(color: cs.error)),
        ],
        const SizedBox(height: 28),
        Center(
          child: FilledButton.icon(
            onPressed: _listening ? _stop : _start,
            icon: Icon(_listening ? Icons.stop : Icons.mic),
            label: Text(_listening ? '止めて分析する' : 'ロングトーン開始'),
          ),
        ),
      ],
    );
  }

  Widget _statRow(String label, String value) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 2),
    child: Row(
      children: [
        SizedBox(width: 80, child: Text(label)),
        Text(value, style: const TextStyle(fontWeight: FontWeight.bold)),
      ],
    ),
  );
}
