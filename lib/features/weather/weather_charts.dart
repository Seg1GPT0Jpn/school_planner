/// 天気の画面のグラフ（降水量・24時間・日の出日の入り・10日間の気温の帯）
library;

import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';

import 'weather_models.dart';

String _hm(DateTime t) => '${t.hour}:${t.minute.toString().padLeft(2, '0')}';

// ───────────────────── 今後6時間の降水量 ─────────────────────

class PrecipitationChart extends StatelessWidget {
  const PrecipitationChart({super.key, required this.slots});

  /// 15分ごとの降水量
  final List<WeatherSlot> slots;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final values = [for (final s in slots) s.precipitation ?? 0];
    final top = math.max(1.0, values.fold<double>(0, math.max));
    return Column(
      children: [
        SizedBox(
          height: 90,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              for (var i = 0; i < slots.length; i++)
                Expanded(
                  child: Tooltip(
                    message:
                        '${_hm(slots[i].time)}　${values[i].toStringAsFixed(1)}mm',
                    child: Container(
                      margin: const EdgeInsets.symmetric(horizontal: 1),
                      height: values[i] <= 0
                          ? 2
                          : math.max(4, 90 * values[i] / top),
                      decoration: BoxDecoration(
                        color: values[i] <= 0
                            ? cs.outlineVariant
                            : Color.lerp(
                                const Color(0xFF64B5F6),
                                const Color(0xFF0D47A1),
                                (values[i] / 10).clamp(0, 1),
                              ),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 4),
        Row(
          children: [
            for (var i = 0; i < slots.length; i++)
              Expanded(
                child: Text(
                  slots[i].time.minute == 0 && i.isEven
                      ? '${slots[i].time.hour}時'
                      : '',
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.visible,
                  softWrap: false,
                  style: TextStyle(fontSize: 10, color: cs.outline),
                ),
              ),
          ],
        ),
      ],
    );
  }
}

// ───────────────────── 24時間の予報 ─────────────────────

class HourlyStrip extends StatelessWidget {
  const HourlyStrip({super.key, required this.slots, this.sunTimes = const []});

  final List<WeatherSlot> slots;

  /// 夜のマークにするための日の出・日の入り（その日ごと）
  final List<DailyWeather> sunTimes;

  static const double _w = 58;

  bool _night(DateTime t) {
    for (final d in sunTimes) {
      if (d.sunrise == null || d.sunset == null) continue;
      if (d.date.year == t.year &&
          d.date.month == t.month &&
          d.date.day == t.day) {
        return t.isBefore(d.sunrise!) || !t.isBefore(d.sunset!);
      }
    }
    return t.hour < 6 || t.hour >= 18;
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final temps = [for (final s in slots) s.temperature];
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: SizedBox(
        width: _w * slots.length,
        child: Column(
          children: [
            // 時刻・天気
            Row(
              children: [
                for (final s in slots)
                  SizedBox(
                    width: _w,
                    child: Column(
                      children: [
                        Text(
                          s.time.hour == 0
                              ? '${s.time.month}/${s.time.day}'
                              : '${s.time.hour}時',
                          style: tt.labelSmall?.copyWith(
                            color: s.time.hour == 0 ? cs.primary : cs.outline,
                            fontWeight: s.time.hour == 0
                                ? FontWeight.bold
                                : null,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          weatherOf(s.code, night: _night(s.time)).icon,
                          style: const TextStyle(fontSize: 22),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
            // 気温の線
            SizedBox(
              height: 70,
              child: CustomPaint(
                size: Size(_w * slots.length, 70),
                painter: _TempLinePainter(
                  temps: temps,
                  line: cs.error,
                  text: cs.onSurface,
                  step: _w,
                ),
              ),
            ),
            // 降水確率・雨量・風
            Row(
              children: [
                for (final s in slots)
                  SizedBox(
                    width: _w,
                    child: Column(
                      children: [
                        Text(
                          s.precipitationProbability == null
                              ? '—'
                              : '${s.precipitationProbability}%',
                          style: tt.labelSmall?.copyWith(
                            color: (s.precipitationProbability ?? 0) >= 50
                                ? const Color(0xFF1565C0)
                                : cs.outline,
                          ),
                        ),
                        Text(
                          (s.precipitation ?? 0) > 0
                              ? '${s.precipitation!.toStringAsFixed(1)}mm'
                              : '',
                          style: tt.labelSmall?.copyWith(
                            color: const Color(0xFF1565C0),
                            fontSize: 10,
                          ),
                        ),
                        Transform.rotate(
                          // 風が吹いていく向きに矢印を向ける
                          angle: ((s.windDirection ?? 0) + 180) * math.pi / 180,
                          child: Icon(Icons.north, size: 14, color: cs.outline),
                        ),
                        Text(
                          s.windSpeed == null ? '' : '${s.windSpeed!.round()}m',
                          style: tt.labelSmall?.copyWith(
                            fontSize: 10,
                            color: (s.windSpeed ?? 0) >= 10
                                ? cs.error
                                : cs.outline,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _TempLinePainter extends CustomPainter {
  _TempLinePainter({
    required this.temps,
    required this.line,
    required this.text,
    required this.step,
  });

  final List<double?> temps;
  final Color line;
  final Color text;
  final double step;

  @override
  void paint(Canvas canvas, Size size) {
    final known = temps.whereType<double>().toList();
    if (known.isEmpty) return;
    final lo = known.reduce(math.min), hi = known.reduce(math.max);
    final span = math.max(1.0, hi - lo);
    double y(double t) => 22 + (size.height - 30) * (1 - (t - lo) / span);

    final path = Path();
    var started = false;
    for (var i = 0; i < temps.length; i++) {
      final t = temps[i];
      if (t == null) continue;
      final p = Offset(step * i + step / 2, y(t));
      if (!started) {
        path.moveTo(p.dx, p.dy);
        started = true;
      } else {
        path.lineTo(p.dx, p.dy);
      }
    }
    canvas.drawPath(
      path,
      Paint()
        ..color = line
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );
    for (var i = 0; i < temps.length; i++) {
      final t = temps[i];
      if (t == null) continue;
      final p = Offset(step * i + step / 2, y(t));
      canvas.drawCircle(p, 3, Paint()..color = line);
      final tp = TextPainter(
        text: TextSpan(
          text: '${t.round()}°',
          style: TextStyle(fontSize: 11, color: text),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(p.dx - tp.width / 2, p.dy - 18));
    }
  }

  @override
  bool shouldRepaint(covariant _TempLinePainter old) => old.temps != temps;
}

// ───────────────────── 日の出・日の入り ─────────────────────

class SunArc extends StatelessWidget {
  const SunArc({
    super.key,
    required this.sunrise,
    required this.sunset,
    required this.now,
  });

  final DateTime sunrise;
  final DateTime sunset;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final length = sunset.difference(sunrise);
    return Column(
      children: [
        SizedBox(
          height: 110,
          width: double.infinity,
          child: CustomPaint(
            painter: _SunArcPainter(
              progress: now.isBefore(sunrise)
                  ? null
                  : now.isAfter(sunset)
                  ? null
                  : now.difference(sunrise).inMinutes / length.inMinutes,
              arc: cs.outlineVariant,
              done: const Color(0xFFFFB300),
              ground: cs.outline,
            ),
          ),
        ),
        Row(
          children: [
            Expanded(
              child: Column(
                children: [
                  Text(
                    '日の出',
                    style: tt.labelSmall?.copyWith(color: cs.outline),
                  ),
                  Text(_hm(sunrise), style: tt.titleMedium),
                ],
              ),
            ),
            Expanded(
              child: Column(
                children: [
                  Text(
                    '昼の長さ',
                    style: tt.labelSmall?.copyWith(color: cs.outline),
                  ),
                  Text(
                    '${length.inHours}時間${length.inMinutes % 60}分',
                    style: tt.titleMedium,
                  ),
                ],
              ),
            ),
            Expanded(
              child: Column(
                children: [
                  Text(
                    '日の入り',
                    style: tt.labelSmall?.copyWith(color: cs.outline),
                  ),
                  Text(_hm(sunset), style: tt.titleMedium),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _SunArcPainter extends CustomPainter {
  _SunArcPainter({
    required this.progress,
    required this.arc,
    required this.done,
    required this.ground,
  });

  /// 日の出から日の入りまでの進み具合（夜は null）
  final double? progress;
  final Color arc;
  final Color done;
  final Color ground;

  @override
  void paint(Canvas canvas, Size size) {
    final r = math.min(size.width * 0.4, size.height - 14);
    final c = Offset(size.width / 2, size.height - 6);
    final rect = Rect.fromCircle(center: c, radius: r);

    canvas.drawLine(
      Offset(c.dx - r - 16, c.dy),
      Offset(c.dx + r + 16, c.dy),
      Paint()
        ..color = ground
        ..strokeWidth = 1,
    );
    canvas.drawArc(
      rect,
      math.pi,
      math.pi,
      false,
      Paint()
        ..color = arc
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );
    final p = progress;
    if (p != null) {
      canvas.drawArc(
        rect,
        math.pi,
        math.pi * p,
        false,
        Paint()
          ..color = done
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3,
      );
      final a = math.pi + math.pi * p;
      final sun = Offset(c.dx + r * math.cos(a), c.dy + r * math.sin(a));
      canvas.drawCircle(sun, 9, Paint()..color = done);
    }
  }

  @override
  bool shouldRepaint(covariant _SunArcPainter old) => old.progress != progress;
}

// ───────────────────── 10日間の気温の帯 ─────────────────────

class TempRangeBar extends StatelessWidget {
  const TempRangeBar({
    super.key,
    required this.min,
    required this.max,
    required this.lo,
    required this.hi,
  });

  /// その日の最低・最高
  final double min;
  final double max;

  /// 10日間ぜんぶの最低・最高
  final double lo;
  final double hi;

  @override
  Widget build(BuildContext context) {
    final span = math.max(1.0, hi - lo);
    return LayoutBuilder(
      builder: (context, c) {
        final w = c.maxWidth;
        final left = w * (min - lo) / span;
        final width = math.max(6.0, w * (max - min) / span);
        return SizedBox(
          height: 8,
          child: Stack(
            children: [
              Container(
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              Positioned(
                left: left,
                width: width,
                top: 0,
                bottom: 0,
                child: Container(
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF42A5F5), Color(0xFFFFA726)],
                    ),
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
