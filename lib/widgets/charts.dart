import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../app/theme.dart';
import '../domain/models.dart';

class TrendLineChart extends StatelessWidget {
  const TrendLineChart({
    super.key,
    required this.data,
    required this.color,
    this.height = 160,
    this.bandLow,
    this.bandHigh,
    this.bandColor,
    this.minY,
    this.maxY,
  });

  final List<double> data;
  final Color color;
  final double height;
  final double? bandLow;
  final double? bandHigh;
  final Color? bandColor;
  final double? minY;
  final double? maxY;

  @override
  Widget build(BuildContext context) {
    if (data.isEmpty) return SizedBox(height: height);
    final min = minY ?? data.reduce((a, b) => a < b ? a : b) - 6;
    final max = maxY ?? data.reduce((a, b) => a > b ? a : b) + 6;

    return SizedBox(
      height: height,
      child: LineChart(
        LineChartData(
          minY: min,
          maxY: max,
          gridData: const FlGridData(show: false),
          borderData: FlBorderData(show: false),
          titlesData: const FlTitlesData(show: false),
          lineTouchData: const LineTouchData(enabled: false),
          rangeAnnotations: RangeAnnotations(
            horizontalRangeAnnotations: [
              if (bandLow != null && bandHigh != null)
                HorizontalRangeAnnotation(
                  y1: bandLow!,
                  y2: bandHigh!,
                  color: (bandColor ?? color).withValues(alpha: 0.10),
                ),
            ],
          ),
          lineBarsData: [
            LineChartBarData(
              spots: [
                for (var i = 0; i < data.length; i++)
                  FlSpot(i.toDouble(), data[i]),
              ],
              isCurved: true,
              curveSmoothness: 0.25,
              color: color,
              barWidth: 2.5,
              dotData: const FlDotData(show: false),
              belowBarData: BarAreaData(
                show: true,
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    color.withValues(alpha: 0.22),
                    color.withValues(alpha: 0),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class TrendBarChart extends StatelessWidget {
  const TrendBarChart({
    super.key,
    required this.data,
    required this.colorFor,
    this.height = 140,
    this.minY,
    this.maxY,
  });

  final List<double> data;
  final Color Function(int index, double value) colorFor;
  final double height;
  final double? minY;
  final double? maxY;

  @override
  Widget build(BuildContext context) {
    final max = maxY ?? data.reduce((a, b) => a > b ? a : b) + 6;
    final min = minY ?? 0;

    return SizedBox(
      height: height,
      child: BarChart(
        BarChartData(
          minY: min,
          maxY: max,
          alignment: BarChartAlignment.spaceBetween,
          gridData: const FlGridData(show: false),
          borderData: FlBorderData(show: false),
          titlesData: const FlTitlesData(show: false),
          barTouchData: BarTouchData(enabled: false),
          barGroups: [
            for (var i = 0; i < data.length; i++)
              BarChartGroupData(
                x: i,
                barRods: [
                  BarChartRodData(
                    toY: data[i],
                    color: colorFor(i, data[i]),
                    width: 7,
                    borderRadius: BorderRadius.circular(4),
                    backDrawRodData: BackgroundBarChartRodData(
                      show: true,
                      toY: max,
                      color: AppColors.border.withValues(alpha: 0.35),
                    ),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

class StressDayChart extends StatelessWidget {
  const StressDayChart({super.key, required this.samples, this.height = 160});

  final List<StressSample> samples;
  final double height;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      child: LineChart(
        LineChartData(
          minY: 0,
          maxY: 100,
          gridData: const FlGridData(show: false),
          borderData: FlBorderData(show: false),
          titlesData: FlTitlesData(
            leftTitles: const AxisTitles(),
            topTitles: const AxisTitles(),
            rightTitles: const AxisTitles(),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                interval: 24,
                reservedSize: 24,
                getTitlesWidget: (value, meta) => Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(
                    '${value.toInt()}h',
                    style: const TextStyle(
                      fontSize: 10,
                      color: AppColors.textTertiary,
                    ),
                  ),
                ),
              ),
            ),
          ),
          lineTouchData: const LineTouchData(enabled: false),
          lineBarsData: [
            LineChartBarData(
              spots: [
                for (var i = 0; i < samples.length; i++)
                  FlSpot(i / 4, samples[i].value.toDouble()),
              ],
              isCurved: true,
              curveSmoothness: 0.3,
              color: AppColors.stress,
              barWidth: 2.5,
              dotData: const FlDotData(show: false),
              belowBarData: BarAreaData(
                show: true,
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    AppColors.stress.withValues(alpha: 0.25),
                    AppColors.stress.withValues(alpha: 0),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class Hypnogram extends StatelessWidget {
  const Hypnogram({super.key, required this.segments});

  final List<SleepSegment> segments;

  static const _stageColors = {
    SleepStage.awake: AppColors.yellow,
    SleepStage.rem: Color(0xFF9AA6FF),
    SleepStage.core: AppColors.sleep,
    SleepStage.deep: Color(0xFF5A63D8),
  };

  @override
  Widget build(BuildContext context) {
    final stages = [
      SleepStage.awake,
      SleepStage.rem,
      SleepStage.core,
      SleepStage.deep,
    ];
    return Column(
      children: [
        for (final stage in stages)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 3),
            child: Row(
              children: [
                SizedBox(
                  width: 46,
                  child: Text(
                    _label(stage),
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
                Expanded(
                  child: Row(
                    children: [
                      for (final seg in segments)
                        Expanded(
                          flex: seg.minutes,
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 0.5,
                            ),
                            child: Container(
                              height: 12,
                              decoration: BoxDecoration(
                                color: seg.stage == stage
                                    ? _stageColors[stage]
                                    : Colors.transparent,
                                borderRadius: BorderRadius.circular(4),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  String _label(SleepStage stage) => switch (stage) {
    SleepStage.awake => 'Awake',
    SleepStage.rem => 'REM',
    SleepStage.core => 'Core',
    SleepStage.deep => 'Deep',
  };
}
