import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:material_ui/material_ui.dart';

/// 教科の既定の色（自分で色を選んでいない教科に使う）
Color categoryColor(String? category) {
  return switch (category) {
    '国語' => Colors.red.shade400,
    '数学' => Colors.blue.shade500,
    '英語' => Colors.purple.shade400,
    '理科' => Colors.green.shade600,
    '社会' => Colors.orange.shade700,
    '情報' => Colors.teal.shade500,
    '副教科' => Colors.blueGrey.shade400,
    _ => Colors.grey.shade500,
  };
}

/// 教科の色を取り出す（自分で選んだ色があればそれ、なければ既定の色）
///
/// どの画面からでも使える。
Color subjectColorOf(BuildContext context, String? category) {
  final custom = SubjectColorScope.customColorsOf(context);
  final value = category == null ? null : custom[category];
  return value != null ? Color(value) : categoryColor(category);
}

// ------------------------------------------------------------
// 保存・読み込み
// ------------------------------------------------------------

/// 教科の色の保存場所：users/{uid}/settings/subject_colors
class SubjectColorRepository {
  SubjectColorRepository({required this.uid, FirebaseFirestore? firestore})
    : _db = firestore ?? FirebaseFirestore.instance;

  final String uid;
  final FirebaseFirestore _db;

  DocumentReference<Map<String, dynamic>> get _doc => _db
      .collection('users')
      .doc(uid)
      .collection('settings')
      .doc('subject_colors');

  /// 自分で選んだ色の一覧を見張る（教科名 → 色）
  Stream<Map<String, int>> watch() {
    return _doc.snapshots().map((snapshot) {
      final raw = snapshot.data()?['colors'];
      if (raw is! Map) return const <String, int>{};
      return {
        for (final entry in raw.entries)
          entry.key as String: (entry.value as num).toInt(),
      };
    });
  }

  /// 教科の色を保存する
  Future<void> setColor(String category, int colorValue) {
    return _doc.set({
      'colors': {category: colorValue},
    }, SetOptions(merge: true));
  }

  /// 教科の色を既定に戻す
  Future<void> resetColor(String category) {
    return _doc.set({
      'colors': {category: FieldValue.delete()},
    }, SetOptions(merge: true));
  }
}

// ------------------------------------------------------------
// アプリ全体に色を行き渡らせる係
// ------------------------------------------------------------

/// 自分で選んだ教科の色を、その内側のすべての画面に届ける
class SubjectColorScope extends InheritedWidget {
  const SubjectColorScope({
    super.key,
    required this.customColors,
    required super.child,
  });

  /// 自分で選んだ色（教科名 → 色）
  final Map<String, int> customColors;

  static Map<String, int> customColorsOf(BuildContext context) {
    return context
            .dependOnInheritedWidgetOfExactType<SubjectColorScope>()
            ?.customColors ??
        const {};
  }

  @override
  bool updateShouldNotify(SubjectColorScope oldWidget) =>
      !mapEquals(oldWidget.customColors, customColors);
}

/// ログイン中のユーザーの教科の色を見張り、SubjectColorScope として届ける
///
/// アプリ全体の一番外側（app.dart）に置く。
/// ログアウト中は、色は空（すべて既定の色）になる。
class SubjectColorProvider extends StatefulWidget {
  const SubjectColorProvider({super.key, required this.child});

  final Widget child;

  @override
  State<SubjectColorProvider> createState() => _SubjectColorProviderState();
}

class _SubjectColorProviderState extends State<SubjectColorProvider> {
  StreamSubscription<User?>? _authSubscription;
  StreamSubscription<Map<String, int>>? _colorSubscription;
  Map<String, int> _colors = const {};

  @override
  void initState() {
    super.initState();
    // ログイン・ログアウトのたびに、見張る相手を切り替える
    _authSubscription = FirebaseAuth.instance.authStateChanges().listen(
      _onUserChanged,
    );
  }

  void _onUserChanged(User? user) {
    _colorSubscription?.cancel();
    _colorSubscription = null;

    if (user == null) {
      if (mounted) setState(() => _colors = const {});
      return;
    }

    _colorSubscription = SubjectColorRepository(uid: user.uid).watch().listen(
      (colors) {
        if (mounted) setState(() => _colors = colors);
      },
      onError: (Object error) {
        debugPrint('【教科の色】読み込みエラー：$error');
      },
    );
  }

  @override
  void dispose() {
    _authSubscription?.cancel();
    _colorSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SubjectColorScope(customColors: _colors, child: widget.child);
  }
}
