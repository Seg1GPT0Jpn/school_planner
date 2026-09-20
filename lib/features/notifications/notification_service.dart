import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import '../study/pomodoro.dart';
import 'notification_planner.dart';

class NotificationService {
  NotificationService._();
  static final NotificationService instance = NotificationService._();

  final _plugin = FlutterLocalNotificationsPlugin();
  bool _ready = false;

  Future<void> init() async {
    if (kIsWeb || _ready) return;
    tzdata.initializeTimeZones();
    tz.setLocalLocation(tz.getLocation('Asia/Tokyo'));
    await _plugin.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      ),
    );
    final AndroidFlutterLocalNotificationsPlugin? android = _plugin
        .resolvePlatformSpecificImplementation();
    await android?.requestNotificationsPermission();
    _ready = true;
  }

  /// 予約をすべて入れ替える（ポモドーロのお知らせは残す）
  Future<void> replaceAll(List<PlannedNotification> plan) async {
    if (kIsWeb) return;
    await init();
    await _cancelWhere((id) => id < pomodoroIdBase);
    await _schedule(plan);
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

  Future<void> _schedule(List<PlannedNotification> plan) async {
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
              'tsuzuri_main',
              'つづりのお知らせ',
              channelDescription: '予定・テスト・ToDo のお知らせ',
              importance: Importance.high,
              priority: Priority.high,
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
