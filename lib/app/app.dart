import 'package:material_ui/material_ui.dart';

import '../features/notifications/notification_sync.dart';
import '../features/timetable/subject_colors.dart';
import 'router.dart';
import 'theme.dart';

/// アプリ全体の設定
class App extends StatelessWidget {
  const App({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'つづり',
      debugShowCheckedModeBanner: false,

      // 手帳風の見た目（スマホの設定に合わせてライト／ダーク）
      theme: buildLightTheme(),
      darkTheme: buildDarkTheme(),
      themeMode: ThemeMode.system,

      routerConfig: appRouter,

      // 日付・時刻の選択画面などを日本語で表示する
      locale: const Locale('ja'),
      supportedLocales: const [Locale('ja')],
      localizationsDelegates: GlobalMaterialLocalizations.delegates,

      // すべての画面の外側に「教科の色」と「通知」の係を置く
      builder: (context, child) {
        return SubjectColorProvider(child: NotificationSync(child: child!));
      },
    );
  }
}
