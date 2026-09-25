/// 音部記号
library;

/// 音部記号（フェーズ1ではト音記号・ヘ音記号のみ対応）
enum Clef {
  /// ト音記号（第2線がソ）
  treble('ト音記号'),

  /// ヘ音記号（第4線がファ）
  bass('ヘ音記号');

  const Clef(this.label);
  final String label;

  /// この音部記号で、五線の一番下の線（第1線）が [Pitch.staffStep] でいくつか
  /// （[Pitch.staffStep] は真ん中のド＝C4を 0 とする。1違うごとに1つ隣の
  /// 幹音、2違うごとに五線の線1本ぶん・間1つぶん動く）
  int get bottomLineStaffStep => switch (this) {
    Clef.treble => 2, // 第1線＝E4
    Clef.bass => -10, // 第1線＝G2
  };
}
