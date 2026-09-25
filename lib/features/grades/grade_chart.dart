/// 成績の折れ線グラフ（ライブラリを使わず自作）
library;

import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';

import 'grade.dart';

class GradeLineChart extends StatelessWidget {
  const GradeLineChart({
    super.key,
    required this.points,
    required this.metric,
    this.target,
  });

  final List<ChartPoint> points;
  final GradeMetric metric;

  /// 目標ライン
  final num? target;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return SizedBox(
      height: 230,
      width: double.infinity,
      child: CustomPaint(
        painter: _ChartPainter(
          points: points,
          metric: metric,
          target: target?.toDouble(),
          line: cs.primary,
          average: cs.outline,
          targetColor: cs.error,
          grid: cs.outlineVariant,
          text: cs.onSurfaceVariant,
        ),
      ),
    );
  }
}

/// 縦軸の範囲（テストしやすいよう外に出す）
({double lo, double hi}) chartRange(
  List<ChartPoint> points,
  GradeMetric metric,
  double? target,
) {
  final values = [
    for (final p in points) p.value,
    for (final p in points) ?p.average,
    ?target,
  ];
  switch (metric) {
    case GradeMetric.score:
      return (lo: 0, hi: 100);
    case GradeMetric.deviation:
      if (values.isEmpty) return (lo: 30, hi: 70);
      final lo = ((values.reduce(math.min) - 5) / 5).floor() * 5.0;
      final hi = ((values.reduce(math.max) + 5) / 5).ceil() * 5.0;
      return (lo: lo, hi: hi);
    case GradeMetric.rank:
      final worst = values.isEmpty ? 10.0 : values.reduce(math.max);
      final hi = math.max(5, (worst * 1.15).ceil()).toDouble();
      return (lo: 1, hi: hi);
  }
}

class _ChartPainter extends CustomPainter {
  _ChartPainter({
    required this.points,
    required this.metric,
    required this.target,
    required this.line,
    required this.average,
    required this.targetColor,
    required this.grid,
    required this.text,
  });

  final List<ChartPoint> points;
  final GradeMetric metric;
  final double? target;
  final Color line, average, targetColor, grid, text;

  static const _left = 34.0, _right = 12.0, _top = 18.0, _bottom = 30.0;

  void _label(
    Canvas c,
    String s,
    Offset at, {
    Color? color,
    double size = 10,
    bool center = true,
    bool bold = false,
  }) {
    final tp = TextPainter(
      text: TextSpan(
        text: s,
        style: TextStyle(
          color: color ?? text,
          fontSize: size,
          fontWeight: bold ? FontWeight.bold : null,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(
      c,
      Offset(
        center ? at.dx - tp.width / 2 : at.dx - tp.width,
        at.dy - tp.height / 2,
      ),
    );
  }

  void _dashed(Canvas c, Offset a, Offset b, Paint p) {
    const dash = 5.0, gap = 4.0;
    final len = (b - a).distance;
    if (len == 0) return;
    final dir = (b - a) / len;
    for (var d = 0.0; d < len; d += dash + gap) {
      c.drawLine(a + dir * d, a + dir * math.min(d + dash, len), p);
    }
  }

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width - _left - _right;
    final h = size.height - _top - _bottom;
    final r = chartRange(points, metric, target);
    final inverted = metric == GradeMetric.rank; // 順位は1位が上

    double y(double v) {
      final t = ((v - r.lo) / (r.hi - r.lo)).clamp(0.0, 1.0);
      return _top + (inverted ? t : 1 - t) * h;
    }

    double x(int i) => points.length == 1
        ? _left + w / 2
        : _left + w * i / (points.length - 1);

    // 目盛り（5本）
    final gridPaint = Paint()
      ..color = grid
      ..strokeWidth = 1;
    for (var k = 0; k <= 4; k++) {
      final v = r.lo + (r.hi - r.lo) * k / 4;
      final yy = y(v);
      canvas.drawLine(Offset(_left, yy), Offset(_left + w, yy), gridPaint);
      _label(
        canvas,
        numText(v.roundToDouble()),
        Offset(_left - 4, yy),
        center: false,
      );
    }

    // 目標ライン
    if (target != null) {
      final ty = y(target!);
      _dashed(
        canvas,
        Offset(_left, ty),
        Offset(_left + w, ty),
        Paint()
          ..color = targetColor
          ..strokeWidth = 1.5,
      );
      _label(
        canvas,
        '目標 ${numText(target!)}',
        Offset(_left + w, ty - 8),
        color: targetColor,
        center: false,
        bold: true,
      );
    }

    if (points.isEmpty) return;

    // 平均（点数のとき）
    final avgPaint = Paint()
      ..color = average
      ..strokeWidth = 1.5;
    for (var i = 0; i < points.length - 1; i++) {
      final a = points[i].average, b = points[i + 1].average;
      if (a != null && b != null) {
        _dashed(canvas, Offset(x(i), y(a)), Offset(x(i + 1), y(b)), avgPaint);
      }
    }
    for (var i = 0; i < points.length; i++) {
      final a = points[i].average;
      if (a != null) {
        canvas.drawCircle(Offset(x(i), y(a)), 2.5, Paint()..color = average);
      }
    }

    // 自分の線
    final path = Path();
    for (var i = 0; i < points.length; i++) {
      final o = Offset(x(i), y(points[i].value));
      i == 0 ? path.moveTo(o.dx, o.dy) : path.lineTo(o.dx, o.dy);
    }
    canvas.drawPath(
      path,
      Paint()
        ..color = line
        ..strokeWidth = 2.5
        ..style = PaintingStyle.stroke,
    );

    // 点・値・日付
    final step = math.max(1, (points.length / 6).ceil()); // 日付が重ならないように間引く
    for (var i = 0; i < points.length; i++) {
      final p = points[i];
      final o = Offset(x(i), y(p.value));
      canvas.drawCircle(o, 4, Paint()..color = line);
      _label(
        canvas,
        metric == GradeMetric.rank ? '${numText(p.value)}位' : numText(p.value),
        o.translate(0, -11),
        color: line,
        bold: true,
      );
      if (i % step == 0 || i == points.length - 1) {
        _label(
          canvas,
          '${p.date.month}/${p.date.day}',
          Offset(x(i), _top + h + 12),
        );
      }
    }
  }

  @override
  bool shouldRepaint(_ChartPainter old) =>
      old.points != points ||
      old.metric != metric ||
      old.target != target ||
      old.line != line;
}
