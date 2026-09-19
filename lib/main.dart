import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

import 'firebase_options.dart';

Future<void> main() async {
  // Flutter の準備が整うのを待つ
  WidgetsFlutterBinding.ensureInitialized();

  // Firebase に接続する（接続が終わるまで待つ）
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'わたしの手帳',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.brown),
      ),
      home: const ConnectionCheckPage(),
    );
  }
}

/// Firebase に接続できたかを確認するための仮の画面
class ConnectionCheckPage extends StatelessWidget {
  const ConnectionCheckPage({super.key});

  @override
  Widget build(BuildContext context) {
    // 接続した Firebase プロジェクトの ID を取得
    final projectId = Firebase.app().options.projectId;

    return Scaffold(
      appBar: AppBar(title: const Text('わたしの手帳')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.cloud_done, size: 64, color: Colors.green),
            const SizedBox(height: 16),
            const Text('Firebase 接続OK', style: TextStyle(fontSize: 24)),
            const SizedBox(height: 8),
            Text('プロジェクト: $projectId'),
          ],
        ),
      ),
    );
  }
}
