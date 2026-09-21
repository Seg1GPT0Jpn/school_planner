/// 「案内（オンボーディング）が終わっているか」の見張り役
///
/// ログインしている人が変わるたびに、その人の案内の進み具合を Firestore から見て、
/// go_router の画面遷移（redirect）が参照する。
library;

import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import 'onboarding_repository.dart';

class OnboardingStateNotifier extends ChangeNotifier {
  String? _uid;
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _subscription;

  bool _loading = true;
  bool _completed = false;

  /// まだ Firestore から読めていないか（読めるまでは画面遷移を保留する）
  bool get isLoading => _loading;

  /// 案内をぜんぶ終えているか
  bool get isCompleted => _completed;

  /// 見る相手（ログインしている人）を切りかえる。同じ人なら何もしない
  void bind(String? uid) {
    if (uid == _uid) return;
    _uid = uid;
    _subscription?.cancel();
    _subscription = null;

    if (uid == null) {
      _loading = false;
      _completed = false;
      notifyListeners();
      return;
    }

    _loading = true;
    _completed = false;
    final repo = OnboardingRepository(uid: uid);
    // ここでは notify しない（redirect の実行中に呼ばれるため。次の1ティックで届く）
    _subscription = repo.watch().listen(
      (doc) async {
        if (OnboardingRepository.isCompleted(doc.data())) {
          _loading = false;
          _completed = true;
          notifyListeners();
          return;
        }

        // 案内はまだ「終わった」記録がない → 案内を作る前から
        // 使っていた人（＝もうデータがある人）かどうかを見る。
        // そういう人には、あとから追加した案内をいまさら強制しない。
        bool hasExistingData;
        try {
          hasExistingData = await repo.hasExistingData();
        } catch (_) {
          hasExistingData = false;
        }
        if (_uid != uid) return; // その間にログインした人が変わっていたら何もしない

        if (hasExistingData) {
          // ignore: unawaited_futures
          repo.markCompleted();
          _loading = false;
          _completed = true;
          notifyListeners();
          return;
        }

        _loading = false;
        _completed = false;
        notifyListeners();
      },
      onError: (_) {
        // 読めなくても案内をやり直させる（true 扱いにはしない）
        _loading = false;
        _completed = false;
        notifyListeners();
      },
    );
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }
}
