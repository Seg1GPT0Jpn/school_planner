/// ドローン（基準音を鳴らし続ける。音程・和音の確認用）
///
/// 単音のほか、複数音を同時に鳴らす「和音モード」にも対応。
/// 和音モードでは、選んだ和音を平均律／純正律それぞれで鳴らし分けられ、
/// 一番低い音を主音として、各音のセント差（純正律−平均律）も表示する。
library;

import 'dart:async';
import 'dart:math' as math;

import 'package:audioplayers/audioplayers.dart';
import 'package:material_ui/material_ui.dart';

import 'music_theory.dart';
import 'tone_synth.dart';

const _notes = ['C', 'C#', 'D', 'D#', 'E', 'F', 'F#', 'G', 'G#', 'A', 'A#', 'B'];

const _intervalNames = [
  '主音',
  '短2度',
  '長2度',
  '短3度',
  '長3度',
  '完全4度',
  '増4度',
  '完全5度',
  '短6度',
  '長6度',
  '短7度',
  '長7度',
];

/// 和音プリセット：選んだルート音からの半音差
const _chordPresets = <String, List<int>>{
  'メジャー': [0, 4, 7],
  'マイナー': [0, 3, 7],
  '属七': [0, 4, 7, 10],
  '減三': [0, 3, 6],
  '増三': [0, 4, 8],
  '完全5度': [0, 7],
};

class DroneTab extends StatefulWidget {
  const DroneTab({super.key});

  @override
  State<DroneTab> createState() => _DroneTabState();
}

class _DroneTabState extends State<DroneTab> {
  String _note = 'C';
  int _octave = 4;
  bool _playing = false;
  final _player = AudioPlayer();

  bool _chordMode = false;
  final Set<int> _chordPitchClasses = {0, 4, 7}; // 初期値：ドミソ
  int _chordRoot = 0;
  Temperament _chordTemperament = Temperament.equal;
  final List<AudioPlayer> _chordPlayers = [];

  double get _freq => frequencyOf(_note, _octave);

  Future<void> _toggle() async {
    if (_playing) {
      await _stopAll();
      return;
    }
    if (_chordMode) {
      await _playChord();
    } else {
      await _player.setReleaseMode(ReleaseMode.loop);
      await _player.play(BytesSource(generateToneWav(_freq)));
    }
    setState(() => _playing = true);
  }

  Future<void> _playChord() async {
    await _stopChordPlayers();
    final sorted = _chordPitchClasses.toList()..sort();
    if (sorted.isEmpty) return;
    // ルート音は「選んだ和音のうち一番低い番号の音」ではなく、
    // 別途選べる「ルート音」チップの値を使う（A・C#・Eのようにピッチクラス番号が
    // 小さい順=ルートとは限らないため）。
    final rootPc = _chordRoot;
    final rootMidi = (_octave + 1) * 12 + rootPc;
    for (final pc in sorted) {
      // 主音（ルート）から見て何半音上かで並べる（0〜11）。ピッチクラスの
      // 番号だけで音の高さを決めると、A・C#・E のような和音でルートより
      // 低い音が混ざってしまう（幹音が最低音にならない）ため、必ず
      // ルートを一番下にして、そこから3音・5音…と積み上げる。
      final offset = ((pc - rootPc) + 12) % 12;
      final midi = rootMidi + offset;
      final freq = frequencyForMidi(
        midi.toDouble(),
        referenceHz: 440,
        temperament: _chordTemperament,
        tonicPitchClass: rootPc,
      );
      final p = AudioPlayer();
      await p.setReleaseMode(ReleaseMode.loop);
      await p.play(BytesSource(generateToneWav(freq)));
      _chordPlayers.add(p);
    }
  }

  Future<void> _stopChordPlayers() async {
    for (final p in _chordPlayers) {
      await p.stop();
      await p.dispose();
    }
    _chordPlayers.clear();
  }

  Future<void> _stopAll() async {
    await _player.stop();
    await _stopChordPlayers();
    setState(() => _playing = false);
  }

  void _applyChordPreset(List<int> offsets) {
    setState(() {
      _chordPitchClasses
        ..clear()
        ..addAll([for (final o in offsets) (_chordRoot + o) % 12]);
    });
    unawaited(_restartIfPlaying());
  }

  Future<void> _restartIfPlaying() async {
    if (!_playing) return;
    if (_chordMode) {
      await _playChord();
    } else {
      await _player.stop();
      await _player.play(BytesSource(generateToneWav(_freq)));
    }
  }

  @override
  void dispose() {
    _player.dispose();
    unawaited(_stopChordPlayers());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        const Text('選んだ音を鳴らし続けます。チューニングや、和音・音程の確認に使えます。'),
        const SizedBox(height: 12),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('和音モード'),
          subtitle: const Text('複数の音を同時に鳴らします'),
          value: _chordMode,
          onChanged: (v) async {
            await _stopAll();
            setState(() => _chordMode = v);
          },
        ),
        const SizedBox(height: 8),
        if (!_chordMode) ..._singleNoteUi(cs) else ..._chordUi(cs),
        const SizedBox(height: 28),
        Center(
          child: FilledButton.icon(
            onPressed: _toggle,
            icon: Icon(_playing ? Icons.stop : Icons.play_arrow),
            label: Text(_playing ? '止める' : '鳴らす'),
          ),
        ),
      ],
    );
  }

  List<Widget> _singleNoteUi(ColorScheme cs) => [
    Center(
      child: Text(
        '$_note$_octave',
        style: Theme.of(context).textTheme.displayMedium?.copyWith(fontWeight: FontWeight.bold),
      ),
    ),
    Center(
      child: Text('${_freq.toStringAsFixed(1)} Hz', style: TextStyle(color: cs.outline)),
    ),
    const SizedBox(height: 20),
    Wrap(
      alignment: WrapAlignment.center,
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final n in _notes)
          ChoiceChip(
            label: Text(n),
            selected: _note == n,
            onSelected: (_) {
              setState(() => _note = n);
              unawaited(_restartIfPlaying());
            },
          ),
      ],
    ),
    const SizedBox(height: 12),
    Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Text('オクターブ　'),
        IconButton(
          onPressed: () {
            setState(() => _octave = (_octave - 1).clamp(1, 7).toInt());
            unawaited(_restartIfPlaying());
          },
          icon: const Icon(Icons.remove_circle_outline),
        ),
        Text('$_octave'),
        IconButton(
          onPressed: () {
            setState(() => _octave = (_octave + 1).clamp(1, 7).toInt());
            unawaited(_restartIfPlaying());
          },
          icon: const Icon(Icons.add_circle_outline),
        ),
      ],
    ),
    const SizedBox(height: 8),
    Wrap(
      alignment: WrapAlignment.center,
      spacing: 8,
      children: [
        OutlinedButton(
          onPressed: () {
            setState(() {
              _note = 'A';
              _octave = 4;
            });
            unawaited(_restartIfPlaying());
          },
          child: const Text('A4（コンサートピッチ 440Hz）'),
        ),
        OutlinedButton(
          onPressed: () {
            setState(() {
              _note = 'A#';
              _octave = 3;
            });
            unawaited(_restartIfPlaying());
          },
          child: const Text('B♭3（B♭管の基準音）'),
        ),
      ],
    ),
  ];

  List<Widget> _chordUi(ColorScheme cs) {
    final sorted = _chordPitchClasses.toList()..sort();
    final rootPc = _chordRoot;
    return [
      Text('和音プリセット', style: Theme.of(context).textTheme.labelLarge),
      const SizedBox(height: 6),
      Text('ルート音', style: TextStyle(color: cs.outline, fontSize: 12)),
      const SizedBox(height: 4),
      Wrap(
        spacing: 6,
        runSpacing: 6,
        children: [
          for (var pc = 0; pc < 12; pc++)
            ChoiceChip(
              label: Text(noteNameFor(pc, NotationSystem.english)),
              selected: _chordRoot == pc,
              onSelected: (_) => setState(() => _chordRoot = pc),
            ),
        ],
      ),
      const SizedBox(height: 8),
      Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          for (final entry in _chordPresets.entries)
            ActionChip(
              avatar: const Icon(Icons.piano, size: 18),
              label: Text(entry.key),
              onPressed: () => _applyChordPreset(entry.value),
            ),
        ],
      ),
      const SizedBox(height: 12),
      Row(
        children: [
          Text('オクターブ　', style: Theme.of(context).textTheme.labelLarge),
          IconButton(
            onPressed: () {
              setState(() => _octave = (_octave - 1).clamp(1, 7).toInt());
              unawaited(_restartIfPlaying());
            },
            icon: const Icon(Icons.remove_circle_outline),
          ),
          Text('$_octave'),
          IconButton(
            onPressed: () {
              setState(() => _octave = (_octave + 1).clamp(1, 7).toInt());
              unawaited(_restartIfPlaying());
            },
            icon: const Icon(Icons.add_circle_outline),
          ),
        ],
      ),
      const SizedBox(height: 16),
      Text('音を選ぶ（複数選択・微調整用）', style: Theme.of(context).textTheme.labelLarge),
      const SizedBox(height: 6),
      Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          for (var pc = 0; pc < 12; pc++)
            FilterChip(
              label: Text(noteNameFor(pc, NotationSystem.english)),
              selected: _chordPitchClasses.contains(pc),
              onSelected: (sel) {
                setState(() {
                  if (sel) {
                    _chordPitchClasses.add(pc);
                  } else {
                    _chordPitchClasses.remove(pc);
                  }
                });
                unawaited(_restartIfPlaying());
              },
            ),
        ],
      ),
      const SizedBox(height: 12),
      Text('音律', style: Theme.of(context).textTheme.labelLarge),
      const SizedBox(height: 6),
      Wrap(
        spacing: 8,
        children: [
          for (final t in [Temperament.equal, Temperament.just])
            ChoiceChip(
              label: Text(t.label),
              selected: _chordTemperament == t,
              onSelected: (_) {
                setState(() => _chordTemperament = t);
                unawaited(_restartIfPlaying());
              },
            ),
        ],
      ),
      const SizedBox(height: 16),
      if (sorted.length >= 2) ...[
        Text('和音チューニング比較（主音：${noteNameFor(rootPc, NotationSystem.english)}）',
            style: Theme.of(context).textTheme.labelLarge),
        const SizedBox(height: 6),
        Card(
          margin: EdgeInsets.zero,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final pc in sorted) _intervalRow(cs, rootPc, pc),
                const SizedBox(height: 4),
                Text(
                  '「純正律−平均律」のセント差です。純正律のほうが整数比なので、'
                  '和音として響かせたときのうなりが少なくなります。',
                  style: TextStyle(color: cs.outline, fontSize: 11),
                ),
              ],
            ),
          ),
        ),
      ],
    ];
  }

  Widget _intervalRow(ColorScheme cs, int rootPc, int pc) {
    final idx = ((pc - rootPc) + 12) % 12;
    final equalCentsFromRoot = idx * 100.0;
    final justRatio = justIntonationRatios[idx];
    final justCentsFromRoot = 1200 * (math.log(justRatio) / math.ln2);
    final diff = justCentsFromRoot - equalCentsFromRoot;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          SizedBox(width: 90, child: Text(_intervalNames[idx])),
          SizedBox(width: 40, child: Text(noteNameFor(pc, NotationSystem.english))),
          Text(
            idx == 0 ? '±0¢' : '${diff >= 0 ? '+' : ''}${diff.toStringAsFixed(1)}¢',
            style: TextStyle(
              color: idx == 0 ? cs.outline : cs.primary,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}
