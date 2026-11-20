/// 雨雲レーダー（Google マップの上に、気象庁の高解像度降水ナウキャストを重ねて表示）
///
/// 地図の土台：Google マップ
/// 降水オーバーレイ：気象庁（ドキュメントの無い、気象庁サイト自身が使っているタイル配信を
/// そのまま利用しているので、気象庁側の都合で予告なく使えなくなる可能性がある）
library;

import 'dart:async';

import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:material_ui/material_ui.dart';

import 'jma_radar_times.dart';
import 'jma_radar_tile_provider.dart';
import 'weather_models.dart';

void openRainRadar(
  BuildContext context, {
  double? latitude,
  double? longitude,
  String? placeName,
}) {
  Navigator.of(context, rootNavigator: true).push(
    MaterialPageRoute<void>(
      builder: (_) => RainRadarPage(
        latitude: latitude,
        longitude: longitude,
        placeName: placeName,
      ),
    ),
  );
}

class RainRadarPage extends StatefulWidget {
  const RainRadarPage({super.key, this.latitude, this.longitude, this.placeName});

  final double? latitude;
  final double? longitude;
  final String? placeName;

  @override
  State<RainRadarPage> createState() => _RainRadarPageState();
}

class _RainRadarPageState extends State<RainRadarPage> {
  static const _overlayId = TileOverlayId('jma_hrpns');

  GoogleMapController? _controller;
  final _provider = JmaRadarTileProvider();

  List<RadarFrame> _frames = const [];
  int _index = 0;
  bool _loading = true;
  String? _error;
  Timer? _playTimer;
  bool _playing = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final frames = await fetchRadarFrames();
      if (!mounted) return;
      if (frames.isEmpty) {
        setState(() {
          _loading = false;
          _error = '気象庁からレーダーの時刻を取得できませんでした';
        });
        return;
      }
      // 「実況」の一番新しいもの（＝いま）を初期選択にする
      var nowIndex = frames.lastIndexWhere((f) => !f.isForecast);
      if (nowIndex < 0) nowIndex = 0;
      setState(() {
        _frames = frames;
        _index = nowIndex;
        _loading = false;
      });
      _provider.frame = frames[nowIndex];
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = '読み込めませんでした（$e）';
      });
    }
  }

  void _select(int i) {
    if (i < 0 || i >= _frames.length || i == _index) return;
    setState(() => _index = i);
    _provider.frame = _frames[i];
    unawaited(_controller?.clearTileCache(_overlayId));
  }

  void _togglePlay() {
    setState(() => _playing = !_playing);
    _playTimer?.cancel();
    if (_playing) {
      _playTimer = Timer.periodic(const Duration(milliseconds: 700), (_) {
        final next = _index + 1 >= _frames.length ? 0 : _index + 1;
        _select(next);
      });
    }
  }

  @override
  void dispose() {
    _playTimer?.cancel();
    super.dispose();
  }

  String _timeLabel(RadarFrame f) =>
      '${f.time.hour.toString().padLeft(2, '0')}:'
      '${f.time.minute.toString().padLeft(2, '0')}'
      '${f.isForecast ? '（予報）' : ''}';

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final lat = widget.latitude ?? schoolLatitude;
    final lng = widget.longitude ?? schoolLongitude;
    final frame = _frames.isEmpty ? null : _frames[_index];

    return Scaffold(
      appBar: AppBar(
        title: Text('雨雲レーダー${widget.placeName != null ? '（${widget.placeName}）' : ''}'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: '取り直す',
            onPressed: _load,
          ),
        ],
      ),
      body: _error != null
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(_error!, textAlign: TextAlign.center),
              ),
            )
          : Stack(
              children: [
                GoogleMap(
                  initialCameraPosition: CameraPosition(
                    target: LatLng(lat, lng),
                    zoom: widget.latitude != null ? 9.5 : 7.2,
                  ),
                  onMapCreated: (c) {
                    _controller = c;
                    if (frame != null) {
                      unawaited(c.clearTileCache(_overlayId));
                    }
                  },
                  myLocationButtonEnabled: false,
                  tileOverlays: {
                    TileOverlay(
                      tileOverlayId: _overlayId,
                      tileProvider: _provider,
                      zIndex: 1,
                    ),
                  },
                ),
                if (_loading)
                  const Positioned.fill(
                    child: Center(child: CircularProgressIndicator()),
                  ),
                Positioned(
                  left: 8,
                  top: 8,
                  child: _Legend(cs: cs),
                ),
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: _Controls(
                    frames: _frames,
                    index: _index,
                    playing: _playing,
                    timeLabel: frame == null ? '' : _timeLabel(frame),
                    onSelect: _select,
                    onPlayToggle: _togglePlay,
                  ),
                ),
              ],
            ),
    );
  }
}

class _Legend extends StatelessWidget {
  const _Legend({required this.cs});
  final ColorScheme cs;

  static const _steps = [
    (label: '弱い', color: Color(0xFF00B7F0)),
    (label: '', color: Color(0xFF0041FF)),
    (label: '', color: Color(0xFFFAE800)),
    (label: '', color: Color(0xFFFF9900)),
    (label: '強い', color: Color(0xFFFF2800)),
  ];

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
    decoration: BoxDecoration(
      color: cs.surface.withValues(alpha: 0.92),
      borderRadius: BorderRadius.circular(10),
      border: Border.all(color: cs.outlineVariant),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text('雨', style: TextStyle(fontSize: 11, color: cs.outline)),
        const SizedBox(width: 6),
        for (final s in _steps)
          Container(
            width: 14,
            height: 14,
            margin: const EdgeInsets.symmetric(horizontal: 1),
            color: s.color,
          ),
        const SizedBox(width: 6),
        Text('強', style: TextStyle(fontSize: 11, color: cs.outline)),
      ],
    ),
  );
}

class _Controls extends StatelessWidget {
  const _Controls({
    required this.frames,
    required this.index,
    required this.playing,
    required this.timeLabel,
    required this.onSelect,
    required this.onPlayToggle,
  });

  final List<RadarFrame> frames;
  final int index;
  final bool playing;
  final String timeLabel;
  final ValueChanged<int> onSelect;
  final VoidCallback onPlayToggle;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 14),
      decoration: BoxDecoration(
        color: cs.surface.withValues(alpha: 0.96),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.08), blurRadius: 8),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              IconButton(
                icon: Icon(playing ? Icons.pause_circle : Icons.play_circle),
                iconSize: 32,
                color: cs.primary,
                onPressed: frames.isEmpty ? null : onPlayToggle,
              ),
              Expanded(
                child: Text(
                  timeLabel,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              const SizedBox(width: 44),
            ],
          ),
          if (frames.isNotEmpty)
            Slider(
              value: index.toDouble(),
              min: 0,
              max: (frames.length - 1).toDouble(),
              divisions: frames.length > 1 ? frames.length - 1 : null,
              onChanged: (v) => onSelect(v.round()),
            ),
          Text(
            '気象庁「高解像度降水ナウキャスト」を利用（気象庁の公開データ）。'
            'このアプリは気象庁の公式アプリ・サービスではありません。',
            style: TextStyle(fontSize: 10, color: cs.outline),
          ),
        ],
      ),
    );
  }
}
