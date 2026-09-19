import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../widgets/placeholder_page.dart';
import 'app_shell.dart';

/// アプリ全体の画面遷移（ルーティング）の設定
final GoRouter appRouter = GoRouter(
  initialLocation: '/',
  routes: [
    StatefulShellRoute.indexedStack(
      builder: (context, state, navigationShell) {
        return AppShell(navigationShell: navigationShell);
      },
      // ※ app_shell.dart の _tabs と同じ順番にすること
      branches: [
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/',
              builder: (context, state) =>
                  const PlaceholderPage(title: 'ホーム', icon: Icons.home),
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/calendar',
              builder: (context, state) => const PlaceholderPage(
                title: 'カレンダー',
                icon: Icons.calendar_month,
              ),
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/timetable',
              builder: (context, state) =>
                  const PlaceholderPage(title: '時間割', icon: Icons.table_chart),
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/todo',
              builder: (context, state) => const PlaceholderPage(
                title: 'ToDo',
                icon: Icons.check_circle,
              ),
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/goals',
              builder: (context, state) =>
                  const PlaceholderPage(title: '目標', icon: Icons.flag),
            ),
          ],
        ),
      ],
    ),
  ],
);
