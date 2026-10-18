import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../app/theme.dart';
import '../../widgets/kit.dart';

class HistoryScreen extends StatelessWidget {
  const HistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 34),
          children: [
            const ScreenHeader(eyebrow: 'ZOOM OUT', title: 'Trends'),
            const SizedBox(height: 22),
            SurfaceCard(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const _GhostBars(),
                  const SizedBox(height: 18),
                  const IconChip(
                    icon: Icons.query_stats_rounded,
                    color: AppColors.teal,
                    size: 44,
                    iconSize: 22,
                  ),
                  const SizedBox(height: 14),
                  const Text(
                    'No Fitbit Air-matched history yet',
                    style: TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.3,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Trend values will appear only after Becel receives records written for your Fitbit Air by the Fitbit app or Google Health. Other devices and sample values are hidden.',
                    style: AppType.note,
                  ),
                  const SizedBox(height: 18),
                  OutlinedButton.icon(
                    onPressed: () => context.go('/data'),
                    icon: const Icon(Icons.tune_rounded, size: 17),
                    label: const Text('Review data access'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 26),
            const SectionHeader(title: 'What will appear here'),
            const SizedBox(height: 12),
            const Row(
              children: [
                Expanded(
                  child: _MetricPreview(
                    icon: Icons.directions_walk_rounded,
                    color: AppColors.green,
                    label: 'Steps',
                  ),
                ),
                SizedBox(width: 10),
                Expanded(
                  child: _MetricPreview(
                    icon: Icons.favorite_rounded,
                    color: AppColors.red,
                    label: 'Heart rate',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            const Row(
              children: [
                Expanded(
                  child: _MetricPreview(
                    icon: Icons.nightlight_round,
                    color: AppColors.blue,
                    label: 'Sleep',
                  ),
                ),
                SizedBox(width: 10),
                Expanded(
                  child: _MetricPreview(
                    icon: Icons.directions_run_rounded,
                    color: AppColors.violet,
                    label: 'Workouts',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            const TrustFooter(
              text: 'SOURCE AND FRESHNESS SHOWN FOR EVERY VALUE',
            ),
          ],
        ),
      ),
    );
  }
}

class _GhostBars extends StatelessWidget {
  const _GhostBars();

  static const _heights = <double>[26, 46, 34, 60, 42, 68, 50];
  static const _colors = <Color>[
    Color(0x24D0F477),
    Color(0x1F79D6C1),
    Color(0x1AD0F477),
    Color(0x1FB9A4FF),
    Color(0x1A8EA9FF),
    Color(0x24D0F477),
    Color(0x1A79D6C1),
  ];

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 68,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          for (var index = 0; index < _heights.length; index++) ...[
            if (index > 0) const SizedBox(width: 7),
            Expanded(
              child: Container(
                height: _heights[index],
                decoration: BoxDecoration(
                  color: _colors[index],
                  borderRadius: BorderRadius.circular(6),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _MetricPreview extends StatelessWidget {
  const _MetricPreview({
    required this.icon,
    required this.color,
    required this.label,
  });

  final IconData icon;
  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return SurfaceCard(
      padding: const EdgeInsets.all(13),
      child: Row(
        children: [
          IconChip(icon: icon, color: color, size: 34, iconSize: 17),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 13.5,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.1,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
