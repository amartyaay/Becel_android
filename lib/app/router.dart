import 'package:go_router/go_router.dart';

import '../features/biology/biology_screen.dart';
import '../features/data/data_screen.dart';
import '../features/energy/energy_screen.dart';
import '../features/fitness/fitness_screen.dart';
import '../features/health/health_hub_screen.dart';
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
              path: '/health',
              builder: (context, state) => const HealthHubScreen(),
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/fitness',
              builder: (context, state) => const FitnessScreen(),
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
              path: '/data',
              builder: (context, state) => const DataScreen(),
            ),
          ],
        ),
      ],
    ),
    GoRoute(
      path: '/health/heart',
      builder: (context, state) => const HeartScreen(),
    ),
    GoRoute(
      path: '/health/sleep',
      builder: (context, state) => const SleepScreen(),
    ),
    GoRoute(
      path: '/health/recovery',
      builder: (context, state) => const RecoveryScreen(),
    ),
    GoRoute(
      path: '/health/strain',
      builder: (context, state) => const StrainScreen(),
    ),
    GoRoute(
      path: '/health/energy',
      builder: (context, state) => const EnergyScreen(),
    ),
    GoRoute(
      path: '/health/biology',
      builder: (context, state) => const BiologyScreen(),
    ),
    GoRoute(
      path: '/settings',
      builder: (context, state) => const SettingsScreen(),
    ),
  ],
);
