import 'package:flutter/material.dart';

import '../../app/theme.dart';
import '../../core/format.dart';
import '../../data/mock_data.dart';
import '../../domain/models.dart';
import '../../domain/score_status.dart';
import '../../widgets/charts.dart';
import '../../widgets/components.dart';
import '../../widgets/visuals.dart';

class SleepScreen extends StatelessWidget {
  const SleepScreen({super.key});

  static const _stageColors = {
    SleepStage.awake: AppColors.yellow,
    SleepStage.rem: Color(0xFF9AA6FF),
    SleepStage.core: AppColors.sleep,
    SleepStage.deep: Color(0xFF5A63D8),
  };

  @override
  Widget build(BuildContext context) {
    final scores = MockData.todayScores;
    final status = ScoreStatus.sleepScore(scores.sleepScore);
    final nights = MockData.sleepSeries.sublist(
      MockData.sleepSeries.length - 7,
    );

    return Scaffold(
      appBar: AppBar(title: const Text('Sleep')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
        children: [
          Center(
            child: Column(
              children: [
                ScoreRing(
                  value: scores.sleepScore / 100,
                  color: AppColors.sleep,
                  size: 176,
                  stroke: 12,
                  center: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '${scores.sleepScore}',
                        style: const TextStyle(
                          fontSize: 40,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -1,
                        ),
                      ),
                      const Text(
                        'Sleep score',
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
                  '7h 52m asleep · 23:14 – 7:02',
                  style: TextStyle(
                    fontSize: 14,
                    color: AppColors.textSecondary,
                    fontFeatures: [FontFeature.tabularFigures()],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 28),
          const SectionHeader('Last night'),
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Hypnogram(segments: MockData.lastNightSegments),
                const SizedBox(height: 18),
                Wrap(
                  spacing: 16,
                  runSpacing: 8,
                  children: [
                    for (final entry in _stageColors.entries)
                      _StageLegend(
                        label: _stageLabel(entry.key),
                        color: entry.value,
                        minutes: MockData.segmentMinutes(entry.key),
                      ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          const SectionHeader('Contributors'),
          AppCard(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 6),
            child: Column(
              children: const [
                _Contributor(
                  label: 'Time asleep',
                  status: 'Good',
                  color: AppColors.green,
                  value: '7h 52m',
                ),
                _Contributor(
                  label: 'Deep sleep',
                  status: 'Good',
                  color: AppColors.green,
                  value: '1h 14m',
                ),
                _Contributor(
                  label: 'REM sleep',
                  status: 'Fair',
                  color: AppColors.yellow,
                  value: '2h 00m',
                ),
                _Contributor(
                  label: 'Heart rate dip',
                  status: 'Good',
                  color: AppColors.green,
                  value: '18%',
                ),
                _Contributor(
                  label: 'Sleep efficiency',
                  status: 'Good',
                  color: AppColors.green,
                  value: '94%',
                ),
                _Contributor(
                  label: 'Continuity',
                  status: 'Fair',
                  color: AppColors.yellow,
                  value: '4 wake-ups',
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: AppCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: const [
                      Text(
                        'Sleep needed',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      SizedBox(height: 6),
                      Text(
                        '8h 30m',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.5,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        'Goal 8h + 42m debt',
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
                    children: const [
                      Text(
                        'Sleep bank',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      SizedBox(height: 6),
                      Text(
                        '-42m',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.5,
                          color: AppColors.red,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        '7-day balance',
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
          const SectionHeader('Last 7 nights'),
          AppCard(
            child: TrendBarChart(
              data: nights,
              minY: 0,
              maxY: 100,
              colorFor: (index, value) {
                if (value >= 75) return AppColors.green;
                if (value >= 60) return AppColors.yellow;
                return AppColors.red;
              },
            ),
          ),
        ],
      ),
    );
  }

  static String _stageLabel(SleepStage stage) => switch (stage) {
    SleepStage.awake => 'Awake',
    SleepStage.rem => 'REM',
    SleepStage.core => 'Core',
    SleepStage.deep => 'Deep',
  };
}

class _StageLegend extends StatelessWidget {
  const _StageLegend({
    required this.label,
    required this.color,
    required this.minutes,
  });

  final String label;
  final Color color;
  final int minutes;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 9,
          height: 9,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(
          '$label ${formatDuration(minutes)}',
          style: const TextStyle(
            fontSize: 12,
            color: AppColors.textSecondary,
            fontFeatures: [FontFeature.tabularFigures()],
          ),
        ),
      ],
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
            child: Text(
              label,
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
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
          const SizedBox(width: 10),
          Text(status, style: TextStyle(fontSize: 12, color: color)),
        ],
      ),
    );
  }
}
