import 'package:flutter/material.dart';

import '../../app/theme.dart';
import '../../data/mock_data.dart';
import '../../domain/score_status.dart';
import '../../widgets/charts.dart';
import '../../widgets/components.dart';
import '../../widgets/visuals.dart';

class EnergyScreen extends StatelessWidget {
  const EnergyScreen({super.key});

  static const _balance = [
    ('Sleep', 34, true, AppColors.sleep),
    ('Rest & calm', 12, true, AppColors.green),
    ('Training', 18, false, AppColors.strain),
    ('Stress load', 9, false, AppColors.stress),
  ];

  @override
  Widget build(BuildContext context) {
    final scores = MockData.todayScores;
    final status = ScoreStatus.energy(scores.energyBank);
    final week = MockData.energySeries.sublist(
      MockData.energySeries.length - 7,
    );

    return Scaffold(
      appBar: AppBar(title: const Text('Energy Bank')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${scores.energyBank}%',
                style: const TextStyle(
                  fontSize: 44,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -1,
                ),
              ),
              const SizedBox(width: 12),
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: StatusPill(status.label, status.color),
              ),
            ],
          ),
          const SizedBox(height: 6),
          const Text(
            '+8 since this morning · carries over day to day',
            style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
          ),
          const SizedBox(height: 20),
          AppCard(
            child: BatteryGauge(
              value: scores.energyBank / 100,
              color: AppColors.energy,
              height: 72,
            ),
          ),
          const SizedBox(height: 24),
          const SectionHeader("Today's balance"),
          AppCard(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
            child: Column(
              children: [
                for (final (label, amount, positive, color) in _balance)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 9),
                    child: Row(
                      children: [
                        Container(
                          width: 30,
                          height: 30,
                          decoration: BoxDecoration(
                            color: color.withValues(alpha: 0.14),
                            borderRadius: BorderRadius.circular(9),
                          ),
                          child: Icon(
                            positive
                                ? Icons.add_circle_outline
                                : Icons.remove_circle_outline,
                            size: 16,
                            color: color,
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
                          '${positive ? '+' : '-'}$amount',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: positive ? AppColors.green : AppColors.red,
                            fontFeatures: const [FontFeature.tabularFigures()],
                          ),
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
            child: TrendLineChart(
              data: week,
              color: AppColors.energy,
              minY: 0,
              maxY: 100,
            ),
          ),
        ],
      ),
    );
  }
}
