/// ストップウォッチ機能
library;

import 'dart:async';

import 'package:material_ui/material_ui.dart';

class StopwatchTab extends StatefulWidget {
  const StopwatchTab({super.key});

  @override
  State<StopwatchTab> createState() => _StopwatchTabState();
}

class _StopwatchTabState extends State<StopwatchTab> {
  final _sw = Stopwatch();
  Timer? _ticker;
  final List<Duration> _laps = [];

  void _startPause() {
    setState(() {
      if (_sw.isRunning) {
        _sw.stop();
        _ticker?.cancel();
      } else {
        _sw.start();
        _ticker = Timer.periodic(const Duration(milliseconds: 33), (_) {
          if (mounted) setState(() {});
        });
      }
    });
  }

  void _lap() {
    if (!_sw.isRunning) return;
    setState(() => _laps.insert(0, _sw.elapsed));
  }

  void _reset() {
    setState(() {
      _sw.stop();
      _sw.reset();
      _ticker?.cancel();
      _laps.clear();
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  String _fmt(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    final cs = (d.inMilliseconds.remainder(1000) ~/ 10).toString().padLeft(2, '0');
    return '$m:$s.$cs';
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const SizedBox(height: 24),
        Text(_fmt(_sw.elapsed), style: Theme.of(context).textTheme.displayLarge),
        const SizedBox(height: 24),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            OutlinedButton(
              onPressed: _sw.elapsed == Duration.zero && !_sw.isRunning ? null : _reset,
              child: const Text('リセット'),
            ),
            const SizedBox(width: 16),
            FilledButton(
              onPressed: _startPause,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
                child: Text(_sw.isRunning ? '一時停止' : '開始'),
              ),
            ),
            const SizedBox(width: 16),
            OutlinedButton(
              onPressed: _sw.isRunning ? _lap : null,
              child: const Text('ラップ'),
            ),
          ],
        ),
        const Divider(height: 32),
        Expanded(
          child: _laps.isEmpty
              ? const Center(child: Text('ラップを記録すると、ここに表示されます'))
              : ListView.builder(
                  itemCount: _laps.length,
                  itemBuilder: (context, i) => ListTile(
                    dense: true,
                    leading: Text('${_laps.length - i}'),
                    title: Text(_fmt(_laps[i])),
                    trailing: i + 1 < _laps.length
                        ? Text('+${_fmt(_laps[i] - _laps[i + 1])}')
                        : null,
                  ),
                ),
        ),
      ],
    );
  }
}
