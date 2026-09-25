import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import '../clock/alarm_ring_state.dart';
import '../clock/clock_models.dart';
import '../study/pomodoro.dart';
import 'notification_planner.dart';

/// 通知の応答（タップ・スヌーズ・停止）を裏（バックグラウンド）で受け取る入り口
///
/// アプリが完全に終了しているときでも、通知のボタンを押すとここが呼ばれる。
/// トップレベル関数（クラスの外）でないと動かないので、ここに置いている。
@pragma('vm:entry-point')
void _onBackgroundNotificationResponse(NotificationResponse response) {
  NotificationService.instance._handleAlarmResponse(response);
}

/// アラーム用の通知の ID の範囲（ポモドーロなど他のお知らせの ID とぶつからないように分けている）
const int alarmIdBase = 950000;

class NotificationService {
  NotificationService._();
  static final NotificationService instance = NotificationService._();

  final _plugin = FlutterLocalNotificationsPlugin();
  bool _ready = false;
  String _timeZone = 'Asia/Tokyo';

  /// アラームの Firestore の ID → 通知の ID（曜日ごとに 0〜7 の枝番を持てる）
  int alarmNotificationId(String alarmId, {int weekday = 0}) =>
      alarmIdBase + (alarmId.hashCode.abs() % 8000) * 10 + weekday;

  /// 設定のタイムゾーンに合わせる（知らない名前のときは何もしない）
  Future<void> setTimeZone(String name) async {
    if (kIsWeb || name.isEmpty || name == _timeZone) return;
    await init();
    try {
      tz.setLocalLocation(tz.getLocation(name));
      _timeZone = name;
    } catch (e) {
      debugPrint('【通知】知らないタイムゾーン：$name');
    }
  }

  Future<void> init() async {
    if (kIsWeb || _ready) return;
    tzdata.initializeTimeZones();
    tz.setLocalLocation(tz.getLocation(_timeZone));
    await _plugin.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      ),
      onDidReceiveNotificationResponse: _handleAlarmResponse,
      onDidReceiveBackgroundNotificationResponse:
          _onBackgroundNotificationResponse,
    );
    final AndroidFlutterLocalNotificationsPlugin? android = _plugin
        .resolvePlatformSpecificImplementation();
    await android?.requestNotificationsPermission();
    await android?.requestExactAlarmsPermission();
    _ready = true;
  }

  /// 通知（アラーム）の応答（本体タップ・スヌーズ・停止）を処理する
  ///
  /// ・本体タップ　　→ アラーム画面を開く（[alarmRingState] 経由）
  /// ・「スヌーズ」　→ 指定の分だけあとに、もう一度鳴らす
  /// ・「止める」　　→ そのまま消音（何もしない）
  void _handleAlarmResponse(NotificationResponse response) {
    final payload = response.payload;
    if (payload == null || !payload.startsWith('alarm:')) return;
    final parts = payload.substring('alarm:'.length).split('|');
    if (parts.isEmpty || parts[0].isEmpty) return;
    final alarmId = parts[0];
    final snoozeMinutes = parts.length > 1 ? int.tryParse(parts[1]) ?? 5 : 5;

    if (response.actionId == 'stop') {
      return;
    }
    if (response.actionId == 'snooze') {
      unawaited(_scheduleSnooze(alarmId, payload, snoozeMinutes));
      return;
    }
    // 通知の本体をタップ → アプリを開いてアラーム画面を出す
    alarmRingState.show(alarmId);
  }

  Future<void> _scheduleSnooze(
    String alarmId,
    String payload,
    int minutes,
  ) async {
    await init();
    final id = alarmNotificationId(alarmId);
    try {
      await _plugin.zonedSchedule(
        id: id,
        title: 'スヌーズ',
        body: 'アラームの時間です',
        scheduledDate: tz.TZDateTime.from(
          DateTime.now().add(Duration(minutes: minutes)),
          tz.local,
        ),
        payload: payload,
        notificationDetails: _alarmNotificationDetails(vibrate: true),
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      );
    } catch (e) {
      debugPrint('【アラーム】スヌーズの予約に失敗：$e');
    }
  }

  /// アプリが通知（アラーム）から起動されたときは、起動直後にアラーム画面を出す
  Future<void> checkLaunchedByAlarm() async {
    if (kIsWeb) return;
    await init();
    final details = await _plugin.getNotificationAppLaunchDetails();
    if (details?.didNotificationLaunchApp != true) return;
    final response = details!.notificationResponse;
    if (response != null) _handleAlarmResponse(response);
  }

  NotificationDetails _alarmNotificationDetails({required bool vibrate}) =>
      NotificationDetails(
        android: AndroidNotificationDetails(
          'tsuzuri_alarm',
          'つづりのアラーム',
          channelDescription: 'アラーム・お休み時間の起床通知',
          importance: Importance.max,
          priority: Priority.max,
          category: AndroidNotificationCategory.alarm,
          fullScreenIntent: true,
          ongoing: true,
          autoCancel: false,
          playSound: true,
          enableVibration: vibrate,
          actions: const [
            AndroidNotificationAction(
              'snooze',
              'スヌーズ',
              showsUserInterface: false,
            ),
            AndroidNotificationAction(
              'stop',
              '止める',
              showsUserInterface: false,
              cancelNotification: true,
            ),
          ],
        ),
      );

  /// アラーム一覧を、鳴動の予約に反映する（既存の予約はすべて入れ替える）
  Future<void> scheduleAlarms(List<Alarm> alarms) async {
    if (kIsWeb) return;
    await init();
    // アラーム用の ID 帯だけを取り消す（他のお知らせの予約は残す）
    final pending = await _plugin.pendingNotificationRequests();
    for (final p in pending) {
      if (p.id >= alarmIdBase && p.id < alarmIdBase + 90000) {
        await _plugin.cancel(id: p.id);
      }
    }
    final now = DateTime.now();
    for (final a in alarms) {
      if (!a.enabled || a.id == null) continue;
      final payload = 'alarm:${a.id}|${a.snoozeMinutes}|${a.dismissAfterMinutes}';
      if (a.repeats) {
        for (final wd in a.weekdays) {
          final fire = _nextWeekday(now, wd, a.time.hour, a.time.minute);
          await _scheduleAlarmAt(
            id: alarmNotificationId(a.id!, weekday: wd),
            title: a.displayLabel,
            body: a.kind == AlarmKind.wakeUp ? '起きる時間です' : 'アラームの時間です',
            at: fire,
            payload: payload,
            vibrate: a.vibrate,
            repeatWeekly: true,
          );
        }
      } else {
        final fire = a.nextFire(now);
        if (fire == null) continue;
        await _scheduleAlarmAt(
          id: alarmNotificationId(a.id!),
          title: a.displayLabel,
          body: a.kind == AlarmKind.wakeUp ? '起きる時間です' : 'アラームの時間です',
          at: fire,
          payload: payload,
          vibrate: a.vibrate,
          repeatWeekly: false,
        );
      }
    }
  }

  DateTime _nextWeekday(DateTime from, int weekday, int hour, int minute) {
    for (var i = 0; i < 8; i++) {
      final d = DateTime(from.year, from.month, from.day + i, hour, minute);
      if (d.weekday == weekday && d.isAfter(from)) return d;
    }
    return DateTime(
      from.year,
      from.month,
      from.day,
      hour,
      minute,
    ).add(const Duration(days: 7));
  }

  Future<void> _scheduleAlarmAt({
    required int id,
    required String title,
    required String body,
    required DateTime at,
    required String payload,
    required bool vibrate,
    required bool repeatWeekly,
  }) async {
    try {
      await _plugin.zonedSchedule(
        id: id,
        title: title,
        body: body,
        scheduledDate: tz.TZDateTime.from(at, tz.local),
        payload: payload,
        notificationDetails: _alarmNotificationDetails(vibrate: vibrate),
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        matchDateTimeComponents: repeatWeekly
            ? DateTimeComponents.dayOfWeekAndTime
            : null,
      );
    } catch (e) {
      debugPrint('【アラーム】予約に失敗：$e');
    }
  }

  /// 1件のアラームの予約だけを取り消す（曜日ごとの枝番もすべて）
  Future<void> cancelAlarm(String alarmId) async {
    if (kIsWeb) return;
    await init();
    for (var wd = 0; wd <= 7; wd++) {
      await _plugin.cancel(id: alarmNotificationId(alarmId, weekday: wd));
    }
  }

  /// タイマー終了時など、1件だけの簡単なお知らせを予約する
  /// （アプリが裏や画面ロック中でも、時間になったら通知が出るようにする保険）
  Future<void> scheduleOneOff({
    required int id,
    required String title,
    required String body,
    required DateTime at,
  }) async {
    if (kIsWeb) return;
    await init();
    try {
      await _plugin.zonedSchedule(
        id: id,
        title: title,
        body: body,
        scheduledDate: tz.TZDateTime.from(at, tz.local),
        notificationDetails: _alarmNotificationDetails(vibrate: true),
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      );
    } catch (e) {
      debugPrint('【タイマー】予約に失敗：$e');
    }
  }

  Future<void> cancelOneOff(int id) async {
    if (kIsWeb) return;
    await init();
    await _plugin.cancel(id: id);
  }

  /// 予約をすべて入れ替える（ポモドーロのお知らせは残す）
  Future<void> replaceAll(
    List<PlannedNotification> plan, {
    bool sound = true,
  }) async {
    if (kIsWeb) return;
    await init();
    await _cancelWhere((id) => id < pomodoroIdBase);
    await _schedule(plan, sound: sound);
  }

  /// ポモドーロの区切りのお知らせを予約する
  Future<void> schedulePomodoro(List<PlannedNotification> plan) async {
    if (kIsWeb) return;
    await init();
    await cancelPomodoro();
    await _schedule(plan);
  }

  /// ポモドーロのお知らせを取り消す
  Future<void> cancelPomodoro() async {
    if (kIsWeb) return;
    await init();
    await _cancelWhere((id) => id >= pomodoroIdBase);
  }

  Future<void> _cancelWhere(bool Function(int id) test) async {
    final pending = await _plugin.pendingNotificationRequests();
    for (final p in pending) {
      if (test(p.id)) await _plugin.cancel(id: p.id);
    }
  }

  Future<void> _schedule(
    List<PlannedNotification> plan, {
    bool sound = true,
  }) async {
    final now = DateTime.now();
    for (final n in plan) {
      if (!n.time.isAfter(now)) continue;
      try {
        await _plugin.zonedSchedule(
          id: n.id,
          title: n.title,
          body: n.body,
          scheduledDate: tz.TZDateTime.from(n.time, tz.local),
          notificationDetails: NotificationDetails(
            android: AndroidNotificationDetails(
              // 音のあり・なしはチャンネルを分ける（あとから変えられないため）
              sound ? 'tsuzuri_main' : 'tsuzuri_quiet',
              sound ? 'つづりのお知らせ' : 'つづりのお知らせ（音なし）',
              channelDescription: '予定・テスト・ToDo のお知らせ',
              importance: Importance.high,
              priority: Priority.high,
              playSound: sound,
              styleInformation: BigTextStyleInformation(n.body),
            ),
          ),
          androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        );
      } catch (e) {
        debugPrint('【通知】予約に失敗：$e');
      }
    }
  }

  Future<void> cancelAll() async {
    if (kIsWeb) return;
    await init();
    await _plugin.cancelAll();
  }
}
