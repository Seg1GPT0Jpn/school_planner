/// ピアノ（鍵盤をタップして音を鳴らす）
///
/// ・複数オクターブの鍵盤（横スクロールで広い音域まで見られる）
/// ・音色：ピアノ／エレピ／オルガン／ハープシコード／シンセ
/// ・音名表示のON/OFF、基準音（Hz）の調整
/// ・音取り・ピッチ確認、和音（ハーモニー）の響きの確認に使う
library;

import 'dart:async';
import 'dart:typed_data';

import 'package:audioplayers/audioplayers.dart';
import 'package:material_ui/material_ui.dart';

import 'tone_synth.dart';

const _whiteNotes = ['C', 'D', 'E', 'F', 'G', 'A', 'B'];

/// 白鍵のインデックス（0〜6）のうち、直後に黒鍵があるもの（E・Bの後にはない）
const _blackAfterWhite = {0: 'C#', 1: 'D#', 3: 'F#', 4: 'G#', 5: 'A#'};

class PianoTab extends StatefulWidget {
  const PianoTab({super.key});

  @override
  State<PianoTab> createState() => _PianoTabState();
}

class _PianoTabState extends State<PianoTab> {
  static const _whiteKeyWidth = 46.0;
  static const _whiteKeyHeight = 170.0;
  static const _blackKeyWidth = 28.0;
  static const _blackKeyHeight = 104.0;

  final List<AudioPlayer> _playerPool = List.generate(10, (_) => AudioPlayer());
  int _playerIndex = 0;
  final Map<String, Uint8List> _cache = {};
  final Set<String> _pressed = {};

  PianoTone _tone = PianoTone.piano;
  bool _showNames = true;
  double _referenceHz = 442;
  int _octaveStart = 3;
  int _octaveCount = 3;

  @override
  void initState() {
    super.initState();
    for (final p in _playerPool) {
      unawaited(p.setPlayerMode(PlayerMode.lowLatency));
    }
  }

  @override
  void dispose() {
    for (final p in _playerPool) {
      unawaited(p.dispose());
    }
    super.dispose();
  }

  Uint8List _wavFor(String noteName, int octave) {
    final key = '${_tone.name}_${noteName}_${octave}_${_referenceHz.round()}';
    return _cache.putIfAbsent(key, () {
      final freq = frequencyOf(noteName, octave, referenceHz: _referenceHz);
      return generatePianoNoteWav(freq, _tone);
    });
  }

  void _play(String noteName, int octave) {
    final bytes = _wavFor(noteName, octave);
    final player = _playerPool[_playerIndex];
    _playerIndex = (_playerIndex + 1) % _playerPool.length;
    unawaited(player.play(BytesSource(bytes)));
  }

  void _keyDown(String noteName, int octave) {
    setState(() => _pressed.add('$noteName$octave'));
    _play(noteName, octave);
  }

  void _keyUp(String noteName, int octave) {
    setState(() => _pressed.remove('$noteName$octave'));
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              const Text(
                '鍵盤をタップすると音が鳴ります。音取りやピッチ確認、和音の響きの確認に使えます。',
              ),
              const SizedBox(height: 12),
              Card(
                margin: EdgeInsets.zero,
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('音色', style: Theme.of(context).textTheme.labelLarge),
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          for (final t in PianoTone.values)
                            ChoiceChip(
                              label: Text(t.label),
                              selected: _tone == t,
                              onSelected: (_) => setState(() => _tone = t),
                            ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Text('表示する音域', style: Theme.of(context).textTheme.labelLarge),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          const Text('低音側　'),
                          IconButton(
                            onPressed: () => setState(
                              () => _octaveStart = (_octaveStart - 1).clamp(0, 7).toInt(),
                            ),
                            icon: const Icon(Icons.remove_circle_outline),
                          ),
                          Text('C$_octaveStart〜'),
                          IconButton(
                            onPressed: () => setState(
                              () => _octaveStart = (_octaveStart + 1).clamp(0, 7).toInt(),
                            ),
                            icon: const Icon(Icons.add_circle_outline),
                          ),
                          const Spacer(),
                          Wrap(
                            spacing: 6,
                            children: [
                              for (final n in const [2, 3, 4])
                                ChoiceChip(
                                  label: Text('$n オクターブ'),
                                  selected: _octaveCount == n,
                                  onSelected: (_) => setState(() => _octaveCount = n),
                                ),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('音名を表示'),
                        value: _showNames,
                        onChanged: (v) => setState(() => _showNames = v),
                      ),
                      Row(
                        children: [
                          Text('基準音　', style: Theme.of(context).textTheme.labelLarge),
                          Text('${_referenceHz.toStringAsFixed(0)} Hz'),
                          const Spacer(),
                          IconButton(
                            onPressed: () => setState(
                              () => _referenceHz = (_referenceHz - 1).clamp(415, 466).toDouble(),
                            ),
                            icon: const Icon(Icons.remove_circle_outline),
                          ),
                          IconButton(
                            onPressed: () => setState(
                              () => _referenceHz = (_referenceHz + 1).clamp(415, 466).toDouble(),
                            ),
                            icon: const Icon(Icons.add_circle_outline),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                '画面の横スクロールで、表示しきれない鍵盤も見られます。',
                style: TextStyle(color: cs.outline, fontSize: 12),
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
        SafeArea(
          top: false,
          child: SizedBox(
            height: _whiteKeyHeight + 12,
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              child: _keyboard(cs),
            ),
          ),
        ),
      ],
    );
  }

  Widget _keyboard(ColorScheme cs) {
    final whiteCount = 7 * _octaveCount;
    final width = whiteCount * _whiteKeyWidth;

    Widget whiteKey(int globalIndex) {
      final octave = _octaveStart + globalIndex ~/ 7;
      final noteName = _whiteNotes[globalIndex % 7];
      final id = '$noteName$octave';
      final isPressed = _pressed.contains(id);
      return Positioned(
        left: globalIndex * _whiteKeyWidth,
        top: 0,
        width: _whiteKeyWidth - 2,
        height: _whiteKeyHeight,
        child: GestureDetector(
          onTapDown: (_) => _keyDown(noteName, octave),
          onTapUp: (_) => _keyUp(noteName, octave),
          onTapCancel: () => _keyUp(noteName, octave),
          child: Container(
            decoration: BoxDecoration(
              color: isPressed ? cs.primaryContainer : Colors.white,
              border: Border.all(color: cs.outlineVariant),
              borderRadius: const BorderRadius.vertical(bottom: Radius.circular(4)),
            ),
            alignment: Alignment.bottomCenter,
            padding: const EdgeInsets.only(bottom: 6),
            child: _showNames
                ? Text(
                    id,
                    style: TextStyle(
                      fontSize: 10,
                      color: isPressed ? cs.primary : Colors.black54,
                    ),
                  )
                : null,
          ),
        ),
      );
    }

    Widget blackKey(int globalIndex) {
      final octaveOffset = globalIndex ~/ 7;
      final withinOctave = globalIndex % 7;
      final sharpName = _blackAfterWhite[withinOctave];
      if (sharpName == null) return const SizedBox.shrink();
      final octave = _octaveStart + octaveOffset;
      final id = '$sharpName$octave';
      final isPressed = _pressed.contains(id);
      final x = (globalIndex + 1) * _whiteKeyWidth - _blackKeyWidth / 2;
      return Positioned(
        left: x,
        top: 0,
        width: _blackKeyWidth,
        height: _blackKeyHeight,
        child: GestureDetector(
          onTapDown: (_) => _keyDown(sharpName, octave),
          onTapUp: (_) => _keyUp(sharpName, octave),
          onTapCancel: () => _keyUp(sharpName, octave),
          child: Container(
            decoration: BoxDecoration(
              color: isPressed ? cs.primary : Colors.black87,
              borderRadius: const BorderRadius.vertical(bottom: Radius.circular(3)),
            ),
            alignment: Alignment.bottomCenter,
            padding: const EdgeInsets.only(bottom: 4),
            child: _showNames
                ? Text(
                    id,
                    style: const TextStyle(fontSize: 8, color: Colors.white70),
                  )
                : null,
          ),
        ),
      );
    }

    return SizedBox(
      width: width,
      height: _whiteKeyHeight,
      child: Stack(
        children: [
          for (var i = 0; i < whiteCount; i++) whiteKey(i),
          for (var i = 0; i < whiteCount; i++) blackKey(i),
        ],
      ),
    );
  }
}
