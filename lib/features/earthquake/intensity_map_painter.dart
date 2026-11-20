/// 震度分布図（Google マップの上に、都道府県ごとの最大震度を重ねて表示）
library;

import 'package:flutter/foundation.dart' show Factory;
import 'package:flutter/gestures.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
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

/// 震度（10倍表記）を「5弱」のような表示用文字列にする（地図のラベル用）
String _label(int scale) => switch (scale) {
  10 => '1',
  20 => '2',
  30 => '3',
  40 => '4',
  45 => '5弱',
  50 => '5強',
  55 => '6弱',
  60 => '6強',
  70 => '7',
  _ => '不明',
};

/// 日本全体が入るくらいのカメラ位置
const _japanCenter = LatLng(36.8, 138.2);

class IntensityMap extends StatefulWidget {
  const IntensityMap({super.key, required this.maxScaleByPref, this.epicenter});

  /// 都道府県名 → 最大震度（10倍表記）
  final Map<String, int> maxScaleByPref;

  /// 震源の位置（表示できれば印を出す）
  final (double lat, double lng)? epicenter;

  @override
  State<IntensityMap> createState() => _IntensityMapState();
}

class _IntensityMapState extends State<IntensityMap> {
  GoogleMapController? _controller;

  Set<Circle> get _circles => {
    for (final e in widget.maxScaleByPref.entries)
      if (prefLocations[e.key] case final loc?)
        Circle(
          circleId: CircleId('pref_${e.key}'),
          center: LatLng(loc.$1, loc.$2),
          radius: 18000 + (e.value.clamp(10, 70) - 10) / 60 * 42000,
          fillColor: scaleColor(e.value).withValues(alpha: 0.55),
          strokeColor: scaleColor(e.value),
          strokeWidth: 1,
        ),
  };

  Set<Marker> get _markers => {
    for (final e in widget.maxScaleByPref.entries)
      if (prefLocations[e.key] case final loc?)
        Marker(
          markerId: MarkerId('pref_marker_${e.key}'),
          position: LatLng(loc.$1, loc.$2),
          alpha: 0.01,
          icon: BitmapDescriptor.defaultMarkerWithHue(
            HSVColor.fromColor(scaleColor(e.value)).hue,
          ),
          infoWindow: InfoWindow(title: '${e.key}　震度${_label(e.value)}'),
        ),
    if (widget.epicenter case (final lat, final lng)?)
      Marker(
        markerId: const MarkerId('epicenter'),
        position: LatLng(lat, lng),
        icon: BitmapDescriptor.defaultMarkerWithHue(
          BitmapDescriptor.hueViolet,
        ),
        infoWindow: const InfoWindow(title: '震源'),
        zIndexInt: 2,
      ),
  };

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: AspectRatio(
        aspectRatio: 0.82,
        child: GoogleMap(
          initialCameraPosition: const CameraPosition(
            target: _japanCenter,
            zoom: 4.4,
          ),
          onMapCreated: (c) => _controller = c,
          circles: _circles,
          markers: _markers,
          myLocationButtonEnabled: false,
          zoomControlsEnabled: false,
          zoomGesturesEnabled: true,
          mapToolbarEnabled: false,
          liteModeEnabled: false,
          // この地図はスクロールできる一覧の中に埋め込まれているため、
          // 何もしないと指でのピンチ（ズーム）操作が親側のスクロールに
          // 取られてしまい、拡大できない。地図の上での操作を地図側に
          // 優先して渡すようにする。
          gestureRecognizers: {
            Factory<OneSequenceGestureRecognizer>(
              () => EagerGestureRecognizer(),
            ),
          },
        ),
      ),
    );
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }
}
