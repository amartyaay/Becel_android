import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../app/theme.dart';

class ShellScreen extends StatelessWidget {
  const ShellScreen({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  static const items = [
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
        // The system inset is applied exactly once, here.
        padding: EdgeInsets.fromLTRB(20, 0, 20, 10 + bottomInset),
        child: BecelNavBar(
          selected: navigationShell.currentIndex,
          onSelect: (index) => navigationShell.goBranch(
            index,
            initialLocation: index == navigationShell.currentIndex,
          ),
        ),
      ),
    );
  }
}

/// Floating pill navigation: the selected tab grows into an ink pill with
/// its label; the others are icons only. Fully custom so its layout never
/// depends on Material's NavigationBar padding rules.
class BecelNavBar extends StatelessWidget {
  const BecelNavBar({
    super.key,
    required this.selected,
    required this.onSelect,
  });

  final int selected;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 68,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(34),
        boxShadow: const [
          BoxShadow(
            color: Color(0x1F1B2340),
            blurRadius: 30,
            offset: Offset(0, 10),
          ),
        ],
      ),
      // The selected pill takes its natural width so its label is never
      // clipped; icon-only tabs share what is left. Label scaling is capped
      // so very large text settings cannot squeeze the icons out.
      child: MediaQuery.withClampedTextScaling(
        maxScaleFactor: 1.2,
        child: Row(
          children: [
            for (var i = 0; i < ShellScreen.items.length; i++)
              if (i == selected)
                _NavItem(
                  icon: ShellScreen.items[i].$1,
                  selectedIcon: ShellScreen.items[i].$2,
                  label: ShellScreen.items[i].$3,
                  selected: true,
                  onTap: () => onSelect(i),
                )
              else
                Expanded(
                  child: _NavItem(
                    icon: ShellScreen.items[i].$1,
                    selectedIcon: ShellScreen.items[i].$2,
                    label: ShellScreen.items[i].$3,
                    selected: false,
                    onTap: () => onSelect(i),
                  ),
                ),
          ],
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.icon,
    required this.selectedIcon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final IconData selectedIcon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: label,
      excludeFromSemantics: true,
      child: Semantics(
        button: true,
        selected: selected,
        label: label,
        child: InkResponse(
          onTap: onTap,
          radius: 32,
          child: Center(
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 260),
              curve: Curves.easeOutCubic,
              height: 48,
              padding: EdgeInsets.symmetric(horizontal: selected ? 14 : 0),
              decoration: BoxDecoration(
                color: selected ? AppColors.ink : Colors.transparent,
                borderRadius: BorderRadius.circular(24),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    selected ? selectedIcon : icon,
                    size: 22,
                    color: selected ? Colors.white : AppColors.textTertiary,
                  ),
                  if (selected) ...[
                    const SizedBox(width: 8),
                    Text(
                      label,
                      maxLines: 1,
                      softWrap: false,
                      style: const TextStyle(
                        fontFamily: AppType.family,
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                  ],
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
const navClearance = 108.0;
