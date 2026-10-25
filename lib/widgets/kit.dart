import 'package:flutter/material.dart';

import '../app/theme.dart';

/// The standard Becel surface: white, very round, lifted by a soft shadow.
class SurfaceCard extends StatelessWidget {
  const SurfaceCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(18),
    this.onTap,
    this.color = AppColors.surface,
    this.borderColor,
    this.radius = 24,
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
    final decoration = BoxDecoration(
      color: color,
      borderRadius: shape,
      border: borderColor == null ? null : Border.all(color: borderColor!),
      boxShadow: color == AppColors.surface ? AppColors.cardShadow : null,
    );
    if (onTap == null) {
      return Container(padding: padding, decoration: decoration, child: child);
    }
    return Container(
      decoration: decoration,
      child: Material(
        color: Colors.transparent,
        borderRadius: shape,
        child: InkWell(
          onTap: onTap,
          borderRadius: shape,
          child: Padding(padding: padding, child: child),
        ),
      ),
    );
  }
}

/// Rounded pastel icon container.
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
        color: AppColors.tint(color, 0.14),
        borderRadius: BorderRadius.circular(radius ?? size * 0.36),
      ),
      child: Icon(icon, color: color, size: iconSize ?? size * 0.5),
    );
  }
}

/// Status pill with an optional icon or inline spinner.
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
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.tint(color, 0.14),
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
          Text(
            label,
            style: AppType.pill.copyWith(color: AppColors.textPrimary),
          ),
        ],
      ),
    );
  }
}

/// Screen title block with a quiet eyebrow and optional back button.
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
          Material(
            color: AppColors.surface,
            shape: const CircleBorder(),
            elevation: 0,
            child: InkWell(
              onTap: onBack,
              customBorder: const CircleBorder(),
              child: Container(
                width: 44,
                height: 44,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  boxShadow: AppColors.cardShadow,
                  color: AppColors.surface,
                ),
                child: const Icon(
                  Icons.arrow_back_rounded,
                  size: 20,
                  color: AppColors.textPrimary,
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
        ],
        Text(eyebrow, style: AppType.eyebrow),
        const SizedBox(height: 4),
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(child: Text(title, style: AppType.screenTitle)),
            if (trailing != null) ...[const SizedBox(width: 12), trailing!],
          ],
        ),
      ],
    );
  }
}

/// Section title with an optional action or caption.
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
          Text(
            caption!.toLowerCase().replaceFirstMapped(
              RegExp(r'^\w'),
              (m) => m[0]!.toUpperCase(),
            ),
            style: AppType.eyebrow,
          ),
        if (action != null)
          TextButton(
            onPressed: onAction,
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              minimumSize: const Size(48, 48),
            ),
            child: Text(action!),
          ),
      ],
    );
  }
}

/// Pastel note for errors and informational banners.
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
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.tint(color, 0.10),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 18, color: color),
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

/// Centered footer stating data provenance.
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

/// A compact provenance line: source, measurement time, and freshness.
class SourceLine extends StatelessWidget {
  const SourceLine({
    super.key,
    required this.text,
    this.icon = Icons.verified_outlined,
    this.color = AppColors.textTertiary,
  });

  final String text;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 1),
          child: Icon(icon, size: 14, color: color),
        ),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            text,
            style: AppType.caption.copyWith(color: color, fontSize: 12),
          ),
        ),
      ],
    );
  }
}

/// Shared loading, empty, and error card.
class StateCard extends StatelessWidget {
  const StateCard({
    super.key,
    required this.title,
    required this.body,
    this.icon = Icons.hourglass_empty_rounded,
    this.color = AppColors.accent,
    this.actionLabel,
    this.onAction,
    this.loading = false,
  });

  final String title;
  final String body;
  final IconData icon;
  final Color color;
  final String? actionLabel;
  final VoidCallback? onAction;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    return SurfaceCard(
      padding: const EdgeInsets.all(18),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          IconChip(icon: icon, color: color, size: 44, iconSize: 21),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: AppType.cardTitle),
                const SizedBox(height: 4),
                Text(body, style: AppType.note),
                if (loading) ...[
                  const SizedBox(height: 12),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(99),
                    child: LinearProgressIndicator(
                      minHeight: 4,
                      backgroundColor: AppColors.surfaceHigher,
                      valueColor: AlwaysStoppedAnimation(color),
                    ),
                  ),
                ],
                if (actionLabel != null && onAction != null) ...[
                  const SizedBox(height: 12),
                  FilledButton(
                    onPressed: onAction,
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 18,
                        vertical: 11,
                      ),
                    ),
                    child: Text(actionLabel!),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
