import 'package:flutter/material.dart';

class AppSpacing {
  AppSpacing._();

  static const xxs = 4.0;
  static const xs = 8.0;
  static const sm = 12.0;
  static const md = 16.0;
  static const lg = 20.0;
  static const xl = 24.0;
  static const xxl = 32.0;
  static const xxxl = 40.0;
  static const huge = 48.0;
}

class AppRadii {
  AppRadii._();

  static const small = 6.0;
  static const medium = 8.0;
  static const large = 10.0;
  static const dialog = 12.0;

  static const desktopBadge = 8.0;
  static const desktopControl = 13.0;
  static const desktopCard = 19.0;
  static const desktopHero = 28.0;
}

class AppBreakpoints {
  AppBreakpoints._();

  static const compact = 720.0;
  static const expanded = 1040.0;
  static const large = 1440.0;
  static const desktopRailCompact = 980.0;
}

class AppLayout {
  AppLayout._();

  static const desktopContentMaxWidth = 920.0;

  static EdgeInsets pagePadding(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final textScale = MediaQuery.textScalerOf(context).scale(1);
    if (Theme.of(context).platform == TargetPlatform.android ||
        width < AppBreakpoints.compact ||
        textScale >= 1.6) {
      return const EdgeInsets.all(AppSpacing.md);
    }
    if (width >= AppBreakpoints.large) {
      return const EdgeInsets.symmetric(
        horizontal: AppSpacing.xxl,
        vertical: AppSpacing.xl,
      );
    }
    return const EdgeInsets.all(AppSpacing.xl);
  }

  static bool useStackedLayout(
    BuildContext context, {
    double breakpoint = AppBreakpoints.expanded,
  }) {
    final width = MediaQuery.sizeOf(context).width;
    final textScale = MediaQuery.textScalerOf(context).scale(1);
    return width < breakpoint || textScale >= 1.6;
  }
}
