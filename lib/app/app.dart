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

      // 日付・時刻の選択画面などを日本語で表示する
      locale: const Locale('ja'),
      supportedLocales: const [Locale('ja')],
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
    );
  }
}
