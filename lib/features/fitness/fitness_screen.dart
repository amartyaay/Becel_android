import 'package:flutter/material.dart';

import '../../app/theme.dart';
import '../../data/mock_data.dart';
import '../../widgets/charts.dart';
import '../../widgets/components.dart';

class FitnessScreen extends StatelessWidget {
  const FitnessScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 140),
          children: [
            const Text(
              'Fitness',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(height: 18),
            AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Text(
                        'Cardio Load',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Spacer(),
                      StatusPill('Productive', AppColors.green),
                    ],
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Short-term load is inside your optimal range.',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 16),
                  TrendLineChart(
                    data: MockData.cardioLoad30,
                    color: AppColors.strain,
                    bandLow: 34,
                    bandHigh: 52,
                    bandColor: AppColors.green,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: const [
                Expanded(
                  child: _StatCard(label: 'VO₂ max', value: '46.2'),
                ),
                SizedBox(width: 12),
                Expanded(
                  child: _StatCard(label: 'HR recovery', value: '32 bpm'),
                ),
                SizedBox(width: 12),
                Expanded(
                  child: _StatCard(label: 'This week', value: '3'),
                ),
              ],
            ),
            const SizedBox(height: 24),
            const SectionHeader('This week'),
            AppCard(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 6),
              child: Column(
                children: const [
                  InfoRow(
                    title: 'Total strain',
                    value: '142',
                    icon: Icons.local_fire_department_outlined,
                    iconColor: AppColors.strain,
                  ),
                  InfoRow(
                    title: 'Workout time',
                    value: '1h 42m',
                    icon: Icons.timer_outlined,
                    iconColor: AppColors.sleep,
                  ),
                  InfoRow(
                    title: 'Calories',
                    value: '698 kcal',
                    icon: Icons.bolt_outlined,
                    iconColor: AppColors.yellow,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            const SectionHeader('Recent workouts'),
            for (final workout in MockData.workouts) ...[
              AppCard(
                onTap: () => showSoonSnack(context, 'Workout details'),
                child: Row(
                  children: [
                    Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        color: AppColors.strain.withValues(alpha: 0.14),
                        borderRadius: BorderRadius.circular(13),
                      ),
                      child: Icon(
                        workout.kind == 'Strength'
                            ? Icons.fitness_center
                            : Icons.directions_run,
                        size: 20,
                        color: AppColors.strain,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            workout.title,
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            [
                              if (workout.distanceKm != null)
                                '${workout.distanceKm} km',
                              '${workout.durationMin}m',
                              '${workout.calories} kcal',
                            ].join(' · '),
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Text(
                      'Strain ${workout.strain.toStringAsFixed(1)}',
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppColors.strain,
                        fontFeatures: [FontFeature.tabularFigures()],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
            ],
          ],
        ),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: AppColors.textTertiary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              fontFeatures: [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );
  }
}
