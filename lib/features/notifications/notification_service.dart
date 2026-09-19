import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

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
    final android = _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    await android?.requestNotificationsPermission();
    _ready = true;
  }

  /// 予約をすべて入れ替える
  Future<void> replaceAll(List<PlannedNotification> plan) async {
    if (kIsWeb) return;
    await init();
    await _plugin.cancelAll();
    for (final n in plan) {
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
