/// 調号
library;

/// 調号（五度圏での位置：-7〜7。0=ハ長調／イ短調、正で♯系、負で♭系）
///
/// MusicXML の &lt;fifths&gt; と同じ考え方。
class KeySignature {
  const KeySignature(this.fifths) : assert(fifths >= -7 && fifths <= 7);

  final int fifths;

  /// ♯がつく順番（ファ・ド・ソ・レ・ラ・ミ・シ）の幹音番号
  static const List<int> _sharpOrder = [3, 0, 4, 1, 5, 2, 6];

  /// ♭がつく順番（シ・ミ・ラ・レ・ソ・ド・ファ）の幹音番号
  static const List<int> _flatOrder = [6, 2, 5, 1, 4, 0, 3];

  /// 調号を描画するときに使う、♯がつく順番（幹音番号）
  static const List<int> sharpOrderForDrawing = _sharpOrder;

  /// 調号を描画するときに使う、♭がつく順番（幹音番号）
  static const List<int> flatOrderForDrawing = _flatOrder;

  /// 幹音番号（0=C..6=B）ごとの調号による変化（-1・0・1）
  Map<int, int> get alterations {
    final result = <int, int>{};
    if (fifths > 0) {
      for (var i = 0; i < fifths; i++) {
        result[_sharpOrder[i]] = 1;
      }
    } else if (fifths < 0) {
      for (var i = 0; i < -fifths; i++) {
        result[_flatOrder[i]] = -1;
      }
    }
    return result;
  }

  /// 長調の日本語名（例：ト長調）
  String get majorLabel {
    const sharpMajors = [
      'ハ', 'ト', 'ニ', 'イ', 'ホ', 'ロ', '嬰ヘ', '嬰ハ',
    ];
    const flatMajors = [
      'ハ', 'ヘ', '変ロ', '変ホ', '変イ', '変ニ', '変ト', '変ハ',
    ];
    final label = fifths >= 0 ? sharpMajors[fifths] : flatMajors[-fifths];
    return '$label長調';
  }

  /// 短調の日本語名（例：ホ短調）
  String get minorLabel {
    const sharpMinors = [
      'イ', 'ホ', 'ロ', '嬰ヘ', '嬰ハ', '嬰ト', '嬰ニ', '嬰イ',
    ];
    const flatMinors = [
      'イ', 'ニ', 'ト', 'ハ', 'ヘ', '変ロ', '変ホ', '変イ',
    ];
    final label = fifths >= 0 ? sharpMinors[fifths] : flatMinors[-fifths];
    return '$label短調';
  }

  /// 「ト長調（♯1つ）」のような表示用ラベル
  String get label {
    if (fifths == 0) return 'ハ長調・イ短調（調号なし）';
    final count = fifths.abs();
    final mark = fifths > 0 ? '♯' : '♭';
    return '$majorLabel／$minorLabel（$mark$count個）';
  }

  Map<String, dynamic> toMap() => {'fifths': fifths};

  static KeySignature fromMap(Map<String, dynamic> m) =>
      KeySignature((m['fifths'] as num?)?.toInt() ?? 0);

  @override
  bool operator ==(Object other) =>
      other is KeySignature && other.fifths == fifths;

  @override
  int get hashCode => fifths.hashCode;
}
