import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/material.dart';

import '../core/theme/app_colors.dart';
import '../core/theme/app_spacing.dart';
import '../core/theme/app_typography.dart';

/// Shared presentation primitives for the Android handoff.
///
/// These widgets intentionally contain no feature state. They keep the four
/// mobile workspaces visually consistent while desktop pages retain their
/// existing, feature-specific presentation.
class MobileLayout {
  MobileLayout._();

  static const horizontalPadding = 16.0;
  static const topPadding = 10.0;
  static const bottomNavigationClearance = 118.0;
  static const playerBottom = 96.0;

  static double bottomClearance(BuildContext context) {
    final systemBottom = MediaQuery.viewPaddingOf(context).bottom;
    final scaffoldBottom = MediaQuery.paddingOf(context).bottom;
    return math.max(
      bottomNavigationClearance + systemBottom,
      scaffoldBottom + 16,
    );
  }

  static EdgeInsets pagePadding(BuildContext context) => EdgeInsets.fromLTRB(
    horizontalPadding,
    topPadding,
    horizontalPadding,
    bottomClearance(context),
  );
}

class MobileMotion {
  MobileMotion._();

  static const standard = Duration(milliseconds: 200);
  static const entrance = Duration(milliseconds: 260);
  static const entranceCurve = Cubic(0.2, 0.8, 0.2, 1);

  static Duration duration(BuildContext context, [Duration value = standard]) {
    return MediaQuery.disableAnimationsOf(context) ? Duration.zero : value;
  }
}

class MobileViewHeader extends StatelessWidget {
  const MobileViewHeader({
    super.key,
    required this.eyebrow,
    required this.title,
    this.accessories = const <Widget>[],
  });

  final String eyebrow;
  final String title;
  final List<Widget> accessories;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: 10, bottom: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            eyebrow.toUpperCase(),
            style: AppTypography.numeric(theme.textTheme.labelSmall).copyWith(
              color: theme.colorScheme.primary,
              fontSize: 10.5,
              height: 1.35,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.9,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            title,
            style: theme.textTheme.headlineMedium?.copyWith(
              fontSize: 24,
              height: 1.25,
              fontWeight: FontWeight.w600,
              letterSpacing: -0.48,
            ),
          ),
          if (accessories.isNotEmpty) ...[
            const SizedBox(height: 12),
            Wrap(spacing: 8, runSpacing: 8, children: accessories),
          ],
        ],
      ),
    );
  }
}

class MobileSurfaceCard extends StatelessWidget {
  const MobileSurfaceCard({
    super.key,
    required this.child,
    this.padding,
    this.radius = AppRadii.mobileCard,
    this.color,
    this.borderColor,
    this.borderWidth = 1,
    this.shadow = true,
    this.clipBehavior = Clip.antiAlias,
  });

  final Widget child;
  final EdgeInsetsGeometry? padding;
  final double radius;
  final Color? color;
  final Color? borderColor;
  final double borderWidth;
  final bool shadow;
  final Clip clipBehavior;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final effects = context.surfaceEffects;
    return AnimatedContainer(
      duration: MobileMotion.duration(context),
      curve: Curves.ease,
      decoration: BoxDecoration(
        color: color ?? colors.surface,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(
          color: borderColor ?? colors.outlineVariant,
          width: borderWidth,
        ),
        boxShadow: shadow ? [effects.cardShadow] : null,
      ),
      clipBehavior: clipBehavior,
      child: padding == null ? child : Padding(padding: padding!, child: child),
    );
  }
}

class MobilePill extends StatelessWidget {
  const MobilePill({
    super.key,
    required this.label,
    this.icon,
    this.foregroundColor,
    this.backgroundColor,
    this.borderColor,
  });

  final String label;
  final IconData? icon;
  final Color? foregroundColor;
  final Color? backgroundColor;
  final Color? borderColor;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final foreground = foregroundColor ?? colors.onSurfaceVariant;
    return AnimatedContainer(
      duration: MobileMotion.duration(context),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: backgroundColor ?? colors.surface,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: borderColor ?? colors.outlineVariant),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 13, color: foreground),
            const SizedBox(width: 6),
          ],
          Flexible(
            child: Text(
              label,
              overflow: TextOverflow.ellipsis,
              style: AppTypography.numeric(
                Theme.of(context).textTheme.labelSmall,
              ).copyWith(color: foreground, fontSize: 11),
            ),
          ),
        ],
      ),
    );
  }
}

class MobileSectionLabel extends StatelessWidget {
  const MobileSectionLabel({super.key, required this.title, this.meta});

  final String title;
  final String? meta;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(2, 22, 2, 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: Text(
              title,
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                fontSize: 14.5,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          if (meta != null) ...[
            const SizedBox(width: AppSpacing.sm),
            Flexible(
              child: Text(
                meta!,
                textAlign: TextAlign.end,
                style:
                    AppTypography.numeric(
                      Theme.of(context).textTheme.labelSmall,
                    ).copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                      fontSize: 10.5,
                    ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class MobileDashedOutline extends StatelessWidget {
  const MobileDashedOutline({
    super.key,
    required this.child,
    this.radius = AppRadii.mobileControl,
    this.color,
    this.strokeWidth = 1.5,
    this.padding = const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
  });

  final Widget child;
  final double radius;
  final Color? color;
  final double strokeWidth;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      foregroundPainter: _DashedRoundedRectPainter(
        color: color ?? Theme.of(context).colorScheme.outlineVariant,
        radius: radius,
        strokeWidth: strokeWidth,
      ),
      child: Padding(padding: padding, child: child),
    );
  }
}

class _DashedRoundedRectPainter extends CustomPainter {
  const _DashedRoundedRectPainter({
    required this.color,
    required this.radius,
    required this.strokeWidth,
  });

  final Color color;
  final double radius;
  final double strokeWidth;

  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()
      ..addRRect(
        RRect.fromRectAndRadius(Offset.zero & size, Radius.circular(radius)),
      );
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round
      ..color = color;
    for (final metric in path.computeMetrics()) {
      var distance = 0.0;
      while (distance < metric.length) {
        canvas.drawPath(metric.extractPath(distance, distance + 6), paint);
        distance += 10;
      }
    }
  }

  @override
  bool shouldRepaint(covariant _DashedRoundedRectPainter oldDelegate) {
    return oldDelegate.color != color ||
        oldDelegate.radius != radius ||
        oldDelegate.strokeWidth != strokeWidth;
  }
}

class MobileGlassSurface extends StatelessWidget {
  const MobileGlassSurface({
    super.key,
    required this.child,
    this.radius = 24,
    this.padding,
  });

  final Widget child;
  final double radius;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final effects = context.surfaceEffects;
    final borderRadius = BorderRadius.circular(radius);
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: borderRadius,
        boxShadow: [effects.floatingShadow],
      ),
      child: ClipRRect(
        borderRadius: borderRadius,
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: AnimatedContainer(
            duration: MobileMotion.duration(context),
            curve: Curves.ease,
            padding: padding,
            decoration: BoxDecoration(
              color: colors.surface.withValues(alpha: effects.glassOpacity),
              borderRadius: borderRadius,
              border: Border.all(color: colors.outlineVariant),
            ),
            child: child,
          ),
        ),
      ),
    );
  }
}
