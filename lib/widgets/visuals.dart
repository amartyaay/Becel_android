import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../app/theme.dart';

class ScoreRing extends StatelessWidget {
  const ScoreRing({
    super.key,
    required this.value,
    required this.color,
    required this.center,
    this.size = 96,
    this.stroke = 8,
  });

  final double value;
  final Color color;
  final Widget center;
  final double size;
  final double stroke;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: value.clamp(0, 1).toDouble()),
        duration: const Duration(milliseconds: 900),
        curve: Curves.easeOutCubic,
        builder: (context, progress, _) => CustomPaint(
          painter: _RingPainter(
            progress: progress,
            color: color,
            stroke: stroke,
          ),
          child: Center(child: center),
        ),
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  _RingPainter({
    required this.progress,
    required this.color,
    required this.stroke,
  });

  final double progress;
  final Color color;
  final double stroke;

  @override
  void paint(Canvas canvas, Size size) {
    final rect =
        Offset(stroke / 2, stroke / 2) &
        Size(size.width - stroke, size.height - stroke);

    final track = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round
      ..color = color.withValues(alpha: 0.14);
    canvas.drawArc(rect, 0, math.pi * 2, false, track);

    final arc = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round
      ..color = color;
    canvas.drawArc(rect, -math.pi / 2, math.pi * 2 * progress, false, arc);
  }

  @override
  bool shouldRepaint(_RingPainter old) =>
      old.progress != progress || old.color != color;
}

class SparkLine extends StatelessWidget {
  const SparkLine({
    super.key,
    required this.data,
    required this.color,
    this.height = 36,
    this.strokeWidth = 2,
  });

  final List<double> data;
  final Color color;
  final double height;
  final double strokeWidth;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      width: double.infinity,
      child: CustomPaint(
        painter: _SparkPainter(
          data: data,
          color: color,
          strokeWidth: strokeWidth,
        ),
      ),
    );
  }
}

class _SparkPainter extends CustomPainter {
  _SparkPainter({
    required this.data,
    required this.color,
    required this.strokeWidth,
  });

  final List<double> data;
  final Color color;
  final double strokeWidth;

  @override
  void paint(Canvas canvas, Size size) {
    if (data.length < 2) return;
    final min = data.reduce(math.min);
    final max = data.reduce(math.max);
    final span = (max - min) == 0 ? 1 : max - min;

    final path = Path();
    for (var i = 0; i < data.length; i++) {
      final x = size.width * i / (data.length - 1);
      final y = size.height - ((data[i] - min) / span) * (size.height - 4) - 2;
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }

    final fill = Path.from(path)
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();

    canvas.drawPath(
      fill,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [color.withValues(alpha: 0.22), color.withValues(alpha: 0)],
        ).createShader(Offset.zero & size),
    );

    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..color = color,
    );
  }

  @override
  bool shouldRepaint(_SparkPainter old) => old.data != data;
}

class BatteryGauge extends StatelessWidget {
  const BatteryGauge({
    super.key,
    required this.value,
    required this.color,
    this.height = 64,
  });

  final double value;
  final Color color;
  final double height;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border),
        color: AppColors.bg,
      ),
      padding: const EdgeInsets.all(5),
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: value.clamp(0, 1).toDouble()),
        duration: const Duration(milliseconds: 900),
        curve: Curves.easeOutCubic,
        builder: (context, progress, _) => FractionallySizedBox(
          alignment: Alignment.centerLeft,
          widthFactor: progress,
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(13),
              gradient: LinearGradient(
                colors: [color.withValues(alpha: 0.55), color],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
