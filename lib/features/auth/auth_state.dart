import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

/// ログイン状態が変わったら知らせる係
///
/// 画面遷移（go_router）がこれを見張っていて、
/// ログイン・ログアウトのたびに「今いてよい画面か」を確認し直す。
class AuthStateNotifier extends ChangeNotifier {
  AuthStateNotifier() {
    _subscription = FirebaseAuth.instance.authStateChanges().listen(
      (_) => notifyListeners(),
    );
  }

  late final StreamSubscription<User?> _subscription;

  /// 今ログインしているか
  bool get isLoggedIn => FirebaseAuth.instance.currentUser != null;

  /// 今ログインしている人のID（ログインしていなければ null）
  String? get uid => FirebaseAuth.instance.currentUser?.uid;

  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }
}
