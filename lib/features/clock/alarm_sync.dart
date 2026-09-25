/// アプリを開くたびに、アラームの予約を最新の状態に合わせ直す係
///
/// （端末の再起動などで OS 側の予約が消えてしまった場合の保険にもなる）
library;

import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:material_ui/material_ui.dart';

import '../notifications/notification_service.dart';
import 'alarm_repository.dart';
import 'clock_models.dart';

class AlarmSync extends StatefulWidget {
  const AlarmSync({super.key, required this.child});
  final Widget child;

  @override
  State<AlarmSync> createState() => _AlarmSyncState();
}

class _AlarmSyncState extends State<AlarmSync> {
  StreamSubscription<User?>? _auth;
  StreamSubscription<List<Alarm>>? _alarms;

  @override
  void initState() {
    super.initState();
    if (kIsWeb) return;
    _auth = FirebaseAuth.instance.authStateChanges().listen(_onUser);
  }

  void _onUser(User? user) {
    _alarms?.cancel();
    if (user == null) return;
    _alarms = AlarmRepository(uid: user.uid).watch().listen((alarms) {
      NotificationService.instance.scheduleAlarms(alarms);
    });
  }

  @override
  void dispose() {
    _auth?.cancel();
    _alarms?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
