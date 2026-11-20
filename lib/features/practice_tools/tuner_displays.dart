/// チューナーの表示モード（Needle / Bar / Strobe）
///
/// 内部の検出精度と、表示の解像度は別物。Strobeの「縞の細かさ」は見た目の
/// 解像度であって、それだけ検出が正確というわけではないことに注意。
library;

import 'package:flutter/scheduler.dart';
import 'package:material_ui/material_ui.dart';

/// ずれ（セント）の大きさに応じた色（緑＝合っている、オレンジ＝ややズレ、赤＝大きくズレ）
///
/// [preciseCents] 以内なら緑、10セント以内ならオレンジ、それ以上は赤。
/// チューナー画面・解析画面で同じ配色にするための共通関数。
Color centsAccuracyColor(double cents, {int preciseCents = 3}) {
  final a = cents.abs();
  if (a <= preciseCents) return const Color(0xFF2E7D32);
  if (a <= 10) return const Color(0xFFEF6C00);
  return const Color(0xFFC62828);
}

enum TunerDisplayMode { needle, bar, strobe }

extension TunerDisplayModeX on TunerDisplayMode {
  String get label => switch (this) {
    TunerDisplayMode.needle => 'Needle',
    TunerDisplayMode.bar => 'Bar',
    TunerDisplayMode.strobe => 'Strobe',
  };
}

/// Strobeの縞の細かさ（表示解像度。内部の検出精度とは別）
enum StrobeResolution {
  coarse(5, '粗め（5¢刻み）'),
  medium(1, '標準（1¢刻み）'),
  fine(0.5, '細かい（0.5¢刻み）'),
  veryFine(0.1, '最細（0.1¢刻み）');

  const StrobeResolution(this.centsPerStripe, this.label);
  final double centsPerStripe;
  final String label;
}

/// ピッチのズレ量（cents）に応じて実際に動くStrobe表示
///
/// 縞は、ずれがゼロなら止まって見え、高ければ右へ、低ければ左へ、
/// ずれが大きいほど速く流れる（実物のストロボチューナーと同じ考え方）。
class StrobeMeter extends StatefulWidget {
  const StrobeMeter({
    super.key,
    required this.cents,
    required this.resolution,
    required this.color,
  });

  final double cents;
  final StrobeResolution resolution;
  final Color color;

  @override
  State<StrobeMeter> createState() => _StrobeMeterState();
}

class _StrobeMeterState extends State<StrobeMeter>
    with SingleTickerProviderStateMixin {
  late final Ticker _ticker;
  double _phase = 0;
  Duration _last = Duration.zero;

  @override
  void initState() {
    super.initState();
    _ticker = createTicker(_onTick)..start();
  }

  void _onTick(Duration elapsed) {
    final dt = (elapsed - _last).inMicroseconds / 1e6;
    _last = elapsed;
    // ずれ1セントあたり、1秒間に何ストライプぶん動かすか（見た目の速さの目安）
    const pixelsPerCentPerSecond = 0.06;
    setState(() {
      _phase += widget.cents * pixelsPerCentPerSecond * dt;
    });
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: SizedBox(
        height: 64,
        child: CustomPaint(
          painter: _StrobePainter(
            phase: _phase,
            stripeWidth: 10 / widget.resolution.centsPerStripe.clamp(0.1, 5) * 2,
            color: widget.color,
            background: cs.surfaceContainerHighest,
          ),
          child: const SizedBox.expand(),
        ),
      ),
    );
  }
}

class _StrobePainter extends CustomPainter {
  _StrobePainter({
    required this.phase,
    required this.stripeWidth,
    required this.color,
    required this.background,
  });

  final double phase;
  final double stripeWidth;
  final Color color;
  final Color background;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = background);
    final paint = Paint()..color = color;
    final w = stripeWidth.clamp(4.0, 40.0).toDouble();
    var x = -(phase % (w * 2));
    if (x > 0) x -= w * 2;
    while (x < size.width) {
      canvas.drawRect(Rect.fromLTWH(x, 0, w, size.height), paint);
      x += w * 2;
    }
  }

  @override
  bool shouldRepaint(covariant _StrobePainter oldDelegate) =>
      oldDelegate.phase != phase || oldDelegate.color != color;
}

/// Bar表示（従来の横バー。0の位置から左右に伸びる）
class TunerBarMeter extends StatelessWidget {
  const TunerBarMeter({super.key, required this.cents, required this.color});
  final double cents;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final t = (cents.clamp(-50, 50) + 50) / 100;
    return SizedBox(
      height: 40,
      child: LayoutBuilder(
        builder: (context, box) => Stack(
          children: [
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  color: cs.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
            for (final mark in [-50, -25, 0, 25, 50])
              Positioned(
                left: ((mark + 50) / 100) * box.maxWidth - 0.5,
                top: mark == 0 ? 0 : 8,
                bottom: mark == 0 ? 0 : 8,
                child: Container(
                  width: mark == 0 ? 2 : 1,
                  color: mark == 0 ? cs.onSurface : cs.outlineVariant,
                ),
              ),
            Positioned(
              left: (t * box.maxWidth - 5).clamp(0, box.maxWidth - 10).toDouble(),
              top: 4,
              bottom: 4,
              child: Container(
                width: 10,
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(5),
                  boxShadow: [BoxShadow(color: color.withValues(alpha: 0.5), blurRadius: 6)],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Needle表示（針が中心から左右に振れる、アナログ式のイメージ）
class TunerNeedleMeter extends StatelessWidget {
  const TunerNeedleMeter({super.key, required this.cents, required this.color});
  final double cents;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final angle = (cents.clamp(-50, 50) / 50) * 0.6; // ラジアン。最大約34度
    return SizedBox(
      height: 100,
      child: CustomPaint(
        painter: _NeedlePainter(angle: angle, color: color, baseColor: cs.outlineVariant),
      ),
    );
  }
}

class _NeedlePainter extends CustomPainter {
  _NeedlePainter({required this.angle, required this.color, required this.baseColor});
  final double angle;
  final Color color;
  final Color baseColor;

  @override
  void paint(Canvas canvas, Size size) {
    final pivot = Offset(size.width / 2, size.height);
    final len = size.height - 12;
    final arcPaint = Paint()
      ..color = baseColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    canvas.drawArc(
      Rect.fromCircle(center: pivot, radius: len),
      -3.14159 * 0.5 - 0.6,
      1.2,
      false,
      arcPaint,
    );
    canvas.save();
    canvas.translate(pivot.dx, pivot.dy);
    canvas.rotate(angle);
    canvas.drawLine(
      Offset.zero,
      Offset(0, -len),
      Paint()
        ..color = color
        ..strokeWidth = 4
        ..strokeCap = StrokeCap.round,
    );
    canvas.restore();
    canvas.drawCircle(pivot, 5, Paint()..color = color);
  }

  @override
  bool shouldRepaint(covariant _NeedlePainter oldDelegate) => oldDelegate.angle != angle;
}
