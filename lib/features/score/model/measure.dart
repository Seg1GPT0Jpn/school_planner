/// 1小節ぶんの音符・休符
library;

import 'duration.dart';
import 'pitch.dart';

/// 1つの音符・休符・和音
///
/// [pitches] が空なら休符。複数あれば和音（同時に鳴る音の集まり）
class ScoreNote {
  const ScoreNote({
    this.pitches = const [],
    required this.duration,
    this.tiedToNext = false,
  });

  final List<Pitch> pitches;
  final NoteDuration duration;

  /// 次の音符にタイでつながっているか（同じ高さの音符どうしを1つの音として伸ばす）
  final bool tiedToNext;

  bool get isRest => pitches.isEmpty;
  bool get isChord => pitches.length > 1;

  /// 和音のうち、符幹の基準にする音（いちばん高い音）
  Pitch? get topPitch =>
      pitches.isEmpty ? null : pitches.reduce((a, b) => a.midi > b.midi ? a : b);

  ScoreNote copyWith({
    List<Pitch>? pitches,
    NoteDuration? duration,
    bool? tiedToNext,
  }) => ScoreNote(
    pitches: pitches ?? this.pitches,
    duration: duration ?? this.duration,
    tiedToNext: tiedToNext ?? this.tiedToNext,
  );

  Map<String, dynamic> toMap() => {
    'pitches': [for (final p in pitches) p.toMap()],
    'duration': duration.toMap(),
    'tiedToNext': tiedToNext,
  };

  static ScoreNote fromMap(Map<String, dynamic> m) => ScoreNote(
    pitches: [
      for (final p in (m['pitches'] as List<dynamic>? ?? const []))
        Pitch.fromMap(Map<String, dynamic>.from(p as Map)),
    ],
    duration: NoteDuration.fromMap(
      Map<String, dynamic>.from(m['duration'] as Map),
    ),
    tiedToNext: m['tiedToNext'] as bool? ?? false,
  );
}

/// 1小節（拍子ぶんの音符・休符の並び）
class Measure {
  const Measure({this.notes = const []});

  final List<ScoreNote> notes;

  /// 今入っている音符・休符の合計の長さ（4分音符を1拍とした長さ）
  double get beatsUsed =>
      notes.fold(0.0, (sum, n) => sum + n.duration.beats);

  /// 指定した拍子に対して、まだ入る余地があるか
  bool hasRoomFor(NoteDuration duration, double beatsPerMeasure) =>
      beatsUsed + duration.beats <= beatsPerMeasure + 0.0001;

  /// 指定した拍子ぶん、ちょうど埋まっているか
  bool isFull(double beatsPerMeasure) => beatsUsed >= beatsPerMeasure - 0.0001;

  Measure withNoteAdded(ScoreNote note) => Measure(notes: [...notes, note]);

  Measure withNoteRemovedAt(int index) => Measure(
    notes: [for (var i = 0; i < notes.length; i++) if (i != index) notes[i]],
  );

  Measure withNoteReplacedAt(int index, ScoreNote note) => Measure(
    notes: [
      for (var i = 0; i < notes.length; i++) if (i == index) note else notes[i],
    ],
  );

  Map<String, dynamic> toMap() => {
    'notes': [for (final n in notes) n.toMap()],
  };

  static Measure fromMap(Map<String, dynamic> m) => Measure(
    notes: [
      for (final n in (m['notes'] as List<dynamic>? ?? const []))
        ScoreNote.fromMap(Map<String, dynamic>.from(n as Map)),
    ],
  );
}
