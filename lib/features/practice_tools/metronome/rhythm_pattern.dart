/// リズムパターン：拍をさらに細かく分割し、どこを鳴らす／鳴らさないか、
/// どれくらいの強さで鳴らすかを、マスごとに自由に決められるようにする
///
/// 「2連・3連・4連」の固定の裏打ちだけでなく、シンコペーションや付点、
/// タンギングパターンの練習用に、任意のクリック配置を作れる。
library;

import 'accent.dart';

/// 1マス（拍のなかの1分割）
class RhythmSlot {
  const RhythmSlot({this.active = true, this.level = DynamicLevel.mf});
  final bool active;
  final DynamicLevel level;

  RhythmSlot copyWith({bool? active, DynamicLevel? level}) =>
      RhythmSlot(active: active ?? this.active, level: level ?? this.level);
}

/// 1小節ぶんのリズムパターン。[beats] × [subdivision] のマス目。
class RhythmPattern {
  RhythmPattern({required this.beats, required this.subdivision, List<List<RhythmSlot>>? grid})
    : grid = grid ?? _defaultGrid(beats, subdivision);

  final int beats;

  /// 1拍をいくつに分けるか（1=分割なし、2=8分、3=3連、4=16分）
  final int subdivision;

  /// grid[beatIndex][slotIndex]
  final List<List<RhythmSlot>> grid;

  static List<List<RhythmSlot>> _defaultGrid(int beats, int subdivision) => [
    for (var b = 0; b < beats; b++)
      [
        const RhythmSlot(active: true, level: DynamicLevel.mf),
        for (var s = 1; s < subdivision; s++)
          const RhythmSlot(active: false, level: DynamicLevel.p),
      ],
  ];

  RhythmSlot slotAt(int beatIndex, int slotIndex) => grid[beatIndex][slotIndex];

  RhythmPattern withSlot(int beatIndex, int slotIndex, RhythmSlot slot) {
    final newGrid = [
      for (var b = 0; b < grid.length; b++)
        [
          for (var s = 0; s < grid[b].length; s++)
            (b == beatIndex && s == slotIndex) ? slot : grid[b][s],
        ],
    ];
    return RhythmPattern(beats: beats, subdivision: subdivision, grid: newGrid);
  }

  /// 拍ごとの強弱プリセットを適用した、新しいパターンを作る
  /// （メインの拍＝スロット0だけに、[preset] の強弱を反映する）
  RhythmPattern withAccentPreset(AccentPreset preset, {required bool Function(int) isGroupStart}) {
    final newGrid = [
      for (var b = 0; b < grid.length; b++)
        [
          for (var s = 0; s < grid[b].length; s++)
            s == 0 ? grid[b][s].copyWith(level: preset.levelFor(b)) : grid[b][s],
        ],
    ];
    return RhythmPattern(beats: beats, subdivision: subdivision, grid: newGrid);
  }

  /// [subdivision] を変えて、新しいパターンを作り直す（既存のON/OFFはできるだけ引き継ぐ）
  RhythmPattern withSubdivision(int newSubdivision) {
    final newGrid = [
      for (var b = 0; b < beats; b++)
        [
          for (var s = 0; s < newSubdivision; s++)
            s < grid[b].length
                ? grid[b][s]
                : RhythmSlot(active: false, level: DynamicLevel.p),
        ],
    ];
    return RhythmPattern(beats: beats, subdivision: newSubdivision, grid: newGrid);
  }

  /// [newBeats] に合わせて、新しいパターンを作り直す
  RhythmPattern withBeats(int newBeats) {
    final newGrid = [
      for (var b = 0; b < newBeats; b++)
        b < grid.length ? grid[b] : _defaultGrid(1, subdivision).first,
    ];
    return RhythmPattern(beats: newBeats, subdivision: subdivision, grid: newGrid);
  }
}
