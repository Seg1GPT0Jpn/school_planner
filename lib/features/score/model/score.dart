/// 楽譜全体のデータ（作品＝パートの集まり）
library;

import 'clef.dart';
import 'key_signature.dart';
import 'measure.dart';
import 'time_signature.dart';

/// 1つのパート（例：トランペット1st）
class ScorePart {
  const ScorePart({
    required this.id,
    required this.name,
    this.instrument = '',
    this.clef = Clef.treble,
    this.keySignature = const KeySignature(0),
    this.timeSignature = const TimeSignature(4, 4),
    this.measures = const [],

    /// 移調楽器の移調量（半音）。例：B♭管トランペットは -2
    /// （記譜音から実音を求めるときに使う。0なら移調しない）
    this.transposeSemitones = 0,
  });

  final String id;
  final String name;
  final String instrument;
  final Clef clef;
  final KeySignature keySignature;
  final TimeSignature timeSignature;
  final List<Measure> measures;
  final int transposeSemitones;

  ScorePart copyWith({
    String? id,
    String? name,
    String? instrument,
    Clef? clef,
    KeySignature? keySignature,
    TimeSignature? timeSignature,
    List<Measure>? measures,
    int? transposeSemitones,
  }) => ScorePart(
    id: id ?? this.id,
    name: name ?? this.name,
    instrument: instrument ?? this.instrument,
    clef: clef ?? this.clef,
    keySignature: keySignature ?? this.keySignature,
    timeSignature: timeSignature ?? this.timeSignature,
    measures: measures ?? this.measures,
    transposeSemitones: transposeSemitones ?? this.transposeSemitones,
  );

  ScorePart withMeasureReplacedAt(int index, Measure measure) => copyWith(
    measures: [
      for (var i = 0; i < measures.length; i++)
        if (i == index) measure else measures[i],
    ],
  );

  ScorePart withMeasureAdded([Measure? measure]) =>
      copyWith(measures: [...measures, measure ?? const Measure()]);

  ScorePart withMeasureRemovedAt(int index) => copyWith(
    measures: [
      for (var i = 0; i < measures.length; i++) if (i != index) measures[i],
    ],
  );

  Map<String, dynamic> toMap() => {
    'id': id,
    'name': name,
    'instrument': instrument,
    'clef': clef.name,
    'keySignature': keySignature.toMap(),
    'timeSignature': timeSignature.toMap(),
    'measures': [for (final m in measures) m.toMap()],
    'transposeSemitones': transposeSemitones,
  };

  static ScorePart fromMap(Map<String, dynamic> m) => ScorePart(
    id: m['id'] as String? ?? '',
    name: m['name'] as String? ?? 'パート1',
    instrument: m['instrument'] as String? ?? '',
    clef: Clef.values.asNameMap()[m['clef']] ?? Clef.treble,
    keySignature: m['keySignature'] == null
        ? const KeySignature(0)
        : KeySignature.fromMap(
            Map<String, dynamic>.from(m['keySignature'] as Map),
          ),
    timeSignature: m['timeSignature'] == null
        ? const TimeSignature(4, 4)
        : TimeSignature.fromMap(
            Map<String, dynamic>.from(m['timeSignature'] as Map),
          ),
    measures: [
      for (final x in (m['measures'] as List<dynamic>? ?? const []))
        Measure.fromMap(Map<String, dynamic>.from(x as Map)),
    ],
    transposeSemitones: (m['transposeSemitones'] as num?)?.toInt() ?? 0,
  );
}

/// 楽譜全体（曲名・作曲者・テンポ・パートの集まり）
class Score {
  const Score({
    this.id = '',
    required this.title,
    this.composer = '',
    this.tempoBpm = 120,
    this.parts = const [],
    this.updatedAt,
  });

  final String id;
  final String title;
  final String composer;
  final int tempoBpm;
  final List<ScorePart> parts;
  final DateTime? updatedAt;

  Score copyWith({
    String? id,
    String? title,
    String? composer,
    int? tempoBpm,
    List<ScorePart>? parts,
    DateTime? updatedAt,
  }) => Score(
    id: id ?? this.id,
    title: title ?? this.title,
    composer: composer ?? this.composer,
    tempoBpm: tempoBpm ?? this.tempoBpm,
    parts: parts ?? this.parts,
    updatedAt: updatedAt ?? this.updatedAt,
  );

  Score withPartReplacedAt(int index, ScorePart part) => copyWith(
    parts: [
      for (var i = 0; i < parts.length; i++) if (i == index) part else parts[i],
    ],
  );

  Score withPartAdded(ScorePart part) => copyWith(parts: [...parts, part]);

  Score withPartRemovedAt(int index) => copyWith(
    parts: [for (var i = 0; i < parts.length; i++) if (i != index) parts[i]],
  );

  Map<String, dynamic> toMap() => {
    'title': title,
    'composer': composer,
    'tempoBpm': tempoBpm,
    'parts': [for (final p in parts) p.toMap()],
  };

  static Score fromMap(String id, Map<String, dynamic> m, {DateTime? updatedAt}) =>
      Score(
        id: id,
        title: m['title'] as String? ?? '無題の曲',
        composer: m['composer'] as String? ?? '',
        tempoBpm: (m['tempoBpm'] as num?)?.toInt() ?? 120,
        parts: [
          for (final p in (m['parts'] as List<dynamic>? ?? const []))
            ScorePart.fromMap(Map<String, dynamic>.from(p as Map)),
        ],
        updatedAt: updatedAt,
      );

  /// 新規作成用：1パート・1小節だけの空の曲
  factory Score.blank({String title = '無題の曲'}) => Score(
    title: title,
    parts: [
      ScorePart(
        id: 'part1',
        name: 'パート1',
        measures: const [Measure()],
      ),
    ],
  );
}
