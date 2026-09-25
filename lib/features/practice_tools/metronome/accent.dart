/// 拍の強弱（ダイナミクス）と、よく使うアクセントパターンのプリセット
library;

/// 拍1つぶんの強弱。[gain] は0（無音）〜1（最大）の音量倍率。
enum DynamicLevel {
  mute(0.0, 'ミュート'),
  p(0.35, 'p'),
  mp(0.55, 'mp'),
  mf(0.75, 'mf'),
  f(1.0, 'f');

  const DynamicLevel(this.gain, this.label);
  final double gain;
  final String label;

  DynamicLevel get louder =>
      DynamicLevel.values[(index + 1).clamp(0, DynamicLevel.values.length - 1).toInt()];
  DynamicLevel get softer =>
      DynamicLevel.values[(index - 1).clamp(0, DynamicLevel.values.length - 1).toInt()];
}

/// 「マーチ（強弱弱弱）」のような、拍ごとの強弱パターン。
/// [levels] の長さが拍数より短い場合は、足りない分を繰り返す。
class AccentPreset {
  const AccentPreset({required this.name, required this.levels});
  final String name;
  final List<DynamicLevel> levels;

  DynamicLevel levelFor(int beatIndex) => levels[beatIndex % levels.length];
}

const List<AccentPreset> accentPresets = [
  AccentPreset(name: 'クラシック（強弱中弱）', levels: [
    DynamicLevel.f,
    DynamicLevel.p,
    DynamicLevel.mf,
    DynamicLevel.p,
  ]),
  AccentPreset(name: 'マーチ（強弱弱弱）', levels: [
    DynamicLevel.f,
    DynamicLevel.p,
    DynamicLevel.p,
    DynamicLevel.p,
  ]),
  AccentPreset(name: 'ワルツ（強弱弱）', levels: [
    DynamicLevel.f,
    DynamicLevel.p,
    DynamicLevel.p,
  ]),
  AccentPreset(name: 'スウィング（強弱中弱）', levels: [
    DynamicLevel.f,
    DynamicLevel.mp,
    DynamicLevel.mf,
    DynamicLevel.mp,
  ]),
  AccentPreset(name: 'すべて均等', levels: [DynamicLevel.mf]),
];
