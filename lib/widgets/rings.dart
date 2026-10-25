import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../app/theme.dart';
import '../domain/estimates.dart';

Color recoveryColor(int? score) =>
    switch (score == null ? null : recoveryBandOf(score)) {
      RecoveryBand.green => AppColors.bandGreen,
      RecoveryBand.yellow => AppColors.bandYellow,
      RecoveryBand.red => AppColors.bandRed,
      null => AppColors.textTertiary,
    };

String recoveryWord(int? score) =>
    switch (score == null ? null : recoveryBandOf(score)) {
      RecoveryBand.green => 'Primed',
      RecoveryBand.yellow => 'Steady',
      RecoveryBand.red => 'Run down',
      null => 'Calibrating',
    };

/// Animated circular progress ring with a centred value and caption.
class MetricRing extends StatelessWidget {
  const MetricRing({
    super.key,
    required this.fraction,
    required this.color,
    required this.value,
    required this.label,
    this.unit,
    this.size = 104,
    this.stroke = 9,
    this.bandFrom,
    this.bandTo,
    this.semanticsLabel,
  });

  final double? fraction;
  final Color color;
  final String value;
  final String label;
  final String? unit;
  final double size;
  final double stroke;

  /// Optional target band drawn as a faint arc (e.g. strain target).
  final double? bandFrom;
  final double? bandTo;
  final String? semanticsLabel;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: semanticsLabel ?? '$label $value${unit ?? ''}',
      child: ExcludeSemantics(
        child: TweenAnimationBuilder<double>(
          tween: Tween(begin: 0, end: (fraction ?? 0).clamp(0.0, 1.0)),
          duration: const Duration(milliseconds: 900),
          curve: Curves.easeOutCubic,
          builder: (context, animated, _) => SizedBox(
            width: size,
            height: size,
            child: CustomPaint(
              painter: _RingPainter(
                fraction: fraction == null ? null : animated,
                color: color,
                stroke: stroke,
                bandFrom: bandFrom,
                bandTo: bandTo,
              ),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.baseline,
                        textBaseline: TextBaseline.alphabetic,
                        children: [
                          Text(
                            value,
                            style: AppType.numM.copyWith(
                              fontSize: size * 0.27,
                              letterSpacing: -1.2,
                            ),
                          ),
                          if (unit != null)
                            Text(
                              unit!,
                              style: AppType.unit.copyWith(
                                fontSize: size * 0.12,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 1),
                    Text(
                      _sentenceCase(label),
                      style: AppType.caption.copyWith(
                        fontSize: math.max(10.5, size * 0.095),
                        color: AppColors.textSecondary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  _RingPainter({
    required this.fraction,
    required this.color,
    required this.stroke,
    this.bandFrom,
    this.bandTo,
  });

  final double? fraction;
  final Color color;
  final double stroke;
  final double? bandFrom;
  final double? bandTo;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final arc = rect.deflate(stroke / 2 + 1);
    const start = -math.pi / 2;
    // Pastel track in the ring's own hue.
    canvas.drawArc(
      arc,
      0,
      math.pi * 2,
      false,
      Paint()
        ..color = AppColors.tint(color, 0.16)
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke,
    );
    if (bandFrom != null && bandTo != null) {
      canvas.drawArc(
        rect.deflate(stroke / 2 + 1 - stroke * 0.85),
        start + bandFrom! * math.pi * 2,
        (bandTo! - bandFrom!) * math.pi * 2,
        false,
        Paint()
          ..color = color.withValues(alpha: 0.35)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3
          ..strokeCap = StrokeCap.round,
      );
    }
    final value = fraction;
    if (value == null || value <= 0) return;
    final sweep = math.max(0.02, value) * math.pi * 2;
    // Gradient runs along the filled arc: light at the start, full colour
    // at the head, like a comet.
    final light = Color.lerp(color, Colors.white, 0.45)!;
    canvas.drawArc(
      arc,
      start,
      sweep,
      false,
      Paint()
        ..shader = SweepGradient(
          startAngle: 0,
          endAngle: math.max(0.01, sweep),
          transform: const GradientRotation(-math.pi / 2),
          colors: [light, color],
        ).createShader(rect)
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke
        ..strokeCap = StrokeCap.round,
    );
    // A bright head with a soft halo marks "now".
    final angle = start + sweep;
    final radius = arc.width / 2;
    final head =
        rect.center + Offset(math.cos(angle), math.sin(angle)) * radius;
    canvas.drawCircle(
      head,
      stroke * 0.9,
      Paint()
        ..color = color.withValues(alpha: 0.25)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
    );
    canvas.drawCircle(head, stroke * 0.32, Paint()..color = Colors.white);
  }

  @override
  bool shouldRepaint(_RingPainter old) =>
      old.fraction != fraction ||
      old.color != color ||
      old.bandFrom != bandFrom ||
      old.bandTo != bandTo;
}

/// Horizontal bar of a value against a reference range, with a marker.
class LinearMeter extends StatelessWidget {
  const LinearMeter({
    super.key,
    required this.value,
    required this.max,
    required this.color,
    this.bandFrom,
    this.bandTo,
    this.height = 8,
  });

  final double value;
  final double max;
  final Color color;
  final double? bandFrom;
  final double? bandTo;
  final double height;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        double x(double v) => (v / max).clamp(0.0, 1.0) * width;
        return SizedBox(
          height: height + 8,
          child: Stack(
            children: [
              Positioned(
                left: 0,
                right: 0,
                top: 4,
                child: Container(
                  height: height,
                  decoration: BoxDecoration(
                    color: AppColors.surfaceHigher,
                    borderRadius: BorderRadius.circular(99),
                  ),
                ),
              ),
              if (bandFrom != null && bandTo != null)
                Positioned(
                  left: x(bandFrom!),
                  width: math.max(2, x(bandTo!) - x(bandFrom!)),
                  top: 4,
                  child: Container(
                    height: height,
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.25),
                      borderRadius: BorderRadius.circular(99),
                    ),
                  ),
                ),
              Positioned(
                left: 0,
                top: 4,
                child: Container(
                  width: x(value),
                  height: height,
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: BorderRadius.circular(99),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// Compact bar chart for daily series with optional colour per bar.
class DayBars extends StatelessWidget {
  const DayBars({
    super.key,
    required this.values,
    required this.labels,
    required this.colorFor,
    this.maxValue,
    this.height = 90,
    this.valueLabel,
    this.referenceLine,
    this.semanticsLabel,
  });

  final List<double?> values;
  final List<String> labels;
  final Color Function(int index, double value) colorFor;
  final double? maxValue;
  final double height;
  final String Function(double value)? valueLabel;
  final double? referenceLine;
  final String? semanticsLabel;

  @override
  Widget build(BuildContext context) {
    final max =
        maxValue ??
        values.whereType<double>().fold<double>(1, (m, v) => math.max(m, v));
    return Semantics(
      label: semanticsLabel,
      child: ExcludeSemantics(
        child: Column(
          children: [
            SizedBox(
              height: height + (valueLabel == null ? 0 : 20),
              child: Stack(
                children: [
                  if (referenceLine != null)
                    Positioned(
                      left: 0,
                      right: 0,
                      bottom: height * (referenceLine! / max).clamp(0.0, 1.0),
                      child: Container(
                        height: 1,
                        color: AppColors.textTertiary.withValues(alpha: 0.5),
                      ),
                    ),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      for (var i = 0; i < values.length; i++)
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 2.5,
                            ),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                if (valueLabel != null && values[i] != null)
                                  FittedBox(
                                    fit: BoxFit.scaleDown,
                                    child: Text(
                                      valueLabel!(values[i]!),
                                      maxLines: 1,
                                      style: AppType.caption.copyWith(
                                        fontSize: 10,
                                        fontWeight: FontWeight.w700,
                                        color: AppColors.textSecondary,
                                      ),
                                    ),
                                  ),
                                const SizedBox(height: 3),
                                Container(
                                  height: values[i] == null
                                      ? 3
                                      : math.max(
                                          4,
                                          height *
                                              (values[i]! / max).clamp(
                                                0.0,
                                                1.0,
                                              ),
                                        ),
                                  decoration: BoxDecoration(
                                    color: values[i] == null
                                        ? AppColors.border
                                        : colorFor(i, values[i]!),
                                    borderRadius: BorderRadius.circular(5),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                for (var i = 0; i < labels.length; i++)
                  Expanded(
                    child: Text(
                      labels[i],
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      style: AppType.caption.copyWith(
                        fontSize: 10.5,
                        color: i == labels.length - 1
                            ? AppColors.textSecondary
                            : AppColors.textTertiary,
                        fontWeight: i == labels.length - 1
                            ? FontWeight.w800
                            : FontWeight.w600,
                      ),
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

/// Small metric block: label, big value, delta line.
class StatBlock extends StatelessWidget {
  const StatBlock({
    super.key,
    required this.label,
    required this.value,
    this.unit,
    this.delta,
    this.deltaColor,
    this.align = CrossAxisAlignment.start,
  });

  final String label;
  final String value;
  final String? unit;
  final String? delta;
  final Color? deltaColor;
  final CrossAxisAlignment align;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: align,
      children: [
        Text(
          _sentenceCase(label),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: AppType.eyebrow.copyWith(fontSize: 12),
        ),
        const SizedBox(height: 4),
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(value, style: AppType.numS.copyWith(fontSize: 21)),
              if (unit != null) ...[
                const SizedBox(width: 3),
                Text(unit!, style: AppType.unit.copyWith(fontSize: 11.5)),
              ],
            ],
          ),
        ),
        if (delta != null) ...[
          const SizedBox(height: 3),
          Text(
            delta!,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppType.caption.copyWith(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: deltaColor ?? AppColors.textTertiary,
            ),
          ),
        ],
      ],
    );
  }
}

/// Titled card section used across the redesigned screens.
class PanelCard extends StatelessWidget {
  const PanelCard({
    super.key,
    required this.child,
    this.title,
    this.icon,
    this.accent = AppColors.green,
    this.trailing,
    this.onTap,
    this.padding = const EdgeInsets.fromLTRB(18, 16, 18, 18),
  });

  final Widget child;
  final String? title;
  final IconData? icon;
  final Color accent;
  final Widget? trailing;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final body = Padding(
      padding: padding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (title != null) ...[
            Row(
              children: [
                if (icon != null) ...[
                  Container(
                    width: 30,
                    height: 30,
                    decoration: BoxDecoration(
                      color: AppColors.tint(accent, 0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(icon, size: 16, color: accent),
                  ),
                  const SizedBox(width: 10),
                ],
                Expanded(
                  child: Text(_sentenceCase(title!), style: AppType.cardTitle),
                ),
                ?trailing,
                if (onTap != null && trailing == null)
                  const Icon(
                    Icons.chevron_right_rounded,
                    size: 18,
                    color: AppColors.textTertiary,
                  ),
              ],
            ),
            const SizedBox(height: 14),
          ],
          child,
        ],
      ),
    );
    const decoration = BoxDecoration(
      color: AppColors.surface,
      borderRadius: BorderRadius.all(Radius.circular(26)),
      boxShadow: AppColors.cardShadow,
    );
    if (onTap == null) return Container(decoration: decoration, child: body);
    return Container(
      decoration: decoration,
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(26),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(26),
          child: body,
        ),
      ),
    );
  }
}

/// "TODAY'S PLAN" → "Today's plan": quieter headers, values lead.
String _sentenceCase(String text) {
  if (text.isEmpty || text != text.toUpperCase()) return text;
  final lower = text.toLowerCase();
  final fixed = lower
      .replaceAll('hrv', 'HRV')
      .replaceAll('acwr', 'ACWR')
      .replaceAll('1rm', '1RM')
      .replaceAll('fitbit', 'Fitbit')
      .replaceAll('becel', 'Becel')
      .replaceAll(' vs ', ' vs ')
      .replaceAll('karvonen', 'Karvonen')
      .replaceAll('vo₂', 'VO₂');
  return fixed[0].toUpperCase() + fixed.substring(1);
}

/// Pill-shaped tag with word + colour (never colour alone).
class Tag extends StatelessWidget {
  const Tag(this.text, {super.key, required this.color});

  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.14),
      borderRadius: BorderRadius.circular(99),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 6,
          height: 6,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(
          text,
          style: AppType.pill.copyWith(
            color: AppColors.textPrimary,
            fontSize: 12,
          ),
        ),
      ],
    ),
  );
}

/// Soft radial glow behind a hero element, tinted by its metric colour.
class Glow extends StatelessWidget {
  const Glow({
    super.key,
    required this.color,
    required this.child,
    this.radius = 0.75,
  });

  final Color color;
  final Widget child;
  final double radius;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      gradient: RadialGradient(
        radius: radius,
        colors: [
          color.withValues(alpha: 0.30),
          color.withValues(alpha: 0.08),
          color.withValues(alpha: 0),
        ],
        stops: const [0.0, 0.6, 1.0],
      ),
    ),
    child: child,
  );
}
