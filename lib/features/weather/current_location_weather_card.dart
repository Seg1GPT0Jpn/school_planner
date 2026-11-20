/// 「現在地の天気」カード（天気画面の上部に出す）
///
/// ボタンを押したときだけ位置情報（GPS）を取りにいく。取った緯度経度は
/// このカードの中だけで使い、保存はしない。場所の名前は Nominatim の
/// reverse geocoding（住所逆引き）で調べる。
library;

import 'package:material_ui/material_ui.dart';

import '../location/current_location_service.dart';
import '../travel/geocoder.dart';
import 'weather_models.dart';
import 'weather_service.dart';

class CurrentLocationWeatherCard extends StatefulWidget {
  const CurrentLocationWeatherCard({super.key});

  @override
  State<CurrentLocationWeatherCard> createState() =>
      _CurrentLocationWeatherCardState();
}

class _CurrentLocationWeatherCardState
    extends State<CurrentLocationWeatherCard> {
  bool _loading = false;
  String? _error;
  String _placeName = '現在地';
  WeatherBundle? _bundle;

  Future<void> _fetch() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    final loc = await CurrentLocationService.getCurrent();
    if (!mounted) return;
    if (!loc.isOk) {
      setState(() {
        _loading = false;
        _error = CurrentLocationService.messageFor(loc.failure!);
      });
      return;
    }
    final (lat, lng) = loc.point!;

    final results = await Future.wait([
      WeatherService.instance.loadAt(latitude: lat, longitude: lng),
      Geocoder.reverse(lat, lng),
    ]);
    if (!mounted) return;
    setState(() {
      _loading = false;
      _bundle = results[0] as WeatherBundle;
      _placeName = (results[1] as String?) ?? '現在地';
    });
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final f = _bundle?.forecast;
    final cur = f?.current;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.my_location, size: 20, color: cs.primary),
                const SizedBox(width: 6),
                Expanded(
                  child: Text('現在地の天気', style: tt.titleMedium),
                ),
                if (_bundle != null && !_loading)
                  IconButton(
                    icon: const Icon(Icons.refresh, size: 20),
                    tooltip: '取り直す',
                    onPressed: _fetch,
                  ),
              ],
            ),
            const SizedBox(height: 8),
            if (_bundle == null && !_loading)
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '今いる場所のおおよその天気を見られます（位置情報の利用に同意が必要です）。',
                    style: TextStyle(color: cs.outline, fontSize: 13),
                  ),
                  const SizedBox(height: 10),
                  OutlinedButton.icon(
                    onPressed: _fetch,
                    icon: const Icon(Icons.my_location, size: 18),
                    label: const Text('現在地の天気を見る'),
                  ),
                ],
              )
            else if (_loading)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 8),
                child: Row(
                  children: [
                    SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                    SizedBox(width: 10),
                    Text('現在地を調べています…'),
                  ],
                ),
              )
            else if (cur != null) ...[
              Text(_placeName, style: TextStyle(color: cs.outline)),
              const SizedBox(height: 6),
              Row(
                children: [
                  Text(
                    weatherOf(cur.code, night: !cur.isDay).icon,
                    style: const TextStyle(fontSize: 32),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    '${cur.temperature?.round() ?? '—'}°',
                    style: tt.headlineSmall,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      weatherOf(cur.code, night: !cur.isDay).label,
                      style: TextStyle(color: cs.outline),
                    ),
                  ),
                ],
              ),
              if ((cur.precipitation ?? 0) > 0) ...[
                const SizedBox(height: 6),
                Text(
                  '今の降水量：${cur.precipitation!.toStringAsFixed(1)}mm/h',
                  style: TextStyle(color: cs.outline, fontSize: 13),
                ),
              ],
            ] else
              Text('取得できませんでした', style: TextStyle(color: cs.error)),
            if (_error != null) ...[
              const SizedBox(height: 8),
              Text(
                _error!,
                style: TextStyle(color: cs.error, fontSize: 12),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
