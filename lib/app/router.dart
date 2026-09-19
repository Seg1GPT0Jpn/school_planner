import 'package:go_router/go_router.dart';

import '../features/auth/auth_state.dart';
import '../features/auth/login_page.dart';
import '../features/calendar/calendar_page.dart';
import '../features/goals/goals_page.dart';
import '../features/home/home_page.dart';
import '../features/timetable/timetable_page.dart';
import '../features/todo/todo_page.dart';
import 'app_shell.dart';

/// ログイン状態の見張り役
final AuthStateNotifier _authState = AuthStateNotifier();

/// アプリ全体の画面遷移
///
/// ※ 変更したときは、r ではなく R（または起動し直し）が必要
final GoRouter appRouter = GoRouter(
  initialLocation: '/',
  refreshListenable: _authState,
  redirect: (context, state) {
    final isLoggedIn = _authState.isLoggedIn;
    final isOnLoginPage = state.matchedLocation == '/login';
    if (!isLoggedIn && !isOnLoginPage) return '/login';
    if (isLoggedIn && isOnLoginPage) return '/';
    return null;
  },
  routes: [
    GoRoute(path: '/login', builder: (context, state) => const LoginPage()),

    // タブのある画面（app_shell.dart の _tabs と同じ順番）
    StatefulShellRoute.indexedStack(
      builder: (context, state, navigationShell) =>
          AppShell(navigationShell: navigationShell),
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
              builder: (context, state) => const GoalsPage(),
            ),
          ],
        ),
      ],
    ),
  ],
);
