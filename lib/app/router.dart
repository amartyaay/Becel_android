import 'package:go_router/go_router.dart';

import '../features/data/data_screen.dart';
import '../features/energy/energy_screen.dart';
import '../features/health/vitals_screen.dart';
import '../features/history/history_screen.dart';
import '../features/recovery/recovery_screen.dart';
import '../features/settings/settings_screen.dart';
import '../features/shell/shell_screen.dart';
import '../features/sleep/sleep_screen.dart';
import '../features/today/today_screen.dart';
import '../features/training/strength_screen.dart';
import '../features/training/training_screen.dart';

GoRouter buildRouter() => GoRouter(
  initialLocation: '/today',
  routes: [
    StatefulShellRoute.indexedStack(
      builder: (context, state, navigationShell) =>
          ShellScreen(navigationShell: navigationShell),
      branches: [
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/today',
              builder: (context, state) => const TodayScreen(),
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/training',
              builder: (context, state) => const TrainingScreen(),
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/sleep',
              builder: (context, state) => const SleepScreen(),
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/history',
              builder: (context, state) => const HistoryScreen(),
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/settings',
              builder: (context, state) => const SettingsScreen(),
            ),
          ],
        ),
      ],
    ),
    GoRoute(
      path: '/recovery',
      builder: (context, state) => const RecoveryScreen(),
    ),
    GoRoute(path: '/energy', builder: (context, state) => const EnergyScreen()),
    GoRoute(
      path: '/strength',
      builder: (context, state) => const StrengthScreen(),
    ),
    GoRoute(path: '/vitals', builder: (context, state) => const VitalsScreen()),
    GoRoute(path: '/data', builder: (context, state) => const DataScreen()),
    // Older links.
    GoRoute(path: '/activity', redirect: (context, state) => '/training'),
    GoRoute(path: '/strain', redirect: (context, state) => '/training'),
    GoRoute(path: '/heart', redirect: (context, state) => '/vitals'),
    GoRoute(path: '/zones', redirect: (context, state) => '/vitals'),
    GoRoute(path: '/biology', redirect: (context, state) => '/vitals'),
  ],
);
