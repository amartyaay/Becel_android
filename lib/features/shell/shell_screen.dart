import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../app/theme.dart';
import '../../widgets/components.dart';

class ShellScreen extends StatelessWidget {
  const ShellScreen({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: navigationShell,
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showQuickActions(context),
        backgroundColor: AppColors.textPrimary,
        foregroundColor: AppColors.bg,
        shape: const CircleBorder(),
        child: const Icon(Icons.add, size: 28),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: navigationShell.currentIndex,
        onDestinationSelected: (index) => navigationShell.goBranch(
          index,
          initialLocation: index == navigationShell.currentIndex,
        ),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.donut_large_outlined),
            selectedIcon: Icon(Icons.donut_large),
            label: 'Today',
          ),
          NavigationDestination(
            icon: Icon(Icons.fitness_center_outlined),
            selectedIcon: Icon(Icons.fitness_center),
            label: 'Fitness',
          ),
          NavigationDestination(
            icon: Icon(Icons.restaurant_outlined),
            selectedIcon: Icon(Icons.restaurant),
            label: 'Nutrition',
          ),
          NavigationDestination(
            icon: Icon(Icons.monitor_heart_outlined),
            selectedIcon: Icon(Icons.monitor_heart),
            label: 'Biology',
          ),
        ],
      ),
    );
  }

  void _showQuickActions(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(24, 4, 24, 12),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Quick log',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
                ),
              ),
            ),
            _QuickAction(
              icon: Icons.water_drop_outlined,
              label: 'Log water',
              onTap: () => _soon(sheetContext, 'Water logging'),
            ),
            _QuickAction(
              icon: Icons.coffee_outlined,
              label: 'Log caffeine',
              onTap: () => _soon(sheetContext, 'Caffeine logging'),
            ),
            _QuickAction(
              icon: Icons.restaurant_outlined,
              label: 'Log food',
              onTap: () => _soon(sheetContext, 'Food logging'),
            ),
            _QuickAction(
              icon: Icons.directions_run_outlined,
              label: 'Start workout',
              onTap: () => _soon(sheetContext, 'Workout tracking'),
            ),
            _QuickAction(
              icon: Icons.book_outlined,
              label: 'Journal entry',
              onTap: () => _soon(sheetContext, 'Journal'),
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }

  void _soon(BuildContext sheetContext, String feature) {
    Navigator.of(sheetContext).pop();
    final context = sheetContext;
    showSoonSnack(context, feature);
  }
}

class _QuickAction extends StatelessWidget {
  const _QuickAction({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Container(
        width: 38,
        height: 38,
        decoration: BoxDecoration(
          color: AppColors.surfaceHigher,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(icon, size: 20),
      ),
      title: Text(label, style: const TextStyle(fontSize: 15)),
      onTap: onTap,
    );
  }
}
