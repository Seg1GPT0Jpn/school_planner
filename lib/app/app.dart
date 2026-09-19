import 'package:material_ui/material_ui.dart';

import 'router.dart';

/// アプリ全体の設定
class App extends StatelessWidget {
  const App({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'わたしの手帳',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.brown),
      ),
      routerConfig: appRouter,
      // 古い書き方の部品（今後追加するライブラリなど）とも
      // デザイン設定を共有するための橋渡し（Flutter 公式の推奨）
      builder: (context, child) {
        return MaterialUiCompatibilityBridge(child: child!);
      },
    );
  }
}
