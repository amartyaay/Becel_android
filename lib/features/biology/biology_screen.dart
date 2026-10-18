import 'package:flutter/material.dart';

import '../../app/theme.dart';
import '../../data/mock_data.dart';
import '../../domain/models.dart';
import '../../widgets/components.dart';
import '../../widgets/visuals.dart';

class BiologyScreen extends StatelessWidget {
  const BiologyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 140),
          children: [
            const Text(
              'Biology',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(height: 18),
            GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: 1.9,
              children: [
                for (final monitor in MockData.monitors)
                  _MonitorCard(monitor: monitor),
              ],
            ),
            const SizedBox(height: 24),
            const SectionHeader('Fitness markers'),
            AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: const [
                      Text(
                        'VO₂ max',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Spacer(),
                      Text(
                        '46.2',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          fontFeatures: [FontFeature.tabularFigures()],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Above average for your age · ml/kg/min',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 12),
                  SparkLine(
                    data: const [
                      42.0,
                      42.4,
                      43.1,
                      43.4,
                      44.0,
                      44.2,
                      44.8,
                      45.1,
                      45.4,
                      45.8,
                      46.0,
                      46.2,
                    ],
                    color: AppColors.strain,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            AppCard(
              onTap: () => showSoonSnack(context, 'Weight logging'),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: const [
                      Text(
                        'Weight',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Spacer(),
                      Text(
                        '74.6 kg',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          fontFeatures: [FontFeature.tabularFigures()],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    '-0.4 kg this month · trend',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 12),
                  SparkLine(
                    data: const [
                      75.6,
                      75.5,
                      75.3,
                      75.4,
                      75.2,
                      75.1,
                      75.0,
                      74.9,
                      74.8,
                      74.8,
                      74.7,
                      74.6,
                    ],
                    color: AppColors.sleep,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            AppCard(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 6),
              child: Column(
                children: const [
                  InfoRow(
                    title: 'Body fat',
                    value: '18.4%',
                    icon: Icons.percent,
                    iconColor: AppColors.yellow,
                  ),
                  InfoRow(
                    title: 'Lean body mass',
                    value: '60.9 kg',
                    icon: Icons.fitness_center,
                    iconColor: AppColors.green,
                  ),
                  InfoRow(
                    title: 'Body mass index',
                    value: '23.1',
                    icon: Icons.straighten,
                    iconColor: AppColors.sleep,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            const SectionHeader('Longevity'),
            AppCard(
              onTap: () => showSoonSnack(context, 'Biological age'),
              child: Row(
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: const [
                      Text(
                        'Biological age',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      SizedBox(height: 6),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.baseline,
                        textBaseline: TextBaseline.alphabetic,
                        children: [
                          Text(
                            '29',
                            style: TextStyle(
                              fontSize: 30,
                              fontWeight: FontWeight.w800,
                              letterSpacing: -0.5,
                            ),
                          ),
                          SizedBox(width: 6),
                          Text(
                            'yrs',
                            style: TextStyle(
                              fontSize: 13,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 4),
                      Text(
                        '3 years younger than your age',
                        style: TextStyle(fontSize: 12, color: AppColors.green),
                      ),
                    ],
                  ),
                  const Spacer(),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      const StatusPill('Pro', AppColors.yellow),
                      const SizedBox(height: 8),
                      const Text(
                        'Confidence: high',
                        style: TextStyle(
                          fontSize: 11,
                          color: AppColors.textTertiary,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            AppCard(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 6),
              child: Column(
                children: [
                  InfoRow(
                    title: 'Health records',
                    subtitle: 'Labs, bloodwork and clinical notes',
                    icon: Icons.folder_outlined,
                    iconColor: AppColors.sleep,
                    value: '',
                    trailing: const Icon(
                      Icons.chevron_right,
                      size: 18,
                      color: AppColors.textTertiary,
                    ),
                    onTap: () => showSoonSnack(context, 'Health records'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MonitorCard extends StatelessWidget {
  const _MonitorCard({required this.monitor});

  final MonitorReading monitor;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.all(14),
      onTap: () => showSoonSnack(context, monitor.label),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            monitor.label,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: AppColors.textTertiary,
            ),
          ),
          const SizedBox(height: 4),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Flexible(
                child: Text(
                  monitor.value,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.3,
                    fontFeatures: [FontFeature.tabularFigures()],
                  ),
                ),
              ),
              if (monitor.unit.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(left: 3),
                  child: Text(
                    monitor.unit,
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
              if (monitor.delta.isNotEmpty) ...[
                const Spacer(),
                Text(
                  monitor.delta,
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppColors.textTertiary,
                    fontFeatures: [FontFeature.tabularFigures()],
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}
