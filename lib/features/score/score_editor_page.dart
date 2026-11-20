/// 楽譜編集画面（フェーズ1：単一パートの音符入力・表示・再生）
library;

import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:material_ui/material_ui.dart';

import '../practice_tools/tone_synth.dart' show PianoTone;
import 'model/clef.dart';
import 'model/duration.dart';
import 'model/key_signature.dart';
import 'model/measure.dart';
import 'model/pitch.dart';
import 'model/score.dart';
import 'model/time_signature.dart';
import 'playback/score_player.dart';
import 'rendering/staff_layout.dart';
import 'rendering/staff_painter.dart';
import 'score_repository.dart';

/// 楽譜編集画面を開く（[scoreId] が null なら新規作成）
void openScoreEditor(BuildContext context, {String? scoreId}) {
  Navigator.of(context, rootNavigator: true).push(
    MaterialPageRoute<void>(builder: (_) => ScoreEditorPage(scoreId: scoreId)),
  );
}

const List<String> _solfegeNames = ['ド', 'レ', 'ミ', 'ファ', 'ソ', 'ラ', 'シ'];

class ScoreEditorPage extends StatefulWidget {
  const ScoreEditorPage({super.key, this.scoreId});

  /// null なら新規作成
  final String? scoreId;

  @override
  State<ScoreEditorPage> createState() => _ScoreEditorPageState();
}

class _ScoreEditorPageState extends State<ScoreEditorPage> {
  late final ScoreRepository _repository;
  late final ScorePlayer _player;
  StreamSubscription<Score?>? _sub;

  Score _score = Score.blank();
  bool _loaded = false;
  bool _dirty = false;
  bool _saving = false;

  int _partIndex = 0;
  (int, int)? _selected;
  (int, int)? _playingAt;
  bool _playingAll = false;

  final List<Score> _undoStack = [];
  final List<Score> _redoStack = [];

  int _pendingStep = 0;
  int _pendingAlter = 0;
  int _pendingOctave = 4;
  NoteDurationBase _pendingBase = NoteDurationBase.quarter;
  int _pendingDots = 0;

  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    final uid = FirebaseAuth.instance.currentUser!.uid;
    _repository = ScoreRepository(uid: uid);
    _player = ScorePlayer(tone: PianoTone.piano);
    unawaited(_player.init());

    if (widget.scoreId != null) {
      _sub = _repository.watch(widget.scoreId!).listen((s) {
        if (s == null || !mounted) return;
        setState(() {
          _score = s;
          _loaded = true;
        });
      });
    } else {
      _loaded = true;
    }
  }

  @override
  void dispose() {
    _sub?.cancel();
    _player.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  ScorePart get _part => _score.parts[_partIndex];

  void _pushUndo() {
    _undoStack.add(_score);
    if (_undoStack.length > 100) _undoStack.removeAt(0);
    _redoStack.clear();
  }

  void _undo() {
    if (_undoStack.isEmpty) return;
    final prev = _undoStack.removeLast();
    setState(() {
      _redoStack.add(_score);
      _score = prev;
      if (_partIndex >= _score.parts.length) {
        _partIndex = _score.parts.length - 1;
      }
      _selected = null;
      _dirty = true;
    });
  }

  void _redo() {
    if (_redoStack.isEmpty) return;
    final next = _redoStack.removeLast();
    setState(() {
      _undoStack.add(_score);
      _score = next;
      if (_partIndex >= _score.parts.length) {
        _partIndex = _score.parts.length - 1;
      }
      _selected = null;
      _dirty = true;
    });
  }

  void _updatePart(ScorePart Function(ScorePart) f) {
    _pushUndo();
    setState(() {
      _score = _score.withPartReplacedAt(_partIndex, f(_part));
      _dirty = true;
    });
  }

  NoteDuration get _pendingDuration =>
      NoteDuration(_pendingBase, dots: _pendingDots);

  Pitch get _pendingPitch =>
      Pitch(step: _pendingStep, alter: _pendingAlter, octave: _pendingOctave);

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      final id = await _repository.save(_score);
      if (!mounted) return;
      setState(() {
        _score = _score.copyWith(id: id);
        _dirty = false;
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('保存しました')));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<bool> _confirmDiscard() async {
    if (!_dirty) return true;
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('保存していない変更があります'),
        content: const Text('保存せずに閉じますか？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(c).pop(false),
            child: const Text('キャンセル'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(c).pop(true),
            child: const Text('保存せず閉じる'),
          ),
        ],
      ),
    );
    return ok == true;
  }

  // ---------------- 音符の追加・編集・削除 ----------------

  void _addNote({required bool rest}) {
    final duration = _pendingDuration;
    final beatsPerMeasure = _part.timeSignature.beatsPerMeasure;
    if (duration.beats > beatsPerMeasure + 0.0001) {
      // この音価だと、どの小節にも（空の小節にも）絶対に入らない
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'この音価（${duration.beats}拍）は、今の拍子（${_part.timeSignature.label}）'
            'の1小節（$beatsPerMeasure拍）より長いので入れられません。',
          ),
        ),
      );
      return;
    }
    var measures = _part.measures;
    if (measures.isEmpty) {
      _updatePart((p) => p.copyWith(measures: const [Measure()]));
      measures = _part.measures;
    }
    var measureIndex = _selected?.$1 ?? measures.length - 1;
    if (measureIndex >= measures.length) measureIndex = measures.length - 1;
    var measure = measures[measureIndex];

    if (!measure.hasRoomFor(duration, beatsPerMeasure)) {
      if (measureIndex + 1 >= _part.measures.length) {
        _updatePart((p) => p.withMeasureAdded());
      }
      setState(() => _selected = (measureIndex + 1, 0));
      _addNote(rest: rest);
      return;
    }

    final note = ScoreNote(
      pitches: rest ? const [] : [_pendingPitch],
      duration: duration,
    );
    final newMeasure = measure.withNoteAdded(note);
    final newIndex = newMeasure.notes.length - 1;
    _updatePart((p) => p.withMeasureReplacedAt(measureIndex, newMeasure));
    setState(() => _selected = (measureIndex, newIndex));
  }

  void _deleteSelected() {
    final sel = _selected;
    if (sel == null) return;
    final measure = _part.measures[sel.$1];
    if (sel.$2 >= measure.notes.length) return;
    final newMeasure = measure.withNoteRemovedAt(sel.$2);
    _updatePart((p) => p.withMeasureReplacedAt(sel.$1, newMeasure));
    setState(() {
      _selected = newMeasure.notes.isEmpty ? null : (sel.$1, 0);
    });
  }

  ScoreNote? get _selectedNote {
    final sel = _selected;
    if (sel == null) return null;
    final measure = _part.measures[sel.$1];
    if (sel.$2 < 0 || sel.$2 >= measure.notes.length) return null;
    return measure.notes[sel.$2];
  }

  void _onPitchTap(int step) {
    setState(() => _pendingStep = step);
    _applyToSelected((old) =>
        old.isRest ? old : old.copyWith(pitches: [_pendingPitch]));
  }

  void _shiftOctave(int delta) {
    setState(() => _pendingOctave = (_pendingOctave + delta).clamp(0, 8));
    _applyToSelected((old) =>
        old.isRest ? old : old.copyWith(pitches: [_pendingPitch]));
  }

  void _setAlter(int alter) {
    setState(() => _pendingAlter = alter);
    _applyToSelected((old) =>
        old.isRest ? old : old.copyWith(pitches: [_pendingPitch]));
  }

  void _onDurationTap(NoteDurationBase base) {
    setState(() => _pendingBase = base);
    _applyToSelected((old) => old.copyWith(duration: _pendingDuration));
  }

  void _toggleDots() {
    setState(() => _pendingDots = _pendingDots >= 2 ? 0 : _pendingDots + 1);
    _applyToSelected((old) => old.copyWith(duration: _pendingDuration));
  }

  void _toggleTie() {
    _applyToSelected((old) => old.copyWith(tiedToNext: !old.tiedToNext));
  }

  void _applyToSelected(ScoreNote Function(ScoreNote) f) {
    final sel = _selected;
    if (sel == null) return;
    final measure = _part.measures[sel.$1];
    if (sel.$2 >= measure.notes.length) return;
    final updated = f(measure.notes[sel.$2]);
    _updatePart(
      (p) =>
          p.withMeasureReplacedAt(sel.$1, measure.withNoteReplacedAt(sel.$2, updated)),
    );
  }

  void _handleTap(TapUpDetails details, PartLayout layout) {
    final x = details.localPosition.dx;
    final hit = layout.hitTest(x);
    if (hit != null) {
      final note = _part.measures[hit.$1].notes[hit.$2];
      setState(() {
        _selected = hit;
        if (!note.isRest) {
          final p = note.pitches.first;
          _pendingStep = p.step;
          _pendingAlter = p.alter;
          _pendingOctave = p.octave;
        }
        _pendingBase = note.duration.base;
        _pendingDots = note.duration.dots;
      });
      return;
    }
    final mi = layout.measureIndexAt(x);
    if (mi != null) {
      setState(() => _selected = (mi, _part.measures[mi].notes.length));
    }
  }

  // ---------------- 再生 ----------------

  void _togglePlay() {
    if (_player.isPlaying) {
      _player.stop();
      setState(() {
        _playingAt = null;
        _playingAll = false;
      });
      return;
    }
    setState(() => _playingAll = false);
    _player.play(
      _part,
      _score.tempoBpm,
      onNote: (mi, ni) {
        if (!mounted) return;
        setState(() => _playingAt = (mi, ni));
      },
      onDone: () {
        if (!mounted) return;
        setState(() => _playingAt = null);
      },
    );
    setState(() {});
  }

  /// 全パートを同時に（アンサンブルとして）再生する
  void _togglePlayAll() {
    if (_player.isPlaying) {
      _player.stop();
      setState(() {
        _playingAt = null;
        _playingAll = false;
      });
      return;
    }
    setState(() => _playingAll = true);
    _player.playParts(
      _score.parts,
      _score.tempoBpm,
      onNote: (pi, mi, ni) {
        if (!mounted || pi != _partIndex) return;
        setState(() => _playingAt = (mi, ni));
      },
      onDone: () {
        if (!mounted) return;
        setState(() {
          _playingAt = null;
          _playingAll = false;
        });
      },
    );
    setState(() {});
  }

  // ---------------- パート設定（音部記号・調号・拍子・テンポ） ----------------

  Future<void> _editPartSettings() async {
    var clef = _part.clef;
    var fifths = _part.keySignature.fifths;
    var timeSig = _part.timeSignature;
    final tempoController = TextEditingController(text: '${_score.tempoBpm}');
    final titleController = TextEditingController(text: _score.title);
    final composerController = TextEditingController(text: _score.composer);

    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => StatefulBuilder(
        builder: (c, setDialogState) => AlertDialog(
          title: const Text('曲・パートの設定'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextField(
                  controller: titleController,
                  decoration: const InputDecoration(labelText: '曲名'),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: composerController,
                  decoration: const InputDecoration(labelText: '作曲者'),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: tempoController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'テンポ（♩=）'),
                ),
                const SizedBox(height: 12),
                const Text('音部記号'),
                SegmentedButton<Clef>(
                  segments: const [
                    ButtonSegment(value: Clef.treble, label: Text('ト音記号')),
                    ButtonSegment(value: Clef.bass, label: Text('ヘ音記号')),
                  ],
                  selected: {clef},
                  onSelectionChanged: (s) =>
                      setDialogState(() => clef = s.first),
                ),
                const SizedBox(height: 12),
                const Text('拍子'),
                Wrap(
                  spacing: 6,
                  children: [
                    for (final ts in commonTimeSignatures)
                      ChoiceChip(
                        label: Text(ts.label),
                        selected: timeSig == ts,
                        onSelected: (_) => setDialogState(() => timeSig = ts),
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                Text('調号：${KeySignature(fifths).label}'),
                Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.remove),
                      onPressed: () => setDialogState(
                        () => fifths = (fifths - 1).clamp(-7, 7),
                      ),
                    ),
                    Text('$fifths'),
                    IconButton(
                      icon: const Icon(Icons.add),
                      onPressed: () => setDialogState(
                        () => fifths = (fifths + 1).clamp(-7, 7),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(c).pop(false),
              child: const Text('キャンセル'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(c).pop(true),
              child: const Text('決定'),
            ),
          ],
        ),
      ),
    );
    if (ok != true) return;

    _pushUndo();
    setState(() {
      _score = _score.copyWith(
        title: titleController.text.trim().isEmpty
            ? _score.title
            : titleController.text.trim(),
        composer: composerController.text.trim(),
        tempoBpm: int.tryParse(tempoController.text) ?? _score.tempoBpm,
      );
      _score = _score.withPartReplacedAt(
        _partIndex,
        _part.copyWith(
          clef: clef,
          timeSignature: timeSig,
          keySignature: KeySignature(fifths),
        ),
      );
      _dirty = true;
    });
  }

  // ---------------- パート管理（追加・名前変更・削除・切り替え） ----------------

  Future<String?> _promptPartName(
    BuildContext context, {
    required String initial,
  }) {
    final controller = TextEditingController(text: initial);
    return showDialog<String>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('パート名'),
        content: TextField(controller: controller, autofocus: true),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(c).pop(),
            child: const Text('キャンセル'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(c).pop(controller.text),
            child: const Text('決定'),
          ),
        ],
      ),
    );
  }

  Future<void> _addPart() async {
    final name = await _promptPartName(
      context,
      initial: 'パート${_score.parts.length + 1}',
    );
    if (name == null || name.trim().isEmpty || !mounted) return;
    _pushUndo();
    setState(() {
      _score = _score.withPartAdded(
        ScorePart(
          id: 'part_${DateTime.now().millisecondsSinceEpoch}',
          name: name.trim(),
          measures: const [Measure()],
        ),
      );
      _partIndex = _score.parts.length - 1;
      _selected = null;
      _dirty = true;
    });
  }

  Future<void> _renamePart(int index) async {
    final renamed = await _promptPartName(
      context,
      initial: _score.parts[index].name,
    );
    if (renamed == null || renamed.trim().isEmpty || !mounted) return;
    _pushUndo();
    setState(() {
      _score = _score.withPartReplacedAt(
        index,
        _score.parts[index].copyWith(name: renamed.trim()),
      );
      _dirty = true;
    });
  }

  void _removePart(int index) {
    if (_score.parts.length <= 1) return;
    _pushUndo();
    setState(() {
      _score = _score.withPartRemovedAt(index);
      if (_partIndex >= _score.parts.length) {
        _partIndex = _score.parts.length - 1;
      }
      _selected = null;
      _dirty = true;
    });
  }

  Future<void> _managePartsDialog() async {
    await showDialog<void>(
      context: context,
      builder: (c) => StatefulBuilder(
        builder: (c, setDialogState) => AlertDialog(
          title: const Text('パート管理'),
          content: SizedBox(
            width: 360,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (var i = 0; i < _score.parts.length; i++)
                  ListTile(
                    title: Text(_score.parts[i].name),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.edit),
                          tooltip: '名前を変更',
                          onPressed: () async {
                            await _renamePart(i);
                            setDialogState(() {});
                          },
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete_outline),
                          tooltip: '削除',
                          onPressed: _score.parts.length <= 1
                              ? null
                              : () {
                                  _removePart(i);
                                  setDialogState(() {});
                                },
                        ),
                      ],
                    ),
                  ),
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed: () async {
                    await _addPart();
                    setDialogState(() {});
                  },
                  icon: const Icon(Icons.add),
                  label: const Text('パートを追加'),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(c).pop(),
              child: const Text('閉じる'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!_loaded) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    final layout = layoutPart(_part);

    return PopScope(
      canPop: !_dirty,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        final discard = await _confirmDiscard();
        if (discard && context.mounted) {
          Navigator.of(context).pop();
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(_score.title),
          actions: [
            IconButton(
              icon: const Icon(Icons.tune),
              tooltip: '曲・パートの設定',
              onPressed: _editPartSettings,
            ),
            IconButton(
              icon: const Icon(Icons.undo),
              tooltip: '元に戻す',
              onPressed: _undoStack.isEmpty ? null : _undo,
            ),
            IconButton(
              icon: const Icon(Icons.redo),
              tooltip: 'やり直す',
              onPressed: _redoStack.isEmpty ? null : _redo,
            ),
            IconButton(
              icon: Icon(
                (_player.isPlaying && !_playingAll)
                    ? Icons.stop
                    : Icons.play_arrow,
              ),
              tooltip: (_player.isPlaying && !_playingAll) ? '止める' : '再生（このパート）',
              onPressed: _togglePlay,
            ),
            IconButton(
              icon: Icon(_playingAll ? Icons.stop_circle : Icons.queue_music),
              tooltip: _playingAll ? '止める' : '全パート再生',
              onPressed: _score.parts.length <= 1 ? null : _togglePlayAll,
            ),
            IconButton(
              icon: _saving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.save),
              tooltip: '保存',
              onPressed: _saving ? null : _save,
            ),
          ],
        ),
        body: Column(
          children: [
            Container(
              color: Theme.of(context).colorScheme.surfaceContainerLow,
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              child: Row(
                children: [
                  Expanded(
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          for (var i = 0; i < _score.parts.length; i++)
                            Padding(
                              padding: const EdgeInsets.only(right: 6),
                              child: ChoiceChip(
                                label: Text(_score.parts[i].name),
                                selected: _partIndex == i,
                                onSelected: (_) => setState(() {
                                  _partIndex = i;
                                  _selected = null;
                                }),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.people_outline),
                    tooltip: 'パート管理',
                    onPressed: _managePartsDialog,
                  ),
                ],
              ),
            ),
            Container(
              color: Theme.of(context).colorScheme.surfaceContainerLowest,
              child: SingleChildScrollView(
                controller: _scrollController,
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: GestureDetector(
                  onTapUp: (d) => _handleTap(d, layout),
                  child: CustomPaint(
                    size: Size(layout.contentWidth, 140),
                    painter: StaffPainter(
                      part: _part,
                      layout: layout,
                      selected: _playingAt ?? _selected,
                    ),
                  ),
                ),
              ),
            ),
            const Divider(height: 1),
            Expanded(child: _buildToolbar(context)),
          ],
        ),
      ),
    );
  }

  Widget _buildToolbar(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 音名
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (var step = 0; step < 7; step++)
                ChoiceChip(
                  label: Text(_solfegeNames[step]),
                  selected: _pendingStep == step,
                  onSelected: (_) => _onPitchTap(step),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_downward),
                tooltip: 'オクターブを下げる',
                onPressed: () => _shiftOctave(-1),
              ),
              Text('オクターブ $_pendingOctave（$_pendingOctave=ト音記号の真ん中のド付近）'),
              IconButton(
                icon: const Icon(Icons.arrow_upward),
                tooltip: 'オクターブを上げる',
                onPressed: () => _shiftOctave(1),
              ),
              const SizedBox(width: 12),
              ChoiceChip(
                label: const Text('♭'),
                selected: _pendingAlter == -1,
                onSelected: (_) => _setAlter(_pendingAlter == -1 ? 0 : -1),
              ),
              const SizedBox(width: 4),
              ChoiceChip(
                label: const Text('♮'),
                selected: _pendingAlter == 0,
                onSelected: (_) => _setAlter(0),
              ),
              const SizedBox(width: 4),
              ChoiceChip(
                label: const Text('♯'),
                selected: _pendingAlter == 1,
                onSelected: (_) => _setAlter(_pendingAlter == 1 ? 0 : 1),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            alignment: WrapAlignment.center,
            children: [
              for (final base in NoteDurationBase.values)
                ChoiceChip(
                  label: Text(base.label),
                  selected: _pendingBase == base,
                  onSelected: (_) => _onDurationTap(base),
                ),
              ChoiceChip(
                label: Text('付点${_pendingDots > 0 ? '($_pendingDots)' : ''}'),
                selected: _pendingDots > 0,
                onSelected: (_) => _toggleDots(),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            alignment: WrapAlignment.center,
            children: [
              FilledButton.icon(
                onPressed: () => _addNote(rest: false),
                icon: const Icon(Icons.add),
                label: const Text('音符を追加'),
              ),
              OutlinedButton.icon(
                onPressed: () => _addNote(rest: true),
                icon: const Icon(Icons.pause),
                label: const Text('休符を追加'),
              ),
              OutlinedButton.icon(
                onPressed: _selected == null ? null : _deleteSelected,
                icon: const Icon(Icons.delete_outline),
                label: const Text('削除'),
              ),
              OutlinedButton.icon(
                onPressed: _selectedNote == null || _selectedNote!.isRest
                    ? null
                    : _toggleTie,
                icon: const Icon(Icons.link),
                label: Text(
                  (_selectedNote?.tiedToNext ?? false) ? 'タイを外す' : 'タイでつなぐ',
                ),
              ),
              OutlinedButton.icon(
                onPressed: () => _updatePart((p) => p.withMeasureAdded()),
                icon: const Icon(Icons.playlist_add),
                label: const Text('小節を追加'),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            '五線をタップすると、その音符を選んで編集できます。'
            '選んでいないときは、最後の小節に音符が追加されます。',
            style: Theme.of(context).textTheme.bodySmall,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
