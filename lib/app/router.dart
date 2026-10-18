import 'package:go_router/go_router.dart';

import '../features/biology/biology_screen.dart';
import '../features/energy/energy_screen.dart';
import '../features/fitness/fitness_screen.dart';
import '../features/nutrition/nutrition_screen.dart';
import '../features/recovery/recovery_screen.dart';
import '../features/settings/settings_screen.dart';
import '../features/shell/shell_screen.dart';
import '../features/sleep/sleep_screen.dart';
import '../features/strain/strain_screen.dart';
import '../features/stress/stress_screen.dart';
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
                  path: '/fitness',
                  builder: (context, state) => const FitnessScreen(),
                ),
              ],
            ),
            StatefulShellBranch(
              routes: [
                GoRoute(
                  path: '/nutrition',
                  builder: (context, state) => const NutritionScreen(),
                ),
              ],
            ),
            StatefulShellBranch(
              routes: [
                GoRoute(
                  path: '/biology',
                  builder: (context, state) => const BiologyScreen(),
                ),
              ],
            ),
          ],
        ),
        GoRoute(
          path: '/recovery',
          builder: (context, state) => const RecoveryScreen(),
        ),
        GoRoute(
          path: '/sleep',
          builder: (context, state) => const SleepScreen(),
        ),
        GoRoute(
          path: '/strain',
          builder: (context, state) => const StrainScreen(),
        ),
        GoRoute(
          path: '/stress',
          builder: (context, state) => const StressScreen(),
        ),
        GoRoute(
          path: '/energy',
          builder: (context, state) => const EnergyScreen(),
        ),
        GoRoute(
          path: '/settings',
          builder: (context, state) => const SettingsScreen(),
        ),
      ],
    );
