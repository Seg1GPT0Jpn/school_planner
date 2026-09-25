/// 楽譜の再生（tone_synth.dart のピアノ音色を使う）
library;

import 'dart:async';
import 'dart:typed_data';

import 'package:audioplayers/audioplayers.dart';

import '../../practice_tools/tone_synth.dart';
import '../model/measure.dart';
import '../model/pitch.dart';
import '../model/score.dart';

class _FlatNote {
  const _FlatNote(
    this.measureIndex,
    this.noteIndex,
    this.note,
    this.startSeconds,
    this.seconds,
  );

  final int measureIndex;
  final int noteIndex;
  final ScoreNote note;
  final double startSeconds;
  final double seconds;
}

bool _samePitches(List<Pitch> a, List<Pitch> b) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}

/// 楽譜（1パート、または複数パート）を再生する
class ScorePlayer {
  ScorePlayer({this.tone = PianoTone.piano, int poolSize = 12})
    : _pool = List.generate(poolSize, (_) => AudioPlayer());

  final PianoTone tone;
  final List<AudioPlayer> _pool;
  final Map<String, Uint8List> _cache = {};
  final List<Timer> _timers = [];
  int _poolIndex = 0;
  bool _playing = false;

  bool get isPlaying => _playing;

  Future<void> init() async {
    for (final p in _pool) {
      await p.setPlayerMode(PlayerMode.lowLatency);
    }
  }

  void dispose() {
    stop();
    for (final p in _pool) {
      unawaited(p.dispose());
    }
  }

  Uint8List _wavFor(Pitch pitch, double seconds) {
    final clamped = seconds.clamp(0.08, 4.0);
    final key = '${tone.name}_${pitch.midi}_${clamped.toStringAsFixed(2)}';
    return _cache.putIfAbsent(
      key,
      () => generatePianoNoteWav(pitch.frequencyHz(), tone, seconds: clamped),
    );
  }

  void _playPitch(Pitch pitch, double seconds) {
    final bytes = _wavFor(pitch, seconds);
    final player = _pool[_poolIndex];
    _poolIndex = (_poolIndex + 1) % _pool.length;
    unawaited(player.play(BytesSource(bytes)));
  }

  /// 1パートぶんのタイマーを組み立てる。戻り値はそのパートの全体の長さ（秒）
  double _schedulePart(
    ScorePart part,
    double secPerBeat, {
    required void Function(int measureIndex, int noteIndex) onNote,
  }) {
    final flat = <_FlatNote>[];
    var t = 0.0;
    for (var mi = 0; mi < part.measures.length; mi++) {
      for (var ni = 0; ni < part.measures[mi].notes.length; ni++) {
        final note = part.measures[mi].notes[ni];
        final seconds = note.duration.beats * secPerBeat;
        flat.add(_FlatNote(mi, ni, note, t, seconds));
        t += seconds;
      }
    }

    var i = 0;
    while (i < flat.length) {
      final start = flat[i];
      var totalSeconds = start.seconds;
      var j = i;
      while (flat[j].note.tiedToNext &&
          j + 1 < flat.length &&
          _samePitches(flat[j].note.pitches, flat[j + 1].note.pitches)) {
        j++;
        totalSeconds += flat[j].seconds;
      }
      final delayMs = (start.startSeconds * 1000).round();
      final noteToPlay = start.note;
      final playSeconds = totalSeconds;
      _timers.add(
        Timer(Duration(milliseconds: delayMs), () {
          if (!_playing) return;
          if (!noteToPlay.isRest) {
            for (final p in noteToPlay.pitches) {
              _playPitch(p, playSeconds * 0.95);
            }
          }
          onNote(start.measureIndex, start.noteIndex);
        }),
      );
      i = j + 1;
    }
    return t;
  }

  /// 1パートを最初から再生する。
  /// [onNote] は音が鳴り始めるたびに (measureIndex, noteIndex) を渡す
  /// （画面上のカーソル表示に使う）。[onDone] は再生が終わったときに呼ばれる
  void play(
    ScorePart part,
    int tempoBpm, {
    void Function(int measureIndex, int noteIndex)? onNote,
    void Function()? onDone,
  }) {
    stop();
    if (tempoBpm <= 0) return;
    _playing = true;
    final secPerBeat = 60 / tempoBpm;
    final total = _schedulePart(
      part,
      secPerBeat,
      onNote: (mi, ni) => onNote?.call(mi, ni),
    );
    _timers.add(
      Timer(Duration(milliseconds: (total * 1000).round()), () {
        _playing = false;
        onDone?.call();
      }),
    );
  }

  /// 複数パートを同時に（アンサンブルとして）再生する。
  /// [onNote] は (パートのインデックス, measureIndex, noteIndex) を渡す
  void playParts(
    List<ScorePart> parts,
    int tempoBpm, {
    void Function(int partIndex, int measureIndex, int noteIndex)? onNote,
    void Function()? onDone,
  }) {
    stop();
    if (tempoBpm <= 0 || parts.isEmpty) return;
    _playing = true;
    final secPerBeat = 60 / tempoBpm;
    var maxTotal = 0.0;
    for (var pi = 0; pi < parts.length; pi++) {
      final total = _schedulePart(
        parts[pi],
        secPerBeat,
        onNote: (mi, ni) => onNote?.call(pi, mi, ni),
      );
      if (total > maxTotal) maxTotal = total;
    }
    _timers.add(
      Timer(Duration(milliseconds: (maxTotal * 1000).round()), () {
        _playing = false;
        onDone?.call();
      }),
    );
  }

  void stop() {
    for (final timer in _timers) {
      timer.cancel();
    }
    _timers.clear();
    _playing = false;
    for (final p in _pool) {
      unawaited(p.stop());
    }
  }
}
