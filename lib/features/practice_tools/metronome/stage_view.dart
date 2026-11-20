/// メトロノームの「ステージ表示」：譜面台に置いても少し離れて読める、
/// 大きくシンプルな表示（横向き・高コントラスト）
library;

import 'package:material_ui/material_ui.dart';

import 'metronome_engine.dart';
import 'time_signature.dart';

class MetronomeStageView extends StatelessWidget {
  const MetronomeStageView({
    super.key,
    required this.bpm,
    required this.timeSignature,
    required this.currentBeat,
    required this.running,
    required this.swing,
    required this.onExit,
    required this.onToggle,
  });

  final int bpm;
  final TimeSignature timeSignature;
  final BeatEvent? currentBeat;
  final bool running;
  final Animation<double> swing;
  final VoidCallback onExit;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final e = currentBeat;
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: GestureDetector(
          onTap: onToggle,
          child: Stack(
            children: [
              Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '$bpm',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 96,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const Text('BPM', style: TextStyle(color: Colors.white54, fontSize: 20)),
                    const SizedBox(height: 16),
                    if (e != null)
                      Text(
                        e.isCountIn
                            ? 'カウントイン'
                            : '小節 ${e.barIndex + 1}　拍 ${e.beatIndex + 1}/${timeSignature.beats}',
                        style: const TextStyle(color: Colors.white70, fontSize: 28),
                      ),
                    const SizedBox(height: 20),
                    Wrap(
                      alignment: WrapAlignment.center,
                      spacing: 10,
                      children: [
                        for (var i = 0; i < timeSignature.beats; i++)
                          Container(
                            width: 26,
                            height: 26,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: (e != null && !e.isCountIn && i == e.beatIndex && e.slotIndex == 0)
                                  ? (i == 0
                                        ? Colors.redAccent
                                        : (timeSignature.isGroupStart(i)
                                              ? Colors.amberAccent
                                              : Colors.lightBlueAccent))
                                  : Colors.white24,
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 28),
                    SizedBox(
                      height: 140,
                      width: 200,
                      child: AnimatedBuilder(
                        animation: swing,
                        builder: (context, _) => CustomPaint(
                          painter: _StagePendulumPainter(angle: swing.value),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Positioned(
                top: 8,
                right: 8,
                child: IconButton(
                  icon: const Icon(Icons.close, color: Colors.white70),
                  onPressed: onExit,
                ),
              ),
              Positioned(
                bottom: 24,
                left: 0,
                right: 0,
                child: Center(
                  child: Text(
                    running ? 'タップで停止' : 'タップで開始',
                    style: const TextStyle(color: Colors.white38, fontSize: 16),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StagePendulumPainter extends CustomPainter {
  _StagePendulumPainter({required this.angle});
  final double angle;
  static const _maxAngle = 0.55;

  @override
  void paint(Canvas canvas, Size size) {
    final pivot = Offset(size.width / 2, size.height - 8);
    final needleLength = size.height - 20;
    canvas.save();
    canvas.translate(pivot.dx, pivot.dy);
    canvas.rotate(angle * _maxAngle);
    canvas.drawLine(
      Offset.zero,
      Offset(0, -needleLength),
      Paint()
        ..color = Colors.white
        ..strokeWidth = 5
        ..strokeCap = StrokeCap.round,
    );
    canvas.restore();
    canvas.drawCircle(pivot, 6, Paint()..color = Colors.white);
  }

  @override
  bool shouldRepaint(covariant _StagePendulumPainter oldDelegate) =>
      oldDelegate.angle != angle;
}
