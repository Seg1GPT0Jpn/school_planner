import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../features/auth/auth_state.dart';
import '../features/auth/login_page.dart';
import '../features/calendar/calendar_page.dart';
import '../features/home/home_page.dart';
import '../features/todo/todo_page.dart';
import '../features/timetable/timetable_page.dart';
import '../widgets/placeholder_page.dart';
import 'app_shell.dart';

/// ログイン状態の見張り役
final AuthStateNotifier _authState = AuthStateNotifier();

/// アプリ全体の画面遷移（ルーティング）の設定
///
/// ※ この設定はアプリ起動時に1回だけ作られる。
///    変更したときは、ホットリロード（r）ではなく
///    ホットリスタート（R）か、起動し直しが必要。
final GoRouter appRouter = GoRouter(
  initialLocation: '/',

  // ログイン状態が変わったら、下の redirect をもう一度確認する
  refreshListenable: _authState,

  // 画面を開くたびに「今いてよい画面か」を確認する
  redirect: (context, state) {
    final isLoggedIn = _authState.isLoggedIn;
    final isOnLoginPage = state.matchedLocation == '/login';

    if (!isLoggedIn && !isOnLoginPage) return '/login';
    if (isLoggedIn && isOnLoginPage) return '/';
    return null;
  },

  routes: [
    // ログイン画面（タブの外）
    GoRoute(path: '/login', builder: (context, state) => const LoginPage()),

    // タブのある画面たち
    StatefulShellRoute.indexedStack(
      builder: (context, state, navigationShell) {
        return AppShell(navigationShell: navigationShell);
      },
      // ※ app_shell.dart の _tabs と同じ順番にすること
      branches: [
        StatefulShellBranch(
          routes: [
            GoRoute(path: '/', builder: (context, state) => const HomePage()),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/calendar',
              builder: (context, state) => const CalendarPage(),
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/timetable',
              builder: (context, state) => const TimetablePage(),
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/todo',
              builder: (context, state) => const TodoPage(),
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
