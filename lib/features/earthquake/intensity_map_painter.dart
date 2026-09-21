/// 震度分布図（自前で描く。都道府県ごとの最大震度を、地図上の位置に丸で表示）
library;

import 'package:material_ui/material_ui.dart';

import 'pref_locations.dart';

/// 震度（10倍表記）の色（気象庁の色見本を参考にした目安）
Color scaleColor(int scale) => switch (scale) {
  >= 70 => const Color(0xFF4A0072), // 7
  >= 60 => const Color(0xFFB71C1C), // 6強
  >= 55 => const Color(0xFFD32F2F), // 6弱
  >= 50 => const Color(0xFFEF5350), // 5強
  >= 45 => const Color(0xFFFF7043), // 5弱
  >= 40 => const Color(0xFFFFA726), // 4
  >= 30 => const Color(0xFFFFCA28), // 3
  >= 20 => const Color(0xFF66BB6A), // 2
  >= 10 => const Color(0xFF64B5F6), // 1
  _ => const Color(0xFFBDBDBD),
};

/// 日本のおおよその範囲（緯度・経度）
const _latMin = 24.0, _latMax = 46.0;
const _lngMin = 122.0, _lngMax = 146.5;

class IntensityMap extends StatelessWidget {
  const IntensityMap({super.key, required this.maxScaleByPref, this.epicenter});

  /// 都道府県名 → 最大震度（10倍表記）
  final Map<String, int> maxScaleByPref;

  /// 震源の位置（表示できれば ×印を出す）
  final (double lat, double lng)? epicenter;

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 0.82,
      child: CustomPaint(
        painter: _IntensityMapPainter(
          maxScaleByPref: maxScaleByPref,
          epicenter: epicenter,
          background: Theme.of(context).colorScheme.surfaceContainerHighest,
          outline: Theme.of(context).colorScheme.outlineVariant,
        ),
      ),
    );
  }
}

class _IntensityMapPainter extends CustomPainter {
  _IntensityMapPainter({
    required this.maxScaleByPref,
    required this.epicenter,
    required this.background,
    required this.outline,
  });

  final Map<String, int> maxScaleByPref;
  final (double lat, double lng)? epicenter;
  final Color background;
  final Color outline;

  Offset _project(double lat, double lng, Size size) {
    final x = (lng - _lngMin) / (_lngMax - _lngMin) * size.width;
    // 緯度は上が北（大きいほど上）なので反転
    final y = (1 - (lat - _latMin) / (_latMax - _latMin)) * size.height;
    return Offset(x, y);
  }

  @override
  void paint(Canvas canvas, Size size) {
    final bgPaint = Paint()..color = background;
    final rect = RRect.fromRectAndRadius(
      Offset.zero & size,
      const Radius.circular(8),
    );
    canvas.drawRRect(rect, bgPaint);
    canvas.drawRRect(
      rect,
      Paint()
        ..color = outline
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1,
    );

    // 震源
    if (epicenter != null) {
      final (lat, lng) = epicenter!;
      if (lat >= _latMin &&
          lat <= _latMax &&
          lng >= _lngMin &&
          lng <= _lngMax) {
        final p = _project(lat, lng, size);
        final paint = Paint()
          ..color = Colors.black87
          ..strokeWidth = 2.5
          ..style = PaintingStyle.stroke;
        canvas.drawLine(
          p + const Offset(-6, -6),
          p + const Offset(6, 6),
          paint,
        );
        canvas.drawLine(
          p + const Offset(-6, 6),
          p + const Offset(6, -6),
          paint,
        );
      }
    }

    // 各都道府県の震度（震度が大きいものを後から描いて目立たせる）
    final entries = maxScaleByPref.entries.toList()
      ..sort((a, b) => a.value.compareTo(b.value));
    for (final e in entries) {
      final loc = prefLocations[e.key];
      if (loc == null) continue;
      final (lat, lng) = loc;
      final p = _project(lat, lng, size);
      final r = 7.0 + (e.value.clamp(10, 70) - 10) / 60 * 8;
      canvas.drawCircle(
        p,
        r,
        Paint()..color = scaleColor(e.value).withValues(alpha: 0.9),
      );
      canvas.drawCircle(
        p,
        r,
        Paint()
          ..color = Colors.black26
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _IntensityMapPainter oldDelegate) =>
      oldDelegate.maxScaleByPref != maxScaleByPref ||
      oldDelegate.epicenter != epicenter;
}
