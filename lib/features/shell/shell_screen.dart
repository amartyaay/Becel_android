import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../app/theme.dart';

class ShellScreen extends StatelessWidget {
  const ShellScreen({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  static const _items = [
    (Icons.donut_large_outlined, Icons.donut_large_rounded, 'Today'),
    (Icons.bolt_outlined, Icons.bolt_rounded, 'Training'),
    (Icons.bedtime_outlined, Icons.bedtime_rounded, 'Sleep'),
    (Icons.insights_outlined, Icons.insights_rounded, 'Trends'),
    (Icons.tune_outlined, Icons.tune_rounded, 'Settings'),
  ];

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.paddingOf(context).bottom;
    return Scaffold(
      extendBody: true,
      body: navigationShell,
      bottomNavigationBar: Padding(
        padding: EdgeInsets.fromLTRB(16, 0, 16, 12 + bottomInset * 0.4),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(28),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
            child: Container(
              height: 68,
              decoration: BoxDecoration(
                color: AppColors.surfaceHigh.withValues(alpha: 0.82),
                borderRadius: BorderRadius.circular(28),
                border: Border.all(color: AppColors.hairline),
              ),
              child: NavigationBar(
                height: 68,
                backgroundColor: Colors.transparent,
                surfaceTintColor: Colors.transparent,
                indicatorColor: AppColors.accent.withValues(alpha: 0.16),
                indicatorShape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                labelBehavior:
                    NavigationDestinationLabelBehavior.onlyShowSelected,
                selectedIndex: navigationShell.currentIndex,
                onDestinationSelected: (index) => navigationShell.goBranch(
                  index,
                  initialLocation: index == navigationShell.currentIndex,
                ),
                destinations: [
                  for (final item in _items)
                    NavigationDestination(
                      icon: Icon(item.$1, color: AppColors.textTertiary),
                      selectedIcon: Icon(item.$2, color: AppColors.accent),
                      label: item.$3,
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

void openSettings(BuildContext context) => context.go('/settings');

/// Bottom padding every tab's scroll view needs to clear the floating bar.
const navClearance = 104.0;
