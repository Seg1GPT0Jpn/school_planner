/// メトロノームのプリセット（曲ごとの設定をまるごと保存する）
library;

import '../tone_synth.dart';
import 'accent.dart';
import 'rhythm_pattern.dart';
import 'tempo_ramp.dart';
import 'time_signature.dart';

class MetronomePreset {
  const MetronomePreset({
    required this.id,
    required this.name,
    required this.bpm,
    required this.timeSignature,
    required this.pattern,
    required this.timbre,
    required this.countInBars,
    required this.muteEnabled,
    required this.muteOnBars,
    required this.muteOffBars,
    required this.tempoRamp,
    required this.updatedAt,
  });

  final String id;
  final String name;
  final int bpm;
  final TimeSignature timeSignature;
  final RhythmPattern pattern;
  final ClickTimbre timbre;
  final int countInBars;
  final bool muteEnabled;
  final int muteOnBars;
  final int muteOffBars;
  final TempoRamp tempoRamp;
  final DateTime updatedAt;

  Map<String, dynamic> toMap() => {
    'name': name,
    'bpm': bpm,
    'beats': timeSignature.beats,
    'denominator': timeSignature.denominator,
    'grouping': timeSignature.grouping,
    'timeSignatureLabel': timeSignature.label,
    'subdivision': pattern.subdivision,
    // Firestoreは配列の中に配列を直接入れられないため、各行をmapで包む
    // （{'slots': [...]} の形にする）。
    'grid': [
      for (final row in pattern.grid)
        {
          'slots': [for (final slot in row) {'a': slot.active, 'l': slot.level.name}],
        },
    ],
    'timbre': timbre.name,
    'countInBars': countInBars,
    'muteEnabled': muteEnabled,
    'muteOnBars': muteOnBars,
    'muteOffBars': muteOffBars,
    'rampMode': tempoRamp.mode.name,
    'rampStepBpm': tempoRamp.stepBpm,
    'rampEveryBars': tempoRamp.everyBars,
    'rampMinBpm': tempoRamp.minBpm,
    'rampMaxBpm': tempoRamp.maxBpm,
  };

  static MetronomePreset fromMap(String id, Map<String, dynamic> m, DateTime updatedAt) {
    final beats = (m['beats'] as num?)?.toInt() ?? 4;
    final subdivision = (m['subdivision'] as num?)?.toInt() ?? 1;
    final rawGrid = m['grid'] as List<dynamic>?;
    List<dynamic>? slotsOf(int b) {
      if (rawGrid == null || b >= rawGrid.length) return null;
      final row = rawGrid[b];
      if (row is Map) return row['slots'] as List<dynamic>?;
      if (row is List) return row; // 旧形式（配列の中に配列）との後方互換
      return null;
    }

    final grid = <List<RhythmSlot>>[
      for (var b = 0; b < beats; b++)
        [
          for (var s = 0; s < subdivision; s++)
            if (slotsOf(b) != null && s < slotsOf(b)!.length)
              RhythmSlot(
                active: (slotsOf(b)![s] as Map)['a'] as bool? ?? true,
                level: DynamicLevel.values.firstWhere(
                  (v) => v.name == (slotsOf(b)![s] as Map)['l'],
                  orElse: () => DynamicLevel.mf,
                ),
              )
            else
              RhythmSlot(active: s == 0, level: s == 0 ? DynamicLevel.mf : DynamicLevel.p),
        ],
    ];
    return MetronomePreset(
      id: id,
      name: m['name'] as String? ?? '無題',
      bpm: (m['bpm'] as num?)?.toInt() ?? 100,
      timeSignature: TimeSignature(
        beats: beats,
        denominator: (m['denominator'] as num?)?.toInt() ?? 4,
        grouping: [for (final g in (m['grouping'] as List? ?? [beats])) (g as num).toInt()],
        label: m['timeSignatureLabel'] as String?,
      ),
      pattern: RhythmPattern(beats: beats, subdivision: subdivision, grid: grid),
      timbre: ClickTimbre.values.firstWhere(
        (t) => t.name == m['timbre'],
        orElse: () => ClickTimbre.classic,
      ),
      countInBars: (m['countInBars'] as num?)?.toInt() ?? 0,
      muteEnabled: m['muteEnabled'] as bool? ?? false,
      muteOnBars: (m['muteOnBars'] as num?)?.toInt() ?? 4,
      muteOffBars: (m['muteOffBars'] as num?)?.toInt() ?? 2,
      tempoRamp: TempoRamp(
        mode: TempoRampMode.values.firstWhere(
          (v) => v.name == m['rampMode'],
          orElse: () => TempoRampMode.off,
        ),
        stepBpm: (m['rampStepBpm'] as num?)?.toInt() ?? 4,
        everyBars: (m['rampEveryBars'] as num?)?.toInt() ?? 4,
        minBpm: (m['rampMinBpm'] as num?)?.toInt() ?? 60,
        maxBpm: (m['rampMaxBpm'] as num?)?.toInt() ?? 160,
      ),
      updatedAt: updatedAt,
    );
  }
}
