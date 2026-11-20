/// 予定の場所までの移動時間と、出発時刻の目安を出す
library;

import 'dart:async';

import 'package:material_ui/material_ui.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/maps.dart';
import '../location/current_location_service.dart';
import '../settings/app_settings.dart';
import '../settings/settings_scope.dart';
import '../timetable/school_periods.dart';
import 'geocoder.dart';
import 'osrm_service.dart';
import 'places_page.dart';
import 'travel.dart';
import 'travel_realtime_service.dart';

/// 出発地の種類から、実際の緯度・経度を引く（現在地は [currentPoint] を渡す）
LatLng? originPoint(TravelOrigin o, AppSettings s, LatLng? currentPoint) =>
    switch (o) {
      TravelOrigin.home => s.homePoint,
      TravelOrigin.school => s.schoolPoint,
      TravelOrigin.current => currentPoint,
    };

/// 設定と予定から、どこから出るか・移動の計画を決める
///
/// 出発地が「現在地」のときは、[currentPoint] にその緯度・経度を渡す
/// （まだ取得できていなければ null のままでよい：null を返す）。
TravelPlan? travelPlanFor({
  required AppSettings s,
  required LatLng destination,
  required DateTime start,
  TravelOrigin? origin,
  TravelMode? mode,
  LatLng? currentPoint,
}) {
  final o = origin ?? originFor(s, start);
  final from = originPoint(o, s, currentPoint);
  if (from == null) return null;
  return planTravel(
    from: from,
    to: destination,
    arriveBy: start,
    origin: o,
    mode: mode ?? s.travelMode,
    bufferMinutes: s.travelBufferMinutes,
  );
}

/// ふだんはどこから出るか
TravelOrigin originFor(AppSettings s, DateTime start) => suggestOrigin(
  start: start,
  hasHome: s.homePoint != null,
  hasSchool: s.schoolPoint != null,
  departFromSchool: s.departFromSchool,
  schoolEndMinutes: schoolEndMinutesOn(start),
);

IconData _modeIcon(TravelPlan p) => p.walking
    ? Icons.directions_walk
    : (p.mode == TravelMode.car ? Icons.directions_car : Icons.train);

Future<void> _openDirections(
  BuildContext context,
  LatLng? from,
  TravelPlan plan,
  String destinationText,
  LatLng destination,
) async {
  if (from == null) return;
  final messenger = ScaffoldMessenger.of(context);
  var ok = false;
  try {
    ok = await launchUrl(
      directionsUri(
        from: from,
        destinationText: destinationText,
        destination: destination,
        mode: plan.walking ? TravelMode.transit : plan.mode,
      ),
      mode: LaunchMode.externalApplication,
    );
  } catch (_) {
    ok = false;
  }
  if (!ok) {
    messenger.showSnackBar(const SnackBar(content: Text('マップを開けませんでした')));
  }
}

/// 場所の文字から位置を調べる（入力中は少し待ってから調べる）
mixin _Lookup<T extends StatefulWidget> on State<T> {
  Timer? _timer;
  String _query = '';
  Future<GeoResult?>? _future;

  void lookup(String text, {Duration wait = Duration.zero}) {
    final t = text.trim();
    _timer?.cancel();
    if (t == _query && _future != null) return;
    if (t.isEmpty) {
      setState(() {
        _query = '';
        _future = null;
      });
      return;
    }
    void run() {
      if (!mounted) return;
      setState(() {
        _query = t;
        _future = Geocoder.lookup(t);
      });
    }

    if (wait == Duration.zero) {
      _query = t;
      _future = Geocoder.lookup(t);
    } else {
      _timer = Timer(wait, run);
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}

// ───────────────────── 予定の画面用（くわしい） ─────────────────────

class TravelCard extends StatefulWidget {
  const TravelCard({
    super.key,
    required this.destination,
    required this.start,
    this.isAllDay = false,
  });

  /// 予定の「場所」の文字
  final String destination;
  final DateTime start;
  final bool isAllDay;

  @override
  State<TravelCard> createState() => _TravelCardState();
}

class _TravelCardState extends State<TravelCard> with _Lookup<TravelCard> {
  /// 画面で選び直したもの（null ならいつもの設定）
  TravelOrigin? _origin;
  TravelMode? _mode;

  /// 「現在地から」を選んだときに取得する現在地（選ぶまでは取得しない）
  Future<LocationResult>? _currentLocationFuture;

  Future<LocationResult> _ensureCurrentLocation() =>
      _currentLocationFuture ??= CurrentLocationService.getCurrent();

  @override
  void initState() {
    super.initState();
    lookup(widget.destination);
  }

  @override
  void didUpdateWidget(TravelCard old) {
    super.didUpdateWidget(old);
    if (old.destination != widget.destination) {
      lookup(widget.destination, wait: const Duration(milliseconds: 900));
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = SettingsScope.of(context);
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final dest = widget.destination.trim();
    if (dest.isEmpty) return const SizedBox.shrink();

    final note = tt.bodySmall?.copyWith(color: cs.outline);

    Widget frame(List<Widget> children) => Card(
      margin: const EdgeInsets.fromLTRB(40, 4, 0, 8),
      color: cs.surfaceContainerLow,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: children,
        ),
      ),
    );

    if (s.homePoint == null && s.schoolPoint == null) {
      return frame([
        Text('自宅・学校の場所を登録すると、何時に出ればよいかがわかります', style: note),
        Align(
          alignment: Alignment.centerRight,
          child: TextButton.icon(
            icon: const Icon(Icons.home_work_outlined),
            label: const Text('場所を登録する'),
            onPressed: () => Navigator.of(
              context,
            ).push(MaterialPageRoute<void>(builder: (_) => const PlacesPage())),
          ),
        ),
      ]);
    }

    return FutureBuilder<GeoResult?>(
      future: _future,
      builder: (context, snap) {
        if (_future == null || snap.connectionState != ConnectionState.done) {
          return frame([
            Row(
              children: [
                const SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
                const SizedBox(width: 8),
                Text('場所を調べています…', style: note),
              ],
            ),
          ]);
        }
        final geo = snap.data;
        if (geo == null) {
          return frame([
            Text(
              '場所の位置がわかりませんでした。'
              '住所や「〇〇駅」のような名前を入れると、移動時間の目安が出ます。',
              style: note,
            ),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                icon: const Icon(Icons.map_outlined),
                label: const Text('Google マップで開く'),
                onPressed: () => openMap(context, dest),
              ),
            ),
          ]);
        }

        final origin = _origin ?? originFor(s, widget.start);
        final canHome = s.homePoint != null, canSchool = s.schoolPoint != null;

        Widget buildCard(LatLng? currentPoint, {String? currentError}) {
          final plan = travelPlanFor(
            s: s,
            destination: geo.point,
            start: widget.start,
            origin:
                (origin == TravelOrigin.home && !canHome) ||
                    (origin == TravelOrigin.school && !canSchool)
                ? null
                : origin,
            mode: _mode,
            currentPoint: currentPoint,
          );

          final chooser = Wrap(
            spacing: 8,
            runSpacing: 4,
            children: [
              SegmentedButton<TravelOrigin>(
                showSelectedIcon: false,
                style: const ButtonStyle(visualDensity: VisualDensity.compact),
                segments: [
                  if (canHome)
                    const ButtonSegment(
                      value: TravelOrigin.home,
                      label: Text('自宅から'),
                    ),
                  if (canSchool)
                    const ButtonSegment(
                      value: TravelOrigin.school,
                      label: Text('学校から'),
                    ),
                  const ButtonSegment(
                    value: TravelOrigin.current,
                    icon: Icon(Icons.my_location),
                    label: Text('現在地から'),
                  ),
                ],
                selected: {plan?.origin ?? origin},
                onSelectionChanged: (v) {
                  setState(() => _origin = v.first);
                  if (v.first == TravelOrigin.current) {
                    _ensureCurrentLocation();
                  }
                },
              ),
              SegmentedButton<TravelMode>(
                showSelectedIcon: false,
                style: const ButtonStyle(visualDensity: VisualDensity.compact),
                segments: const [
                  ButtonSegment(
                    value: TravelMode.transit,
                    icon: Icon(Icons.train_outlined),
                    label: Text('電車・バス'),
                  ),
                  ButtonSegment(
                    value: TravelMode.car,
                    icon: Icon(Icons.directions_car_outlined),
                    label: Text('車'),
                  ),
                ],
                selected: {_mode ?? s.travelMode},
                onSelectionChanged: (v) => setState(() => _mode = v.first),
              ),
            ],
          );

          if (origin == TravelOrigin.current && currentPoint == null) {
            return frame([
              if (currentError != null)
                Text(currentError, style: note)
              else
                Row(
                  children: [
                    const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                    const SizedBox(width: 8),
                    Text('現在地を調べています…', style: note),
                  ],
                ),
              const SizedBox(height: 8),
              chooser,
            ]);
          }

          if (plan == null) {
            return frame([
              Text(
                '${origin.label}のすぐ近くです（移動の時間はほとんどかかりません）',
                style: tt.bodyMedium,
              ),
              const SizedBox(height: 8),
              chooser,
            ]);
          }

          final fromPoint = originPoint(plan.origin, s, currentPoint);

          return frame([
            Row(
              children: [
                Icon(_modeIcon(plan), size: 20, color: cs.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '${plan.origin.label}から${plan.modeLabel}で 約${plan.minutes}分',
                    style: tt.titleSmall,
                  ),
                ),
              ],
            ),
            if (plan.walking)
              // 徒歩のときは、無料の OSRM（徒歩用）で実際の歩道にそった時間を出す
              // （直線距離×係数の目安より正確。取れなければ何も出さない）
              FutureBuilder<int?>(
                future: fromPoint == null
                    ? Future.value(null)
                    : OsrmService.instance.fetchWalkMinutes(
                        from: fromPoint,
                        to: geo.point,
                      ),
                builder: (context, walkSnap) {
                  final walk = walkSnap.data;
                  if (walk == null) return const SizedBox.shrink();
                  return Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                      '実際の道なりでは：約$walk分',
                      style: note,
                    ),
                  );
                },
              )
            else
              // 渋滞・電車の遅れを考慮した実際の時間（取れなければ何も出さない）
              FutureBuilder<int?>(
                future: fromPoint == null
                    ? Future.value(null)
                    : TravelRealtimeService.instance.fetchMinutes(
                        from: fromPoint,
                        to: geo.point,
                        mode: plan.mode,
                        arriveBy: plan.arriveBy,
                      ),
                builder: (context, rtSnap) {
                  final rt = rtSnap.data;
                  if (rt != null) {
                    return Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Row(
                        children: [
                          Icon(
                            Icons.traffic_outlined,
                            size: 14,
                            color: cs.primary,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '今の渋滞・遅れを考えると：約$rt分',
                            style: note?.copyWith(color: cs.primary),
                          ),
                        ],
                      ),
                    );
                  }
                  // ここまで取れないときは、車移動だけ「実際の道なり」の時間を
                  // 無料の OSRM から出す（渋滞は含まない・直線距離の目安より正確）
                  if (plan.mode != TravelMode.car || fromPoint == null) {
                    return const SizedBox.shrink();
                  }
                  return FutureBuilder<int?>(
                    future: OsrmService.instance.fetchCarMinutes(
                      from: fromPoint,
                      to: geo.point,
                    ),
                    builder: (context, osrmSnap) {
                      final road = osrmSnap.data;
                      if (road == null) return const SizedBox.shrink();
                      return Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Text(
                          '実際の道なりでは：約$road分（渋滞は含みません）',
                          style: note,
                        ),
                      );
                    },
                  );
                },
              ),
            if (!widget.isAllDay) ...[
              const SizedBox(height: 4),
              Text(
                '${s.timeOf(plan.departAt)}ごろに出発',
                style: tt.titleMedium?.copyWith(
                  color: cs.primary,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                plan.bufferMinutes == 0
                    ? '${s.timeOf(plan.arriveBy)}に着くように'
                    : '${s.timeOf(plan.arriveBy)}の${plan.bufferMinutes}分前に着くように',
                style: note,
              ),
            ],
            const SizedBox(height: 4),
            Text(
              'まっすぐ${plan.distanceLabel}'
              '${geo.label.isEmpty ? '' : '・見つかった場所：${geo.label}'}',
              style: note,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 8),
            chooser,
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                icon: const Icon(Icons.directions),
                label: const Text('Google マップで経路を見る'),
                onPressed: () =>
                    _openDirections(context, fromPoint, plan, dest, geo.point),
              ),
            ),
            Text('距離から出した目安です。電車の時刻や渋滞はマップで確かめてください。', style: note),
          ]);
        }

        if (origin == TravelOrigin.current) {
          return FutureBuilder<LocationResult>(
            future: _ensureCurrentLocation(),
            builder: (context, locSnap) {
              if (locSnap.connectionState != ConnectionState.done) {
                return buildCard(null);
              }
              final loc = locSnap.data;
              if (loc == null || !loc.isOk) {
                final msg = loc == null
                    ? '現在地を取得できませんでした。'
                    : CurrentLocationService.messageFor(loc.failure!);
                return buildCard(null, currentError: msg);
              }
              final (lat, lng) = loc.point!;
              return buildCard(LatLng(lat, lng));
            },
          );
        }
        return buildCard(null);
      },
    );
  }
}

// ───────────────────── ホーム用（1行） ─────────────────────

/// 「🚃 13:25ごろ出発（自宅から約25分）」の1行。わからないときは何も出さない
class TravelHint extends StatefulWidget {
  const TravelHint({super.key, required this.destination, required this.start});

  final String destination;
  final DateTime start;

  @override
  State<TravelHint> createState() => _TravelHintState();
}

class _TravelHintState extends State<TravelHint> with _Lookup<TravelHint> {
  @override
  void initState() {
    super.initState();
    lookup(widget.destination);
  }

  @override
  void didUpdateWidget(TravelHint old) {
    super.didUpdateWidget(old);
    if (old.destination != widget.destination) lookup(widget.destination);
  }

  @override
  Widget build(BuildContext context) {
    final s = SettingsScope.of(context);
    if (s.homePoint == null && s.schoolPoint == null) {
      return const SizedBox.shrink();
    }
    return FutureBuilder<GeoResult?>(
      future: _future,
      builder: (context, snap) {
        final geo = snap.data;
        if (geo == null) return const SizedBox.shrink();
        final plan = travelPlanFor(
          s: s,
          destination: geo.point,
          start: widget.start,
        );
        if (plan == null) return const SizedBox.shrink();
        final cs = Theme.of(context).colorScheme;
        final tt = Theme.of(context).textTheme;
        final overdue = DateTime.now().isAfter(plan.departAt);
        return InkWell(
          onTap: () => _openDirections(
            context,
            originPoint(plan.origin, s, null),
            plan,
            widget.destination,
            geo.point,
          ),
          borderRadius: BorderRadius.circular(6),
          child: Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Row(
              children: [
                Icon(
                  _modeIcon(plan),
                  size: 14,
                  color: overdue ? cs.error : cs.primary,
                ),
                const SizedBox(width: 4),
                Flexible(
                  child: Text(
                    '${s.timeOf(plan.departAt)}ごろ出発'
                    '（${plan.origin.label}から約${plan.minutes}分）',
                    style: tt.bodySmall?.copyWith(
                      color: overdue ? cs.error : cs.primary,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
