/// メトロノームの「音楽的タイミング」を管理するエンジン
///
/// Timer.periodic のコールバックが呼ばれた時刻そのものを拍の基準にすると、
/// OSやイベントループの混雑で少しずつズレて、そのズレが積み重なってしまう
/// （ドリフト）。そこで、開始時刻を基準にした「本来あるべき絶対時刻」を
/// 計算し続け、短い間隔（5ミリ秒）でポーリングして「その時刻を過ぎていたら
/// 鳴らす」方式にする。Timerは「正確な時計」ではなく「次にチェックすべき
/// タイミングを知らせる、粗いスケジューラ」として使う。
///
/// 音の再生（鳴らす）とUIの更新（拍の表示・振り子など）は、コールバックの
/// 順番としては同じタイミングで呼ぶが、UI側の重い処理が音の発音を遅らせない
/// よう、エンジン自体はUIに依存しない（PureDartのタイマーとStopwatchだけで
/// 動く）。
library;

import 'dart:async';
import 'dart:math' as math;

import 'accent.dart';
import 'rhythm_pattern.dart';
import 'tempo_ramp.dart';
import 'time_signature.dart';

/// 1回の発音イベント
class BeatEvent {
  const BeatEvent({
    required this.barIndex,
    required this.beatIndex,
    required this.slotIndex,
    required this.isMainBeat,
    required this.isGroupStart,
    required this.muted,
    required this.level,
    required this.currentBpm,
    required this.isCountIn,
  });

  /// 0始まりの小節番号（カウントインは負の番号）
  final int barIndex;
  final int beatIndex;
  final int slotIndex;
  final bool isMainBeat;
  final bool isGroupStart;
  final bool muted;
  final DynamicLevel level;
  final int currentBpm;
  final bool isCountIn;
}

/// タイミング精度の計測用サンプル（開発者向けパネルで使う）
class TimingSample {
  const TimingSample({required this.expectedMs, required this.actualMs});
  final double expectedMs;
  final double actualMs;
  double get errorMs => actualMs - expectedMs;
}

class MetronomeEngine {
  MetronomeEngine({
    required this.onBeat,
    this.onStop,
    this.onSample,
  });

  final void Function(BeatEvent event) onBeat;
  final void Function()? onStop;
  final void Function(TimingSample sample)? onSample;

  final Stopwatch _stopwatch = Stopwatch();
  Timer? _poll;
  bool _running = false;

  // --- 設定 ---
  int startBpm = 100;
  TimeSignature timeSignature = commonTimeSignatures[2]; // 4/4
  RhythmPattern pattern = RhythmPattern(
    beats: 4, // commonTimeSignatures[2] (4/4) の拍数と合わせる
    subdivision: 1,
  );
  int countInBars = 0;
  bool muteEnabled = false;
  int muteOnBars = 4;
  int muteOffBars = 2;
  int? loopStartBar; // null なら小節番号を意識しないフリー再生
  int? loopEndBar;
  bool loopRepeat = false;
  TempoRamp tempoRamp = const TempoRamp();
  bool collectAccuracySamples = false;

  int _nextSlotOrdinal = 0;
  bool _bounceUp = true;

  /// ループ再生中は、内部の小節番号0を実際には何小節目として扱うか
  /// （ループ範囲の途中から再生・くり返しをするための下駄）
  int _barOffset = 0;

  /// このstart()が「カウントインを省略すべきループの再開」かどうか
  int _activeCountIn = 0;

  bool get isRunning => _running;

  void start({bool suppressCountIn = false}) {
    if (_running) return;
    _running = true;
    _nextSlotOrdinal = 0;
    _bounceUp = true;
    _activeCountIn = suppressCountIn ? 0 : countInBars;
    _barOffset = (loopEndBar != null) ? (loopStartBar ?? 0) : 0;
    _stopwatch
      ..reset()
      ..start();
    _poll = Timer.periodic(const Duration(milliseconds: 5), (_) => _tick());
  }

  void stop() {
    if (!_running) return;
    _running = false;
    _poll?.cancel();
    _poll = null;
    _stopwatch.stop();
    onStop?.call();
  }

  double _expectedMsFor(int ordinal) {
    // ordinal番目のスロットが「本来鳴るべき」絶対時刻（ミリ秒）を、
    // 開始からの経過小節・拍・BPM変化を踏まえて積算する。
    var elapsedMs = 0.0;
    var remaining = ordinal;
    var barIndex = -_activeCountIn;
    var beatIndex = 0;
    var slotIndex = 0;
    final totalBeats = timeSignature.beats;
    final slotsPerBeat = math.max(1, pattern.subdivision);

    while (remaining > 0) {
      final bpmNow = barIndex < 0 ? startBpm : _bpmForBar(barIndex);
      final msPerSlot = 60000.0 / bpmNow / slotsPerBeat;
      elapsedMs += msPerSlot;
      remaining--;
      slotIndex++;
      if (slotIndex >= slotsPerBeat) {
        slotIndex = 0;
        beatIndex++;
        if (beatIndex >= totalBeats) {
          beatIndex = 0;
          barIndex++;
        }
      }
    }
    return elapsedMs;
  }

  int _bpmForBar(int barIndex) {
    if (tempoRamp.mode == TempoRampMode.off) return startBpm;
    return tempoRamp.bpmAfter(startBpm, barIndex + _barOffset, bounceDirectionUp: _bounceUp);
  }

  void _tick() {
    if (!_running) return;
    final nowMs = _stopwatch.elapsedMicroseconds / 1000.0;
    // 追いつくまで、遅れているスロットをまとめて処理する（取りこぼし防止）
    var guard = 0;
    while (guard < 64) {
      final expectedMs = _expectedMsFor(_nextSlotOrdinal);
      if (nowMs < expectedMs) break;
      _fire(_nextSlotOrdinal, expectedMs, nowMs);
      _nextSlotOrdinal++;
      guard++;
    }
  }

  void _fire(int ordinal, double expectedMs, double actualMs) {
    if (collectAccuracySamples && onSample != null) {
      onSample!(TimingSample(expectedMs: expectedMs, actualMs: actualMs));
    }

    final totalBeats = timeSignature.beats;
    final slotsPerBeat = math.max(1, pattern.subdivision);
    final slotsPerBar = totalBeats * slotsPerBeat;

    final barIndexFromCountIn = ordinal ~/ slotsPerBar - _activeCountIn;
    final withinBar = ordinal % slotsPerBar;
    final beatIndex = withinBar ~/ slotsPerBeat;
    final slotIndex = withinBar % slotsPerBeat;
    final isCountIn = barIndexFromCountIn < 0;
    final trueBar = barIndexFromCountIn + _barOffset;

    final bpmNow = isCountIn ? startBpm : _bpmForBar(barIndexFromCountIn);

    // 往復モードの折り返し判定（1小節ごとに一度だけ更新）
    if (!isCountIn && beatIndex == 0 && slotIndex == 0 &&
        tempoRamp.mode == TempoRampMode.bounce && tempoRamp.everyBars > 0) {
      final cycle = (trueBar ~/ tempoRamp.everyBars);
      _bounceUp = cycle.isEven;
    }

    var muted = false;
    if (!isCountIn && muteEnabled && (muteOnBars + muteOffBars) > 0) {
      final cyclePos = trueBar % (muteOnBars + muteOffBars);
      muted = cyclePos >= muteOnBars;
    }

    // ループ範囲外なら止める（自動停止）
    if (!isCountIn && loopEndBar != null && trueBar > loopEndBar!) {
      if (loopRepeat && loopStartBar != null) {
        // ループ範囲を過ぎたら、ループ開始小節からカウントインなしで再開する
        stop();
        start(suppressCountIn: true);
        return;
      }
      stop();
      return;
    }

    final slot = isCountIn
        ? const RhythmSlot(active: true, level: DynamicLevel.mp)
        : pattern.slotAt(beatIndex, slotIndex.clamp(0, pattern.subdivision - 1).toInt());

    if (!slot.active) return;

    onBeat(
      BeatEvent(
        barIndex: isCountIn ? barIndexFromCountIn : trueBar,
        beatIndex: beatIndex,
        slotIndex: slotIndex,
        isMainBeat: slotIndex == 0,
        isGroupStart: slotIndex == 0 && timeSignature.isGroupStart(beatIndex),
        muted: muted,
        level: slot.level,
        currentBpm: bpmNow,
        isCountIn: isCountIn,
      ),
    );
  }
}
