import 'package:flutter/material.dart';

import '../../app/theme.dart';
import '../../data/mock_data.dart';
import '../../domain/score_status.dart';
import '../../widgets/charts.dart';
import '../../widgets/components.dart';

class StressScreen extends StatelessWidget {
  const StressScreen({super.key});

  static const _activities = [
    ('Sleep', 12, AppColors.green),
    ('Workout', 65, AppColors.red),
    ('Work', 38, AppColors.yellow),
    ('Evening', 22, AppColors.green),
  ];

  @override
  Widget build(BuildContext context) {
    final scores = MockData.todayScores;
    final status = ScoreStatus.stress(scores.stress);
    final week = MockData.stressSeries.sublist(
      MockData.stressSeries.length - 7,
    );

    return Scaffold(
      appBar: AppBar(title: const Text('Stress')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
        children: [
          Row(
            children: [
              Text(
                '${scores.stress}',
                style: const TextStyle(
                  fontSize: 44,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -1,
                ),
              ),
              const SizedBox(width: 12),
              StatusPill(status.label, status.color),
            ],
          ),
          const SizedBox(height: 6),
          const Text(
            'Lower is calmer. Stress reflects physiological load, not emotions.',
            style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
          ),
          const SizedBox(height: 20),
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Today',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 14),
                StressDayChart(samples: MockData.stressToday),
              ],
            ),
          ),
          const SizedBox(height: 24),
          const SectionHeader('By activity'),
          AppCard(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
            child: Column(
              children: [
                for (final (label, value, color) in _activities)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 9),
                    child: Row(
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: color,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            label,
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        Text(
                          'avg $value',
                          style: TextStyle(fontSize: 13, color: color),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          const SectionHeader('Last 7 days'),
          AppCard(
            child: TrendBarChart(
              data: week,
              minY: 0,
              maxY: 100,
              colorFor: (index, value) {
                if (value <= 33) return AppColors.green;
                if (value <= 66) return AppColors.yellow;
                return AppColors.red;
              },
            ),
          ),
        ],
      ),
    );
  }
}
