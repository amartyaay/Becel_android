import 'package:flutter/material.dart';

import '../../app/theme.dart';
import '../../data/mock_data.dart';
import '../../domain/score_status.dart';
import '../../widgets/charts.dart';
import '../../widgets/components.dart';
import '../../widgets/visuals.dart';

class RecoveryScreen extends StatelessWidget {
  const RecoveryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final scores = MockData.todayScores;
    final status = ScoreStatus.recovery(scores.recovery);

    return Scaffold(
      appBar: AppBar(title: const Text('Recovery')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
        children: [
          Center(
            child: Column(
              children: [
                ScoreRing(
                  value: scores.recovery / 100,
                  color: AppColors.recovery,
                  size: 176,
                  stroke: 12,
                  center: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '${scores.recovery}%',
                        style: const TextStyle(
                          fontSize: 40,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -1,
                        ),
                      ),
                      const Text(
                        'Recovery',
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
                const Text(
                  'Your body is ready to take on strain today.',
                  style: TextStyle(
                    fontSize: 14,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 28),
          const SectionHeader('Contributors'),
          AppCard(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 6),
            child: Column(
              children: const [
                _Contributor(
                  label: 'Sleep',
                  status: 'Good',
                  color: AppColors.green,
                  value: '88',
                ),
                _Contributor(
                  label: 'HRV',
                  status: 'Above baseline',
                  color: AppColors.green,
                  value: '68 ms',
                ),
                _Contributor(
                  label: 'Resting HR',
                  status: 'Lower than usual',
                  color: AppColors.green,
                  value: '54 bpm',
                ),
                _Contributor(
                  label: 'Respiratory rate',
                  status: 'Stable',
                  color: AppColors.green,
                  value: '14.2 /min',
                ),
                _Contributor(
                  label: 'Blood oxygen',
                  status: 'Normal',
                  color: AppColors.green,
                  value: '97%',
                ),
                _Contributor(
                  label: 'Skin temperature',
                  status: 'At baseline',
                  color: AppColors.yellow,
                  value: '-0.2°C',
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          const SectionHeader('Recovery trend'),
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const _CardTitle('Last 30 days'),
                const SizedBox(height: 16),
                TrendLineChart(
                  data: MockData.recoverySeries,
                  color: AppColors.recovery,
                  minY: 0,
                  maxY: 100,
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          const SectionHeader('Baselines'),
          AppCard(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 6),
            child: Column(
              children: const [
                _Contributor(
                  label: 'HRV baseline',
                  status: '60-day average',
                  color: AppColors.sleep,
                  value: '64 ms',
                ),
                _Contributor(
                  label: 'RHR baseline',
                  status: '60-day average',
                  color: AppColors.sleep,
                  value: '56 bpm',
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Text(
                      'Calibration',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Spacer(),
                    Text(
                      'Day 12 of 42',
                      style: TextStyle(
                        fontSize: 13,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                const ProgressBar(value: 12 / 42, color: AppColors.recovery),
                const SizedBox(height: 8),
                const Text(
                  'Scores become personalized after your baseline is built.',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Contributor extends StatelessWidget {
  const _Contributor({
    required this.label,
    required this.status,
    required this.color,
    required this.value,
  });

  final String label;
  final String status;
  final Color color;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  status,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              fontFeatures: [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );
  }
}

class _CardTitle extends StatelessWidget {
  const _CardTitle(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w600,
        color: AppColors.textSecondary,
      ),
    );
  }
}
