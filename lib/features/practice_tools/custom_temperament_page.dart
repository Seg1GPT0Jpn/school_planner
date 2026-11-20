/// カスタム音律エディタ：12半音それぞれの「平均律からのズレ（セント）」を編集する
library;

import 'package:material_ui/material_ui.dart';

import 'music_theory.dart';

Future<CustomTemperament?> openCustomTemperamentEditor(
  BuildContext context,
  CustomTemperament initial,
) {
  return Navigator.of(context).push<CustomTemperament>(
    MaterialPageRoute(builder: (_) => _CustomTemperamentPage(initial: initial)),
  );
}

class _CustomTemperamentPage extends StatefulWidget {
  const _CustomTemperamentPage({required this.initial});
  final CustomTemperament initial;

  @override
  State<_CustomTemperamentPage> createState() => _CustomTemperamentPageState();
}

class _CustomTemperamentPageState extends State<_CustomTemperamentPage> {
  late CustomTemperament _t = widget.initial;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('カスタム音律'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(_t),
            child: const Text('決定'),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text('各音を、平均律から何セントずらすかを決められます（0で平均律と同じ）。'),
          const SizedBox(height: 16),
          for (var pc = 0; pc < 12; pc++) _row(pc),
        ],
      ),
    );
  }

  Widget _row(int pc) {
    final v = _t.offsetFor(pc);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(width: 36, child: Text(noteNameFor(pc, NotationSystem.english))),
          Expanded(
            child: Slider(
              value: v.clamp(-50, 50).toDouble(),
              min: -50,
              max: 50,
              divisions: 100,
              label: v.toStringAsFixed(0),
              onChanged: (nv) => setState(() => _t = _t.withOffset(pc, nv)),
            ),
          ),
          SizedBox(
            width: 56,
            child: Text(
              '${v >= 0 ? '+' : ''}${v.toStringAsFixed(0)}¢',
              textAlign: TextAlign.end,
            ),
          ),
        ],
      ),
    );
  }
}
