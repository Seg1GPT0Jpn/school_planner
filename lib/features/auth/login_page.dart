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
        // Android 版：Google のログイン画面をブラウザで開く
        await FirebaseAuth.instance.signInWithProvider(GoogleAuthProvider());
      }
    } on FirebaseAuthException catch (e) {
      // ログイン画面を自分で閉じた場合は、エラー扱いしない
      const closedCodes = {
        'popup-closed-by-user',
        'cancelled-popup-request',
        'web-context-canceled',
        'canceled',
      };
      if (!closedCodes.contains(e.code)) {
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
              Text('つづり', style: textTheme.headlineMedium),
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
