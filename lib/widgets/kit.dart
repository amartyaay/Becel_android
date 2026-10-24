import 'package:flutter/material.dart';

import '../app/theme.dart';

/// The standard Becel surface: rounded, hairline border, one elevation level.
class SurfaceCard extends StatelessWidget {
  const SurfaceCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.onTap,
    this.color = AppColors.surfaceHigh,
    this.borderColor,
    this.radius = 20,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;
  final Color color;
  final Color? borderColor;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final shape = BorderRadius.circular(radius);
    final border = Border.all(color: borderColor ?? AppColors.border);
    if (onTap == null) {
      return Container(
        padding: padding,
        decoration: BoxDecoration(
          color: color,
          borderRadius: shape,
          border: border,
        ),
        child: child,
      );
    }
    return Material(
      color: color,
      borderRadius: shape,
      child: InkWell(
        onTap: onTap,
        borderRadius: shape,
        child: Container(
          padding: padding,
          decoration: BoxDecoration(borderRadius: shape, border: border),
          child: child,
        ),
      ),
    );
  }
}

/// Rounded color-tinted icon container used across metrics and sources.
class IconChip extends StatelessWidget {
  const IconChip({
    super.key,
    required this.icon,
    required this.color,
    this.size = 40,
    this.iconSize,
    this.radius,
  });

  final IconData icon;
  final Color color;
  final double size;
  final double? iconSize;
  final double? radius;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(radius ?? size * 0.33),
      ),
      child: Icon(icon, color: color, size: iconSize ?? size * 0.5),
    );
  }
}

/// Unified status pill with an optional dot-less icon or inline spinner.
class StatusPill extends StatelessWidget {
  const StatusPill({
    super.key,
    required this.label,
    required this.color,
    this.icon,
    this.loading = false,
  });

  final String label;
  final Color color;
  final IconData? icon;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (loading)
            SizedBox(
              width: 12,
              height: 12,
              child: CircularProgressIndicator(strokeWidth: 1.8, color: color),
            )
          else if (icon != null)
            Icon(icon, size: 13, color: color),
          if (loading || icon != null) const SizedBox(width: 6),
          Text(label, style: AppType.pill.copyWith(color: color)),
        ],
      ),
    );
  }
}

/// Screen title block with an uppercase eyebrow and optional trailing widget.
class ScreenHeader extends StatelessWidget {
  const ScreenHeader({
    super.key,
    required this.eyebrow,
    required this.title,
    this.trailing,
    this.onBack,
  });

  final String eyebrow;
  final String title;
  final Widget? trailing;
  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (onBack != null) ...[
          Row(
            children: [
              InkWell(
                onTap: onBack,
                borderRadius: BorderRadius.circular(10),
                child: Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: AppColors.surfaceHigh,
                    border: Border.all(color: AppColors.border),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.arrow_back_rounded,
                    size: 18,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Text(eyebrow, style: AppType.eyebrow),
            ],
          ),
          const SizedBox(height: 10),
        ] else
          Text(eyebrow, style: AppType.eyebrow),
        const SizedBox(height: 6),
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(child: Text(title, style: AppType.screenTitle)),
            if (trailing != null) ...[
              const SizedBox(width: 12),
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: trailing!,
              ),
            ],
          ],
        ),
      ],
    );
  }
}

/// Section title with an optional action ("See all") or caption ("LAST 7 DAYS").
class SectionHeader extends StatelessWidget {
  const SectionHeader({
    super.key,
    required this.title,
    this.action,
    this.onAction,
    this.caption,
  });

  final String title;
  final String? action;
  final VoidCallback? onAction;
  final String? caption;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(child: Text(title, style: AppType.sectionTitle)),
        if (caption != null)
          Text(caption!, style: AppType.eyebrow.copyWith(letterSpacing: 0.8)),
        if (action != null)
          TextButton(
            onPressed: onAction,
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 6),
              minimumSize: const Size(48, 36),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: Text(action!),
          ),
      ],
    );
  }
}

/// Soft tinted note for errors and informational banners.
class InfoNote extends StatelessWidget {
  const InfoNote({
    super.key,
    required this.text,
    this.icon = Icons.error_outline_rounded,
    this.color = AppColors.red,
    this.textColor,
  });

  final String text;
  final IconData? icon;
  final Color color;
  final Color? textColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.22)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 17, color: color),
            const SizedBox(width: 10),
          ],
          Expanded(
            child: Text(
              text,
              style: AppType.note.copyWith(
                color: textColor ?? AppColors.textSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Centered uppercase footer used to state data provenance per screen.
class TrustFooter extends StatelessWidget {
  const TrustFooter({super.key, required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(text, textAlign: TextAlign.center, style: AppType.footer),
    );
  }
}

/// The signature Becel movement card.
///
/// Renders the lime gradient hero when a Fitbit Air-matched step record is
/// present, and a muted dark variant when it is missing so empty states read
/// as designed rather than broken.
class MovementHero extends StatelessWidget {
  const MovementHero({
    super.key,
    required this.stepCount,
    required this.label,
    required this.caption,
    required this.statusLabel,
    required this.attention,
    required this.footerNote,
  });

  final int? stepCount;
  final String label;
  final String caption;
  final String statusLabel;
  final bool attention;
  final String footerNote;

  static const _goal = 10000;

  @override
  Widget build(BuildContext context) {
    final hasData = stepCount != null;
    final progress = ((stepCount ?? 0) / _goal).clamp(0.0, 1.0);
    final percent = (progress * 100).round();
    final steps = hasData ? _formatNumber(stepCount!) : '—';

    final titleColor = hasData
        ? const Color(0xFF43532A)
        : AppColors.textTertiary;
    final valueColor = hasData
        ? const Color(0xFF17200E)
        : AppColors.textPrimary;
    final captionColor = hasData
        ? const Color(0xFF4D6033)
        : AppColors.textSecondary;
    final ringValueColor = hasData
        ? const Color(0xFF1C2910)
        : AppColors.textPrimary;
    final ringLabelColor = hasData
        ? const Color(0xFF52663A)
        : AppColors.textTertiary;
    final footerColor = hasData
        ? const Color(0xFF44592B)
        : AppColors.textSecondary;
    final trackColor = hasData
        ? const Color(0x334E632E)
        : AppColors.surfaceHigher;
    final brandIconBg = hasData
        ? Color(0xFF27391A).withValues(alpha: 0.12)
        : AppColors.surfaceHigher;
    final brandIconColor = hasData
        ? const Color(0xFF344821)
        : AppColors.textSecondary;

    final chipBg = hasData
        ? Colors.black.withValues(alpha: 0.08)
        : attention
        ? AppColors.yellow.withValues(alpha: 0.14)
        : AppColors.surfaceHigher;
    final chipFg = hasData
        ? const Color(0xFF44592B)
        : attention
        ? AppColors.yellow
        : AppColors.textTertiary;

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(26),
        gradient: hasData
            ? const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFFDAF58B), Color(0xFFB9E867)],
              )
            : const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFF1A241E), Color(0xFF131C17)],
              ),
        border: hasData
            ? null
            : Border.all(color: AppColors.green.withValues(alpha: 0.12)),
        boxShadow: hasData
            ? [
                BoxShadow(
                  color: AppColors.green.withValues(alpha: 0.10),
                  blurRadius: 30,
                  offset: const Offset(0, 14),
                ),
              ]
            : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: brandIconBg,
                  borderRadius: BorderRadius.circular(11),
                ),
                child: Icon(
                  Icons.directions_walk_rounded,
                  color: brandIconColor,
                  size: 18,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    color: titleColor,
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.2,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
                decoration: BoxDecoration(
                  color: chipBg,
                  borderRadius: BorderRadius.circular(99),
                ),
                child: Text(
                  statusLabel,
                  style: TextStyle(
                    color: chipFg,
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.6,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      steps,
                      style: TextStyle(
                        color: valueColor,
                        fontSize: 46,
                        height: 1,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -2.4,
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      caption,
                      style: TextStyle(
                        color: captionColor,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(
                width: 92,
                height: 92,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    SizedBox.expand(
                      child: CircularProgressIndicator(
                        value: progress,
                        strokeWidth: 8,
                        backgroundColor: trackColor,
                        valueColor: const AlwaysStoppedAnimation(
                          Color(0xFF263817),
                        ),
                        strokeCap: StrokeCap.round,
                      ),
                    ),
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          hasData ? '$percent%' : '—',
                          style: TextStyle(
                            color: ringValueColor,
                            fontSize: 21,
                            fontWeight: FontWeight.w900,
                            letterSpacing: -0.6,
                            fontFeatures: const [FontFeature.tabularFigures()],
                          ),
                        ),
                        Text(
                          'of goal',
                          style: TextStyle(
                            color: ringLabelColor,
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          ClipRRect(
            borderRadius: BorderRadius.circular(99),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 7,
              backgroundColor: trackColor,
              valueColor: const AlwaysStoppedAnimation(Color(0xFF263817)),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            footerNote,
            style: TextStyle(
              color: footerColor,
              fontSize: 11.5,
              height: 1.35,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  static String _formatNumber(int value) {
    final text = value.toString();
    final buffer = StringBuffer();
    for (var index = 0; index < text.length; index++) {
      if (index > 0 && (text.length - index) % 3 == 0) buffer.write(',');
      buffer.write(text[index]);
    }
    return buffer.toString();
  }
}

/// Compact metric tile used in pairs (heart rate, sleep) on Today.
class MetricTile extends StatelessWidget {
  const MetricTile({
    super.key,
    required this.icon,
    required this.color,
    required this.label,
    required this.value,
    this.unit = '',
    required this.note,
    this.onTap,
  });

  final IconData icon;
  final Color color;
  final String label;
  final String value;
  final String unit;
  final String note;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surfaceHigh,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.fromLTRB(16, 15, 16, 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppColors.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(icon, size: 16, color: color),
                  const SizedBox(width: 7),
                  Expanded(
                    child: Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppType.eyebrow.copyWith(letterSpacing: 0.8),
                    ),
                  ),
                  if (onTap != null)
                    const Icon(
                      Icons.chevron_right_rounded,
                      size: 16,
                      color: AppColors.textTertiary,
                    ),
                ],
              ),
              const Spacer(),
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Text(value, style: AppType.numM),
                    if (unit.isNotEmpty) ...[
                      const SizedBox(width: 4),
                      Text(unit, style: AppType.unit),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 6),
              Text(
                note,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: AppType.caption,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
