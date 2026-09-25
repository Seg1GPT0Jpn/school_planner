/// 五線譜の横位置（レイアウト）の計算
///
/// 描画（StaffPainter）と、タップ位置から音符を特定する処理の両方から、
/// 同じ計算を使うための共通ロジック。Flutter に依存しないプレーンな Dart。
library;

import '../model/measure.dart';
import '../model/score.dart';

/// 1音符・1休符の、五線上での横位置
class NoteSlot {
  const NoteSlot({
    required this.measureIndex,
    required this.noteIndex,
    required this.centerX,
    required this.width,
    required this.note,
  });

  final int measureIndex;
  final int noteIndex;

  /// 符頭の中心のx座標
  final double centerX;

  /// この音符が占める横幅
  final double width;
  final ScoreNote note;
}

/// 1小節分の横位置
class MeasureSlot {
  const MeasureSlot({
    required this.index,
    required this.startX,
    required this.endX,
  });

  final int index;

  /// 小節の中身が始まるx座標
  final double startX;

  /// 右側の小節線のx座標
  final double endX;

  bool contains(double x) => x >= startX && x <= endX;
}

/// 1パートぶんのレイアウト結果
class PartLayout {
  const PartLayout({
    required this.clefX,
    required this.keySigStartX,
    required this.timeSigX,
    required this.firstMeasureX,
    required this.notes,
    required this.measures,
    required this.contentWidth,
  });

  final double clefX;
  final double keySigStartX;
  final double timeSigX;
  final double firstMeasureX;
  final List<NoteSlot> notes;
  final List<MeasureSlot> measures;

  /// 五線譜全体の必要な幅
  final double contentWidth;

  /// 指定した座標に一番近い音符を探す（タップ判定用。measureIndex, noteIndex を返す）
  (int, int)? hitTest(double x, {double tolerance = 26}) {
    NoteSlot? best;
    double bestDist = double.infinity;
    for (final slot in notes) {
      final d = (slot.centerX - x).abs();
      if (d < bestDist) {
        bestDist = d;
        best = slot;
      }
    }
    if (best == null || bestDist > tolerance) return null;
    return (best.measureIndex, best.noteIndex);
  }

  /// 指定した座標がどの小節か（音符が1つもない小節でも判定できる）
  int? measureIndexAt(double x) {
    for (final m in measures) {
      if (m.contains(x)) return m.index;
    }
    return null;
  }
}

/// 音価（拍数）から、音符1つぶんの横幅を決める
/// （長い音符ほど広く、短い音符ほど狭く。読みやすさのための簡易な比例配分）
double noteWidthForBeats(double beats) => 30 + beats * 24;

/// パートのレイアウトを計算する
PartLayout layoutPart(
  ScorePart part, {
  double leftMargin = 12,
  double headerWidth = 92,
  double measureGap = 20,
  double minEmptyMeasureWidth = 70,
}) {
  final notes = <NoteSlot>[];
  final measures = <MeasureSlot>[];
  var x = leftMargin + headerWidth;

  for (var mi = 0; mi < part.measures.length; mi++) {
    final measure = part.measures[mi];
    final startX = x;
    if (measure.notes.isEmpty) {
      x += minEmptyMeasureWidth;
    } else {
      for (var ni = 0; ni < measure.notes.length; ni++) {
        final note = measure.notes[ni];
        final w = noteWidthForBeats(note.duration.beats);
        notes.add(
          NoteSlot(
            measureIndex: mi,
            noteIndex: ni,
            centerX: x + w / 2,
            width: w,
            note: note,
          ),
        );
        x += w;
      }
    }
    final endX = x + measureGap / 2;
    measures.add(MeasureSlot(index: mi, startX: startX, endX: endX));
    x = endX + measureGap / 2;
  }

  return PartLayout(
    clefX: leftMargin + 22,
    keySigStartX: leftMargin + 42,
    timeSigX: leftMargin + headerWidth - 26,
    firstMeasureX: leftMargin + headerWidth,
    notes: notes,
    measures: measures,
    contentWidth: x + leftMargin,
  );
}
