import 'package:flutter/material.dart';

import '../../app/theme.dart';
import '../../data/mock_data.dart';
import '../../domain/score_status.dart';
import '../../widgets/charts.dart';
import '../../widgets/components.dart';
import '../../widgets/visuals.dart';

class StrainScreen extends StatelessWidget {
  const StrainScreen({super.key});

  static const _zoneColors = [
    AppColors.green,
    Color(0xFF3EDCC4),
    AppColors.yellow,
    Color(0xFFFF9F45),
    AppColors.red,
  ];

  @override
  Widget build(BuildContext context) {
    final scores = MockData.todayScores;
    final status = ScoreStatus.strain(
      scores.strain,
      scores.strainLow,
      scores.strainHigh,
    );
    final activeStrain = MockData.workouts.fold<double>(
      0,
      (sum, workout) => sum + workout.strain,
    );
    final passiveStrain = (scores.strain - activeStrain).clamp(0, 100);

    return Scaffold(
      appBar: AppBar(title: const Text('Strain')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
        children: [
          Center(
            child: Column(
              children: [
                ScoreRing(
                  value: scores.strain / 100,
                  color: AppColors.strain,
                  size: 176,
                  stroke: 12,
                  center: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '${scores.strain}%',
                        style: const TextStyle(
                          fontSize: 40,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -1,
                        ),
                      ),
                      const Text(
                        'Strain',
                        style: TextStyle(
                          fontSize: 13,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                StatusPill(status.label, status.color),
                const SizedBox(height: 10),
                Text(
                  'Target strain ${scores.strainLow}–${scores.strainHigh}%',
                  style: const TextStyle(
                    fontSize: 14,
                    color: AppColors.textSecondary,
                    fontFeatures: [FontFeature.tabularFigures()],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 28),
          const SectionHeader('Today'),
          Row(
            children: [
              Expanded(
                child: AppCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Active',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        activeStrain.toStringAsFixed(1),
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.5,
                        ),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'From 3 workouts',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.textTertiary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: AppCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Passive',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        passiveStrain.toStringAsFixed(1),
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.5,
                        ),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'Daily movement',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.textTertiary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          const SectionHeader('30-day strain'),
          AppCard(
            child: TrendBarChart(
              data: MockData.strainSeries,
              minY: 0,
              maxY: 100,
              colorFor: (index, value) {
                if (value < scores.strainLow) return AppColors.sleep;
                if (value <= scores.strainHigh) return AppColors.green;
                return AppColors.strain;
              },
            ),
          ),
          const SizedBox(height: 24),
          const SectionHeader('Heart rate zones'),
          AppCard(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
            child: Column(
              children: [
                for (var i = 0; i < MockData.heartRateZones.length; i++)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 7),
                    child: Row(
                      children: [
                        SizedBox(
                          width: 28,
                          child: Text(
                            'Z${MockData.heartRateZones[i][0]}',
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ),
                        Expanded(
                          child: ProgressBar(
                            value: MockData.heartRateZones[i][1] / 60,
                            color: _zoneColors[i],
                          ),
                        ),
                        const SizedBox(width: 12),
                        SizedBox(
                          width: 42,
                          child: Text(
                            '${MockData.heartRateZones[i][1]}m',
                            textAlign: TextAlign.right,
                            style: const TextStyle(
                              fontSize: 13,
                              fontFeatures: [FontFeature.tabularFigures()],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          const SectionHeader('Workouts'),
          for (final workout in MockData.workouts) ...[
            AppCard(
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: AppColors.strain.withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.directions_run,
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
                            'Avg ${workout.avgHr} bpm',
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
                    workout.strain.toStringAsFixed(1),
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
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
    );
  }
}
