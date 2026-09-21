/// ホームに出す天気と、自宅待機の予測
library;

import 'package:material_ui/material_ui.dart';

import 'school_closure.dart';
import 'weather_models.dart';
import 'weather_page.dart';
import 'weather_service.dart';

class WeatherHomeCard extends StatefulWidget {
  const WeatherHomeCard({super.key, required this.isSchoolDay});

  final bool Function(DateTime day) isSchoolDay;

  @override
  State<WeatherHomeCard> createState() => _WeatherHomeCardState();
}

class _WeatherHomeCardState extends State<WeatherHomeCard> {
  late final Future<WeatherBundle> _future = WeatherService.instance.load();

  void _open() => openWeather(context, isSchoolDay: widget.isSchoolDay);

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    return FutureBuilder<WeatherBundle>(
      future: _future,
      builder: (context, snap) {
        final b = snap.data ?? WeatherService.instance.cached;
        if (b == null) {
          return Card(
            child: ListTile(
              leading: const Icon(Icons.cloud_outlined),
              title: const Text('天気を読み込んでいます…'),
              onTap: _open,
            ),
          );
        }
        final now = DateTime.now();
        final f = b.forecast;
        final c = f?.current;
        final today = f?.dayOf(now);
        final w = weatherOf(c?.code, night: !(c?.isDay ?? true));
        final prediction = b.warnings == null
            ? null
            : predictClosure(
                now: now,
                target: nextJudgeTime(now, widget.isSchoolDay),
                warnings: b.warnings!,
                forecast: f,
                typhoons: b.typhoons,
              );
        // 雨が近いか（今後2時間）
        final rainSoon = f == null
            ? 0.0
            : f
                  .precipitationNext(now, hours: 2)
                  .fold<double>(0, (s, x) => s + (x.precipitation ?? 0));
        final maxLevel = b.warnings?.maxLevel ?? 0;

        return Column(
          children: [
            Card(
              child: InkWell(
                onTap: _open,
                borderRadius: BorderRadius.circular(12),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Text(w.icon, style: const TextStyle(fontSize: 40)),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              c?.temperature == null
                                  ? '天気'
                                  : '${c!.temperature!.round()}°  ${w.label}',
                              style: tt.titleLarge,
                            ),
                            Text(
                              [
                                if (today?.max != null)
                                  '最高${today!.max!.round()}°',
                                if (today?.min != null)
                                  '最低${today!.min!.round()}°',
                                if (today?.precipitationProbability != null)
                                  '☔${today!.precipitationProbability}%',
                                if (c?.apparent != null)
                                  '体感${c!.apparent!.round()}°',
                              ].join('・'),
                              style: tt.bodySmall?.copyWith(color: cs.outline),
                            ),
                            if (rainSoon > 0)
                              Text(
                                '2時間以内に雨（${rainSoon.toStringAsFixed(1)}mm）',
                                style: tt.bodySmall?.copyWith(
                                  color: const Color(0xFF1565C0),
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            if (maxLevel >= 2)
                              Text(
                                '警報・注意報：${b.warnings!.sorted.take(3).map((x) => x.name).join('・')}',
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: tt.bodySmall?.copyWith(
                                  color: levelColor(maxLevel),
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                          ],
                        ),
                      ),
                      const Icon(Icons.chevron_right),
                    ],
                  ),
                ),
              ),
            ),
            // 自宅待機がありうるときだけ、大きく出す
            if (prediction != null &&
                prediction.risk.index >= ClosureRisk.low.index) ...[
              const SizedBox(height: 12),
              ClosureCard(prediction: prediction, onTap: _open),
            ],
          ],
        );
      },
    );
  }
}
