/// 天気予報の画面（藤沢市）と、荒天のときの自宅待機の予測
library;

import 'package:material_ui/material_ui.dart';
import 'package:url_launcher/url_launcher.dart';

import 'jma_warnings.dart';
import 'school_closure.dart';
import 'weather_charts.dart';
import 'weather_models.dart';
import 'weather_service.dart';

const _wd = ['月', '火', '水', '木', '金', '土', '日'];

String _hm(DateTime t) => '${t.hour}:${t.minute.toString().padLeft(2, '0')}';
String _t(double? v) => v == null ? '—' : '${v.round()}°';

/// 警戒レベルの色（気象庁の色に合わせる）
Color levelColor(int level) => switch (level) {
  >= 5 => const Color(0xFF0C000C),
  4 => const Color(0xFFAA00AA),
  3 => const Color(0xFFFF2800),
  _ => const Color(0xFFD4B800),
};

Color riskColor(ClosureRisk r, ColorScheme cs) => switch (r) {
  ClosureRisk.now => const Color(0xFFAA00AA),
  ClosureRisk.high => const Color(0xFFFF2800),
  ClosureRisk.medium => const Color(0xFFEF6C00),
  ClosureRisk.low => const Color(0xFFD4B800),
  ClosureRisk.none => cs.outline,
};

/// 天気の画面を開く
void openWeather(
  BuildContext context, {
  required bool Function(DateTime day) isSchoolDay,
}) {
  Navigator.of(context, rootNavigator: true).push(
    MaterialPageRoute<void>(
      builder: (_) => WeatherPage(isSchoolDay: isSchoolDay),
    ),
  );
}

class WeatherPage extends StatefulWidget {
  const WeatherPage({super.key, required this.isSchoolDay});

  /// その日が登校日か（自宅待機の予測に使う）
  final bool Function(DateTime day) isSchoolDay;

  @override
  State<WeatherPage> createState() => _WeatherPageState();
}

class _WeatherPageState extends State<WeatherPage> {
  late Future<WeatherBundle> _future = WeatherService.instance.load();

  Future<void> _refresh() async {
    final f = WeatherService.instance.load(force: true);
    setState(() => _future = f);
    await f;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('天気（$schoolPlaceName）'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: '取り直す',
            onPressed: _refresh,
          ),
        ],
      ),
      body: FutureBuilder<WeatherBundle>(
        future: _future,
        builder: (context, snap) {
          final b = snap.data ?? WeatherService.instance.cached;
          if (b == null) {
            return snap.hasError
                ? Center(child: Text('読み込めませんでした\n${snap.error}'))
                : const Center(child: CircularProgressIndicator());
          }
          return RefreshIndicator(
            onRefresh: _refresh,
            child: _WeatherBody(bundle: b, isSchoolDay: widget.isSchoolDay),
          );
        },
      ),
    );
  }
}

class _WeatherBody extends StatelessWidget {
  const _WeatherBody({required this.bundle, required this.isSchoolDay});

  final WeatherBundle bundle;
  final bool Function(DateTime day) isSchoolDay;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final f = bundle.forecast;
    final w = bundle.warnings;
    final prediction = w == null
        ? null
        : predictClosure(
            now: now,
            target: nextJudgeTime(now, isSchoolDay),
            warnings: w,
            forecast: f,
            typhoons: bundle.typhoons,
          );
    const gap = SizedBox(height: 12);

    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 720),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
          children: [
            for (final e in bundle.errors)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(
                  '⚠ $e',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.error,
                    fontSize: 12,
                  ),
                ),
              ),
            if (prediction != null) ...[
              ClosureCard(prediction: prediction, detailed: true),
              gap,
            ],
            if (w != null &&
                (w.warnings.isNotEmpty || bundle.typhoons.isNotEmpty)) ...[
              _WarningsCard(warnings: w, typhoons: bundle.typhoons),
              gap,
            ],
            if (f != null) ...[
              _NowCard(forecast: f, now: now),
              gap,
              _Section(
                title: '今後6時間の降水量',
                icon: Icons.umbrella_outlined,
                child: () {
                  final slots = f.precipitationNext(now);
                  if (slots.isEmpty) return const Text('データがありません');
                  final total = slots.fold<double>(
                    0,
                    (s, x) => s + (x.precipitation ?? 0),
                  );
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        total <= 0
                            ? 'この6時間は雨の心配はなさそうです'
                            : '6時間で合計 ${total.toStringAsFixed(1)}mm（15分ごと）',
                      ),
                      const SizedBox(height: 8),
                      PrecipitationChart(slots: slots),
                    ],
                  );
                }(),
              ),
              gap,
              _Section(
                title: '24時間の予報',
                icon: Icons.schedule,
                child: HourlyStrip(slots: f.hourlyNext(now), sunTimes: f.daily),
              ),
              gap,
              if (f.dayOf(now) case final today?
                  when today.sunrise != null && today.sunset != null) ...[
                _Section(
                  title: '日の出・日の入り',
                  icon: Icons.wb_twilight,
                  child: SunArc(
                    sunrise: today.sunrise!,
                    sunset: today.sunset!,
                    now: now,
                  ),
                ),
                gap,
              ],
              _Section(
                title: '10日間の予報',
                icon: Icons.calendar_view_week,
                child: _TenDays(days: f.daily),
              ),
              gap,
            ],
            _Section(
              title: '地図・くわしい情報（気象庁）',
              icon: Icons.map_outlined,
              child: Column(
                children: [
                  for (final p in jmaPages)
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      dense: true,
                      leading: const Icon(Icons.open_in_new, size: 18),
                      title: Text(p.label),
                      subtitle: Text(p.description),
                      onTap: () => launchUrl(
                        p.uri,
                        mode: LaunchMode.externalApplication,
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Text(
              '天気予報：Open-Meteo（open-meteo.com・CC BY 4.0。日本の予報には気象庁のモデルを使用）\n'
              '警報・台風：気象庁\n'
              '取得：${_hm(bundle.fetchedAt)}（10分ごとに取り直せます）',
              style: TextStyle(
                fontSize: 11,
                color: Theme.of(context).colorScheme.outline,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({
    required this.title,
    required this.icon,
    required this.child,
  });

  final String title;
  final IconData icon;
  final Widget child;

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                icon,
                size: 20,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(width: 6),
              Text(title, style: Theme.of(context).textTheme.titleMedium),
            ],
          ),
          const SizedBox(height: 10),
          child,
        ],
      ),
    ),
  );
}

// ───────────────────── 自宅待機の予測 ─────────────────────

/// 自宅待機（休校）の予測。ホームでも使う
class ClosureCard extends StatelessWidget {
  const ClosureCard({
    super.key,
    required this.prediction,
    this.detailed = false,
    this.onTap,
  });

  final ClosurePrediction prediction;

  /// 学校のきまりの全文も出す
  final bool detailed;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final p = prediction;
    final color = riskColor(p.risk, cs);
    final d = p.target;
    final when = p.isToday
        ? '今日（${d.month}/${d.day}）朝6時'
        : '${d.month}/${d.day}(${_wd[d.weekday - 1]}) 朝6時';

    return Card(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: p.risk == ClosureRisk.none ? cs.outlineVariant : color,
          width: p.risk.index >= ClosureRisk.medium.index ? 2 : 1,
        ),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    p.risk.index >= ClosureRisk.medium.index
                        ? Icons.house_outlined
                        : Icons.school_outlined,
                    color: color,
                  ),
                  const SizedBox(width: 8),
                  Expanded(child: Text('$when の自宅待機', style: tt.titleMedium)),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.12),
                      border: Border.all(color: color),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      p.risk == ClosureRisk.now ? 'あてはまる' : p.risk.label,
                      style: tt.labelLarge?.copyWith(
                        color: color,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              if (p.risk == ClosureRisk.now)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    '学校のきまりでは自宅で待機です。「すぐーる」「クラスルーム」の連絡を確かめてください。',
                    style: TextStyle(color: color, fontWeight: FontWeight.bold),
                  ),
                ),
              for (final r in p.reasons)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text('・$r'),
                ),
              for (final n in p.notes)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    '・$n',
                    style: tt.bodySmall?.copyWith(color: cs.outline),
                  ),
                ),
              if (p.risk == ClosureRisk.none &&
                  p.reasons.isEmpty &&
                  p.notes.isEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(
                    '自宅待機になるような警報は出ていません',
                    style: tt.bodySmall?.copyWith(color: cs.outline),
                  ),
                ),
              if (detailed) ...[
                const Divider(height: 24),
                Text('学校のきまり（荒天時）', style: tt.labelLarge),
                const SizedBox(height: 4),
                Text(
                  '午前6時の時点で藤沢市に次のどれかが出ていたら、自宅で待機。\n'
                  '① レベル4以上の警報\n'
                  '② 「大雨」「河川氾濫」「土砂災害」のレベル3警報が3つ同時\n'
                  '③ 「大雪警報」または「暴風雪警報」\n'
                  '④ そのほか学校から連絡があったとき\n'
                  '警報がなくても、登校が難しいと判断したら「すぐーる」で連絡（遅刻・欠席にはならない）。',
                  style: tt.bodySmall,
                ),
                const SizedBox(height: 8),
                Text(
                  'この予測は気象庁の警報と予報からの目安です。最後は学校からの連絡で決まります。',
                  style: tt.bodySmall?.copyWith(color: cs.outline),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

// ───────────────────── 警報・台風 ─────────────────────

class _WarningsCard extends StatelessWidget {
  const _WarningsCard({required this.warnings, required this.typhoons});

  final AreaWarnings warnings;
  final List<String> typhoons;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final r = warnings.reportTime;
    return _Section(
      title: '${schoolPlaceName}の警報・注意報',
      icon: Icons.warning_amber_rounded,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final t in typhoons)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  const Text('🌀', style: TextStyle(fontSize: 18)),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      '${typhoonLabel(t)}が発生しています',
                      style: tt.titleSmall,
                    ),
                  ),
                ],
              ),
            ),
          if (warnings.warnings.isEmpty)
            Text('いまは出ていません', style: TextStyle(color: cs.outline)),
          for (final w in warnings.sorted)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 5),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    margin: const EdgeInsets.only(top: 2, right: 8),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 1,
                    ),
                    decoration: BoxDecoration(
                      color: levelColor(w.level),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      'Lv${w.level}',
                      style: TextStyle(
                        color: w.level == 2 ? Colors.black : Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${w.name}'
                          '${w.additions.isEmpty ? '' : '（${w.additions.join('・')}）'}',
                          style: tt.bodyLarge?.copyWith(
                            fontWeight: w.level >= 3 ? FontWeight.bold : null,
                          ),
                        ),
                        for (final p in w.periods)
                          Text(
                            p.sentence.isEmpty
                                ? '${_hm(p.start)}〜${_hm(p.end)}'
                                : p.sentence,
                            style: tt.bodySmall?.copyWith(color: cs.outline),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          if (warnings.headline.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(warnings.headline, style: tt.bodySmall),
          ],
          if (r != null)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                '気象庁 ${r.month}/${r.day} ${_hm(r)} 発表',
                style: tt.labelSmall?.copyWith(color: cs.outline),
              ),
            ),
        ],
      ),
    );
  }
}

// ───────────────────── いまの天気 ─────────────────────

class _NowCard extends StatelessWidget {
  const _NowCard({required this.forecast, required this.now});

  final WeatherForecast forecast;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final c = forecast.current;
    final today = forecast.dayOf(now);
    final w = weatherOf(c?.code, night: !(c?.isDay ?? true));

    Widget tile(IconData icon, String label, String value, [String? sub]) =>
        SizedBox(
          width: 150,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(icon, size: 20, color: cs.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        label,
                        style: tt.labelSmall?.copyWith(color: cs.outline),
                      ),
                      Text(value, style: tt.titleSmall),
                      if (sub != null && sub.isNotEmpty)
                        Text(
                          sub,
                          style: tt.labelSmall?.copyWith(color: cs.outline),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(w.icon, style: const TextStyle(fontSize: 56)),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        c?.temperature == null
                            ? '—'
                            : '${c!.temperature!.toStringAsFixed(1)}°',
                        style: tt.displaySmall,
                      ),
                      Text(w.label, style: tt.titleMedium),
                      Text(
                        '体感 ${_t(c?.apparent)}　'
                        '最高 ${_t(today?.max)} / 最低 ${_t(today?.min)}',
                        style: tt.bodySmall?.copyWith(color: cs.outline),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Wrap(
              children: [
                tile(
                  Icons.water_drop_outlined,
                  '湿度',
                  c?.humidity == null ? '—' : '${c!.humidity!.round()}%',
                ),
                tile(
                  Icons.speed,
                  '気圧',
                  c?.pressure == null ? '—' : '${c!.pressure!.round()}hPa',
                ),
                tile(
                  Icons.air,
                  '風',
                  c?.windSpeed == null
                      ? '—'
                      : '${windDirectionText(c!.windDirection)} '
                            '${c.windSpeed!.toStringAsFixed(1)}m/s',
                  windStrengthText(c?.windSpeed),
                ),
                tile(
                  Icons.umbrella_outlined,
                  '今日の雨量',
                  today?.precipitationSum == null
                      ? '—'
                      : '${today!.precipitationSum!.toStringAsFixed(1)}mm',
                  today?.precipitationProbability == null
                      ? null
                      : '降水確率 ${today!.precipitationProbability}%',
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ───────────────────── 10日間 ─────────────────────

class _TenDays extends StatelessWidget {
  const _TenDays({required this.days});

  final List<DailyWeather> days;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final mins = days.map((d) => d.min).whereType<double>();
    final maxs = days.map((d) => d.max).whereType<double>();
    if (mins.isEmpty || maxs.isEmpty) return const Text('データがありません');
    final lo = mins.reduce((a, b) => a < b ? a : b);
    final hi = maxs.reduce((a, b) => a > b ? a : b);

    return Column(
      children: [
        for (final d in days)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 5),
            child: Row(
              children: [
                SizedBox(
                  width: 64,
                  child: Text(
                    '${d.date.month}/${d.date.day}(${_wd[d.date.weekday - 1]})',
                    style: tt.bodySmall?.copyWith(
                      color: d.date.weekday == DateTime.sunday
                          ? cs.error
                          : d.date.weekday == DateTime.saturday
                          ? Colors.blue.shade700
                          : null,
                    ),
                  ),
                ),
                SizedBox(
                  width: 32,
                  child: Text(
                    weatherOf(d.code).icon,
                    style: const TextStyle(fontSize: 20),
                  ),
                ),
                SizedBox(
                  width: 64,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        d.precipitationProbability == null
                            ? ''
                            : '☔${d.precipitationProbability}%',
                        style: tt.labelSmall?.copyWith(
                          color: const Color(0xFF1565C0),
                        ),
                      ),
                      if ((d.precipitationSum ?? 0) > 0)
                        Text(
                          '${d.precipitationSum!.toStringAsFixed(1)}mm',
                          style: tt.labelSmall?.copyWith(
                            color: cs.outline,
                            fontSize: 10,
                          ),
                        ),
                    ],
                  ),
                ),
                SizedBox(
                  width: 34,
                  child: Text(
                    _t(d.min),
                    textAlign: TextAlign.right,
                    style: tt.bodySmall?.copyWith(
                      color: const Color(0xFF1E88E5),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: d.min == null || d.max == null
                      ? const SizedBox.shrink()
                      : TempRangeBar(min: d.min!, max: d.max!, lo: lo, hi: hi),
                ),
                const SizedBox(width: 8),
                SizedBox(
                  width: 34,
                  child: Text(
                    _t(d.max),
                    style: tt.bodySmall?.copyWith(
                      color: const Color(0xFFEF6C00),
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}
