/// どの画面からでも設定を読めるようにする
library;

import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:material_ui/material_ui.dart';

import 'app_settings.dart';
import 'settings_repository.dart';

/// 使い方：`final s = SettingsScope.of(context);`
class SettingsScope extends InheritedWidget {
  const SettingsScope({
    super.key,
    required this.settings,
    required super.child,
  });

  final AppSettings settings;

  static AppSettings of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<SettingsScope>()?.settings ??
      const AppSettings();

  /// ログインしていないときなど、設定が読めていなくても困らないように
  static SettingsRepository? repositoryOf(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    return uid == null ? null : SettingsRepository(uid: uid);
  }

  @override
  bool updateShouldNotify(SettingsScope old) =>
      !mapEquals(old.settings.toMap(), settings.toMap());
}

/// アプリ全体を包んで、設定の変更を配る
class SettingsProvider extends StatefulWidget {
  const SettingsProvider({super.key, required this.child});

  final Widget child;

  @override
  State<SettingsProvider> createState() => _SettingsProviderState();
}

class _SettingsProviderState extends State<SettingsProvider> {
  StreamSubscription<User?>? _auth;
  StreamSubscription<AppSettings>? _settings;
  AppSettings _current = const AppSettings();

  @override
  void initState() {
    super.initState();
    _auth = FirebaseAuth.instance.authStateChanges().listen(_listen);
  }

  void _listen(User? user) {
    _settings?.cancel();
    _settings = null;
    if (user == null) {
      if (mounted) setState(() => _current = const AppSettings());
      return;
    }
    _settings = SettingsRepository(uid: user.uid).watch().listen((s) {
      if (mounted) setState(() => _current = s);
    });
  }

  @override
  void dispose() {
    _auth?.cancel();
    _settings?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      SettingsScope(settings: _current, child: widget.child);
}
