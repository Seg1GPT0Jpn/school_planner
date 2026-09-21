import 'package:flutter/foundation.dart' show Listenable;
import 'package:go_router/go_router.dart';

import '../features/auth/auth_state.dart';
import '../features/auth/login_page.dart';
import '../features/calendar/calendar_page.dart';
import '../features/goals/goals_page.dart';
import '../features/home/home_page.dart';
import '../features/onboarding/intro_page.dart';
import '../features/onboarding/onboarding_flow_page.dart';
import '../features/onboarding/onboarding_state.dart';
import '../features/timetable/timetable_page.dart';
import '../features/todo/todo_page.dart';
import 'app_shell.dart';

/// ログイン状態の見張り役
final AuthStateNotifier _authState = AuthStateNotifier();

/// 案内（オンボーディング）が終わっているかの見張り役
final OnboardingStateNotifier _onboardingState = OnboardingStateNotifier();

/// アプリ全体の画面遷移
///
/// ※ 変更したときは、r ではなく R（または起動し直し）が必要
final GoRouter appRouter = GoRouter(
  initialLocation: '/',
  refreshListenable: Listenable.merge([_authState, _onboardingState]),
  redirect: (context, state) {
    final isLoggedIn = _authState.isLoggedIn;
    final loc = state.matchedLocation;

    if (!isLoggedIn) {
      _onboardingState.bind(null);
      if (loc == '/login' || loc == '/intro') return null;
      return '/intro';
    }

    _onboardingState.bind(_authState.uid);

    // まだ案内の進み具合を読めていない間は、今の画面のままにしておく
    if (_onboardingState.isLoading) return null;

    if (!_onboardingState.isCompleted) {
      if (loc == '/onboarding') return null;
      return '/onboarding';
    }

    // 案内は終わっている → ログイン画面や案内の画面には行かせない
    if (loc == '/login' || loc == '/intro' || loc == '/onboarding') {
      return '/';
    }
    return null;
  },
  routes: [
    GoRoute(path: '/intro', builder: (context, state) => const IntroPage()),
    GoRoute(path: '/login', builder: (context, state) => const LoginPage()),
    GoRoute(
      path: '/onboarding',
      builder: (context, state) => const OnboardingFlowPage(),
    ),

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
