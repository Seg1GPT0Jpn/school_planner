/// いま鳴らすべきアラームがあるかどうかの見張り役
///
/// 通知をタップした（アプリが裏で動いている、または通知から起動した）ときに、
/// ここに ID を入れると、ルーター（app/router.dart）がアラーム画面へ連れて行く。
library;

import 'package:flutter/foundation.dart';

class AlarmRingStateNotifier extends ChangeNotifier {
  String? _alarmId;
  String? get alarmId => _alarmId;

  void show(String id) {
    if (_alarmId == id) return;
    _alarmId = id;
    notifyListeners();
  }

  void clear() {
    if (_alarmId == null) return;
    _alarmId = null;
    notifyListeners();
  }
}

/// アプリ全体で1つだけ使う
final AlarmRingStateNotifier alarmRingState = AlarmRingStateNotifier();
