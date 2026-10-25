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
    required this.rangeLabel,
    required this.minutes,
    required this.fraction,
    required this.color,
  });

  final String label;
  final String rangeLabel;
  final int minutes;
  final double fraction;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  label,
                  style: AppType.rowTitle.copyWith(color: color, fontSize: 12),
                ),
              ),
              Text(rangeLabel, style: AppType.caption),
              const SizedBox(width: 9),
              Text(
                '$minutes min',
                style: AppType.caption.copyWith(color: AppColors.textSecondary),
              ),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: Stack(
              children: [
                Container(height: 7, color: AppColors.border),
                FractionallySizedBox(
                  widthFactor: fraction.clamp(0.0, 1.0),
                  child: Container(height: 7, color: color),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// A day at a glance: heart rate from midnight to midnight with sleep and
/// workouts shaded behind it and a marker at the current time.
class DayTimeline extends StatelessWidget {
  const DayTimeline({
    super.key,
    required this.points,
    required this.sleep,
    required this.workouts,
    this.nowMinute,
    this.height = 120,
  });

  /// (minute of day 0–1439, bpm), in time order.
  final List<(double, double)> points;

  /// Shaded spans as (from, to) minutes of day.
  final List<(double, double)> sleep;
  final List<(double, double)> workouts;
  final double? nowMinute;
  final double height;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        SizedBox(
          height: height,
          width: double.infinity,
          child: points.length < 2
              ? Center(
                  child: Text(
                    'No heart rate yet today',
                    style: AppType.caption,
                  ),
                )
              : CustomPaint(
                  painter: _DayTimelinePainter(
                    points: points,
                    sleep: sleep,
                    workouts: workouts,
                    nowMinute: nowMinute,
                  ),
                ),
        ),
        const SizedBox(height: 6),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            for (final label in const ['12a', '6a', '12p', '6p', '12a'])
              Text(label, style: AppType.caption.copyWith(fontSize: 11)),
          ],
        ),
      ],
    );
  }
}

class _DayTimelinePainter extends CustomPainter {
  _DayTimelinePainter({
    required this.points,
    required this.sleep,
    required this.workouts,
    required this.nowMinute,
  });

  final List<(double, double)> points;
  final List<(double, double)> sleep;
  final List<(double, double)> workouts;
  final double? nowMinute;

  @override
  void paint(Canvas canvas, Size size) {
    double x(double minute) => minute / 1440 * size.width;
    final values = [for (final p in points) p.$2];
    final low = values.reduce(math.min) - 5;
    final high = values.reduce(math.max) + 5;
    double y(double bpm) =>
        size.height - (bpm - low) / math.max(1, high - low) * size.height;

    final band = RRect.fromLTRBR;
    void shade(List<(double, double)> spans, Color color) {
      final paint = Paint()..color = color;
      for (final (from, to) in spans) {
        final left = x(from.clamp(0, 1440));
        final right = x(to.clamp(0, 1440));
        if (right - left < 1) continue;
        canvas.drawRRect(
          band(left, 0, right, size.height, const Radius.circular(6)),
          paint,
        );
      }
    }

    shade(sleep, AppColors.tint(AppColors.sleep, 0.12));
    shade(workouts, AppColors.tint(AppColors.strain, 0.16));

    // Quiet guides at 6-hour marks.
    final grid = Paint()
      ..color = AppColors.border
      ..strokeWidth = 1;
    for (var h = 6; h < 24; h += 6) {
      canvas.drawLine(
        Offset(x(h * 60.0), 0),
        Offset(x(h * 60.0), size.height),
        grid,
      );
    }

    final line = Path();
    final area = Path();
    for (var i = 0; i < points.length; i++) {
      final px = x(points[i].$1);
      final py = y(points[i].$2);
      // Break the line across gaps of more than 20 minutes (band off).
      final gap = i > 0 && points[i].$1 - points[i - 1].$1 > 20;
      if (i == 0 || gap) {
        line.moveTo(px, py);
      } else {
        line.lineTo(px, py);
      }
    }
    area
      ..addPath(line, Offset.zero)
      ..lineTo(x(points.last.$1), size.height)
      ..lineTo(x(points.first.$1), size.height)
      ..close();
    canvas.drawPath(
      area,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            AppColors.active.withValues(alpha: 0.16),
            AppColors.active.withValues(alpha: 0),
          ],
        ).createShader(Offset.zero & size),
    );
    canvas.drawPath(
      line,
      Paint()
        ..color = AppColors.active
        ..strokeWidth = 2
        ..style = PaintingStyle.stroke
        ..strokeJoin = StrokeJoin.round
        ..strokeCap = StrokeCap.round,
    );

    final now = nowMinute;
    if (now != null) {
      final nx = x(now.clamp(0, 1440));
      final dash = Paint()
        ..color = AppColors.textTertiary
        ..strokeWidth = 1.2;
      for (var dy = 0.0; dy < size.height; dy += 6) {
        canvas.drawLine(Offset(nx, dy), Offset(nx, dy + 3), dash);
      }
      final last = points.last;
      canvas.drawCircle(
        Offset(x(last.$1), y(last.$2)),
        4,
        Paint()..color = AppColors.surface,
      );
      canvas.drawCircle(
        Offset(x(last.$1), y(last.$2)),
        3,
        Paint()..color = AppColors.active,
      );
    }
  }

  @override
  bool shouldRepaint(_DayTimelinePainter old) =>
      old.points != points || old.nowMinute != nowMinute;
}
