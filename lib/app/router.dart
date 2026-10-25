import 'package:go_router/go_router.dart';

import '../features/activity/activity_screen.dart';
import '../features/biology/biology_screen.dart';
import '../features/data/data_screen.dart';
import '../features/energy/energy_screen.dart';
import '../features/health/heart_screen.dart';
import '../features/history/history_screen.dart';
import '../features/recovery/recovery_screen.dart';
import '../features/settings/settings_screen.dart';
import '../features/shell/shell_screen.dart';
import '../features/sleep/sleep_screen.dart';
import '../features/strain/strain_screen.dart';
import '../features/today/today_screen.dart';

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
              path: '/activity',
              builder: (context, state) => const ActivityScreen(),
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
    GoRoute(path: '/heart', builder: (context, state) => const HeartScreen()),
    GoRoute(path: '/zones', builder: (context, state) => const StrainScreen()),
    GoRoute(path: '/strain', redirect: (context, state) => '/zones'),
    GoRoute(path: '/energy', builder: (context, state) => const EnergyScreen()),
    GoRoute(
      path: '/biology',
      builder: (context, state) => const BiologyScreen(),
    ),
    GoRoute(path: '/data', builder: (context, state) => const DataScreen()),
  ],
);
