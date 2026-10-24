import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../app/theme.dart';

class ChartSegment {
  const ChartSegment({
    required this.label,
    required this.minutes,
    required this.color,
  });

  final String label;
  final int minutes;
  final Color color;
}

class SparkArea extends StatelessWidget {
  const SparkArea({
    super.key,
    required this.values,
    this.color = AppColors.green,
    this.height = 120,
    this.emptyLabel = 'No samples yet',
  });

  final List<double> values;
  final Color color;
  final double height;
  final String emptyLabel;

  @override
  Widget build(BuildContext context) {
    if (values.length < 2) {
      return SizedBox(
        height: height,
        child: Center(child: Text(emptyLabel, style: AppType.caption)),
      );
    }
    return SizedBox(
      height: height,
      width: double.infinity,
      child: CustomPaint(painter: _SparkAreaPainter(values, color)),
    );
  }
}

class _SparkAreaPainter extends CustomPainter {
  _SparkAreaPainter(this.values, this.color);

  final List<double> values;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    var min = values.first;
    var max = values.first;
    for (final value in values) {
      min = math.min(min, value);
      max = math.max(max, value);
    }
    if (max - min < 1) {
      max += 1;
      min -= 1;
    }
    final range = max - min;
    final padded = range * 0.15;
    final top = max + padded;
    final bottom = min - padded;

    final stepX = size.width / (values.length - 1);
    final points = <Offset>[];
    for (var index = 0; index < values.length; index++) {
      final normalized = (values[index] - bottom) / (top - bottom);
      points.add(
        Offset(index * stepX, size.height - normalized * (size.height - 8) - 4),
      );
    }

    final linePath = Path()..moveTo(points.first.dx, points.first.dy);
    for (var index = 1; index < points.length; index++) {
      final previous = points[index - 1];
      final current = points[index];
      final midX = (previous.dx + current.dx) / 2;
      linePath.cubicTo(
        midX,
        previous.dy,
        midX,
        current.dy,
        current.dx,
        current.dy,
      );
    }

    final fillPath = Path.from(linePath)
      ..lineTo(points.last.dx, size.height)
      ..lineTo(points.first.dx, size.height)
      ..close();

    canvas.drawPath(
      fillPath,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [color.withValues(alpha: 0.28), color.withValues(alpha: 0)],
        ).createShader(Offset.zero & size),
    );

    canvas.drawPath(
      linePath,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.2
        ..strokeCap = StrokeCap.round,
    );

    canvas.drawCircle(points.last, 3.5, Paint()..color = color);
  }

  @override
  bool shouldRepaint(_SparkAreaPainter oldDelegate) =>
      oldDelegate.values != values || oldDelegate.color != color;
}

class TrendBars extends StatelessWidget {
  const TrendBars({
    super.key,
    required this.values,
    this.labels = const [],
    this.color = AppColors.green,
    this.barAreaHeight = 84,
    this.highlightLast = true,
    this.valueLabelBuilder,
  });

  final List<double?> values;
  final List<String> labels;
  final Color color;
  final double barAreaHeight;
  final bool highlightLast;
  final String Function(double value)? valueLabelBuilder;

  @override
  Widget build(BuildContext context) {
    if (values.isEmpty) {
      return const SizedBox.shrink();
    }
    var maximum = 0.0;
    for (final value in values) {
      if (value != null) maximum = math.max(maximum, value);
    }
    if (maximum <= 0) maximum = 1;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            for (var index = 0; index < values.length; index++)
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 3),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      if (valueLabelBuilder != null &&
                          values[index] != null &&
                          index == values.length - 1 &&
                          highlightLast)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 4),
                          child: Text(
                            valueLabelBuilder!(values[index]!),
                            maxLines: 1,
                            style: AppType.caption.copyWith(
                              color: color,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      Container(
                        height: values[index] == null
                            ? 3
                            : math.max(
                                6,
                                barAreaHeight * values[index]! / maximum,
                              ),
                        decoration: BoxDecoration(
                          color: values[index] == null
                              ? AppColors.border
                              : color.withValues(
                                  alpha:
                                      (highlightLast &&
                                          index == values.length - 1)
                                      ? 1
                                      : 0.38,
                                ),
                          borderRadius: BorderRadius.circular(6),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
        if (labels.isNotEmpty) ...[
          const SizedBox(height: 6),
          Row(
            children: [
              for (var index = 0; index < values.length; index++)
                Expanded(
                  child: Text(
                    index < labels.length ? labels[index] : '',
                    textAlign: TextAlign.center,
                    style: AppType.caption.copyWith(
                      color: index == values.length - 1 && highlightLast
                          ? AppColors.textSecondary
                          : AppColors.textTertiary,
                      fontWeight: index == values.length - 1 && highlightLast
                          ? FontWeight.w700
                          : FontWeight.w600,
                    ),
                  ),
                ),
            ],
          ),
        ],
      ],
    );
  }
}

class StageBar extends StatelessWidget {
  const StageBar({
    super.key,
    required this.segments,
    this.height = 20,
    this.showLabels = true,
  });

  final List<ChartSegment> segments;
  final double height;
  final bool showLabels;

  @override
  Widget build(BuildContext context) {
    final total = segments.fold<int>(
      0,
      (sum, segment) => sum + segment.minutes,
    );
    if (total <= 0) {
      return Text('No stage data for this session', style: AppType.caption);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(height / 2),
          child: SizedBox(
            height: height,
            child: Row(
              children: [
                for (final segment in segments)
                  if (segment.minutes > 0)
                    Expanded(
                      flex: segment.minutes,
                      child: Container(color: segment.color),
                    ),
              ],
            ),
          ),
        ),
        if (showLabels) ...[
          const SizedBox(height: 10),
          Wrap(
            spacing: 14,
            runSpacing: 6,
            children: [
              for (final segment in segments)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: segment.color,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      '${segment.label} ${segment.minutes}m',
                      style: AppType.caption,
                    ),
                  ],
                ),
            ],
          ),
        ],
      ],
    );
  }
}

class ZoneBarRow extends StatelessWidget {
  const ZoneBarRow({
    super.key,
    required this.label,
    required this.bpmRange,
    required this.minutes,
    required this.fraction,
    required this.color,
  });

  final String label;
  final String bpmRange;
  final int minutes;
  final double fraction;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          SizedBox(
            width: 34,
            child: Text(label, style: AppType.caption.copyWith(color: color)),
          ),
          SizedBox(width: 74, child: Text(bpmRange, style: AppType.caption)),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: Stack(
                children: [
                  Container(height: 8, color: AppColors.border),
                  FractionallySizedBox(
                    widthFactor: fraction.clamp(0.0, 1.0),
                    child: Container(height: 8, color: color),
                  ),
                ],
              ),
            ),
          ),
          SizedBox(
            width: 52,
            child: Text(
              '${minutes}m',
              textAlign: TextAlign.right,
              style: AppType.caption.copyWith(color: AppColors.textSecondary),
            ),
          ),
        ],
      ),
    );
  }
}
