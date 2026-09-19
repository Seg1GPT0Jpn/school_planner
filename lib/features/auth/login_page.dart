import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:material_ui/material_ui.dart';

/// ログイン画面
class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  /// ログイン処理中か（ボタンを連打できないようにする）
  bool _isBusy = false;

  /// 画面に表示するエラーメッセージ
  String? _errorMessage;

  Future<void> _signInWithGoogle() async {
    setState(() {
      _isBusy = true;
      _errorMessage = null;
    });

    try {
      if (kIsWeb) {
        // Web 版：Google のログイン用の小さなウィンドウを開く
        await FirebaseAuth.instance.signInWithPopup(GoogleAuthProvider());
      } else {
        // Android 版は、Android で動かす段階で設定する
        setState(() {
          _errorMessage = 'Android 版のログインは、後の段階で設定します。';
        });
      }
    } on FirebaseAuthException catch (e) {
      // ログイン用のウィンドウを自分で閉じた場合は、エラー扱いしない
      final closedByUser =
          e.code == 'popup-closed-by-user' ||
          e.code == 'cancelled-popup-request';
      if (!closedByUser) {
        setState(() {
          _errorMessage = 'ログインに失敗しました（${e.code}）';
        });
      }
    } finally {
      if (mounted) {
        setState(() => _isBusy = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.menu_book, size: 72, color: colorScheme.primary),
              const SizedBox(height: 16),
              Text('わたしの手帳', style: textTheme.headlineMedium),
              const SizedBox(height: 8),
              Text('時間割・予定・目標をひとつに', style: textTheme.bodyMedium),
              const SizedBox(height: 32),
              FilledButton.icon(
                onPressed: _isBusy ? null : _signInWithGoogle,
                icon: _isBusy
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.login),
                label: const Text('Google でログイン'),
              ),
              if (_errorMessage != null) ...[
                const SizedBox(height: 16),
                Text(
                  _errorMessage!,
                  style: TextStyle(color: colorScheme.error),
                  textAlign: TextAlign.center,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
