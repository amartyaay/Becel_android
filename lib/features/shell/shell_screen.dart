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
        // The system inset is applied once, here; the bar itself must not
        // add it again (NavigationBar pads for it by default).
        padding: EdgeInsets.fromLTRB(20, 0, 20, 10 + bottomInset),
        child: Container(
          height: 70,
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(35),
            boxShadow: const [
              BoxShadow(
                color: Color(0x1F1B2340),
                blurRadius: 30,
                offset: Offset(0, 10),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(35),
            child: NavigationBarTheme(
              data: NavigationBarThemeData(
                labelTextStyle: WidgetStateProperty.resolveWith(
                  (states) => TextStyle(
                    fontFamily: AppType.family,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: states.contains(WidgetState.selected)
                        ? AppColors.textPrimary
                        : AppColors.textTertiary,
                  ),
                ),
              ),
              child: MediaQuery.removePadding(
                context: context,
                removeBottom: true,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  child: NavigationBar(
                    height: 70,
                    backgroundColor: Colors.transparent,
                    surfaceTintColor: Colors.transparent,
                    indicatorColor: AppColors.ink,
                    indicatorShape: const StadiumBorder(),
                    labelBehavior:
                        NavigationDestinationLabelBehavior.alwaysHide,
                    selectedIndex: navigationShell.currentIndex,
                    onDestinationSelected: (index) => navigationShell.goBranch(
                      index,
                      initialLocation: index == navigationShell.currentIndex,
                    ),
                    destinations: [
                      for (final item in _items)
                        NavigationDestination(
                          icon: Icon(item.$1, color: AppColors.textTertiary),
                          selectedIcon: Icon(item.$2, color: Colors.white),
                          label: item.$3,
                        ),
                    ],
                  ),
                ),
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
const navClearance = 108.0;
