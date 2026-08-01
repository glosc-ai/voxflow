import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';

import 'app_colors.dart';
import 'app_spacing.dart';

class AppTheme {
  AppTheme._();

  static const double androidAppBarHeight = 56;
  static const double windowsAppBarHeight = 64;

  static ThemeData get light => _theme(Brightness.light);
  static ThemeData get dark => _theme(Brightness.dark);

  /// Keeps the platform toolbar baseline while allowing accessibility text to
  /// grow instead of being clipped by a fixed-height [AppBar].
  static double responsiveAppBarHeight(
    BuildContext context, {
    int largeTextMaxLines = 1,
  }) {
    assert(largeTextMaxLines > 0);
    final theme = Theme.of(context);
    final baseHeight = theme.platform == TargetPlatform.android
        ? androidAppBarHeight
        : windowsAppBarHeight;
    final titleStyle = theme.appBarTheme.titleTextStyle ??
        theme.textTheme.headlineSmall ??
        const TextStyle(fontSize: 24, height: 32 / 24);
    final fontSize = titleStyle.fontSize ?? 24;
    final scaledFontSize = MediaQuery.textScalerOf(context).scale(fontSize);
    final scale = scaledFontSize / fontSize;
    final lineCount = scale >= 1.6 ? largeTextMaxLines : 1;
    final lineHeight = scaledFontSize * (titleStyle.height ?? 1);
    final contentHeight = lineHeight * lineCount + AppSpacing.md;
    return contentHeight > baseHeight ? contentHeight : baseHeight;
  }

  static ThemeData _theme(Brightness brightness) {
    final isDark = brightness == Brightness.dark;
    final isAndroid = defaultTargetPlatform == TargetPlatform.android;
    final controlHeight = isAndroid ? 48.0 : 40.0;
    final colors = _colorScheme(brightness);
    final semantics = isDark ? AppSemanticColors.dark : AppSemanticColors.light;
    final textTheme = _textTheme(colors.onSurface);
    const shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.all(Radius.circular(AppRadii.medium)),
    );

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: colors,
      scaffoldBackgroundColor:
          isDark ? AppColors.darkCanvas : AppColors.lightCanvas,
      canvasColor: isDark ? AppColors.darkSurface : AppColors.lightSurface,
      fontFamilyFallback: const [
        'Segoe UI Variable',
        'Segoe UI',
        'Microsoft YaHei UI',
        'Roboto',
        'Noto Sans CJK SC',
      ],
      textTheme: textTheme,
      extensions: [semantics],
      visualDensity: VisualDensity.standard,
      materialTapTargetSize: MaterialTapTargetSize.padded,
      splashFactory: InkRipple.splashFactory,
      appBarTheme: AppBarTheme(
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        toolbarHeight: isAndroid ? androidAppBarHeight : windowsAppBarHeight,
        backgroundColor: Colors.transparent,
        foregroundColor: colors.onSurface,
        surfaceTintColor: Colors.transparent,
        titleTextStyle: textTheme.headlineSmall,
        actionsPadding: const EdgeInsets.only(right: AppSpacing.md),
      ),
      cardTheme: CardThemeData(
        margin: EdgeInsets.zero,
        elevation: 0,
        color: colors.surface,
        surfaceTintColor: Colors.transparent,
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadii.large),
          side: BorderSide(color: colors.outlineVariant),
        ),
      ),
      dividerTheme: DividerThemeData(
        color: colors.outlineVariant,
        thickness: 1,
        space: 1,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: colors.surface,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.sm,
        ),
        labelStyle: textTheme.bodyMedium?.copyWith(
          color: colors.onSurfaceVariant,
        ),
        hintStyle: textTheme.bodyMedium?.copyWith(
          color: semantics.textTertiary,
        ),
        helperStyle: textTheme.bodySmall,
        errorStyle: textTheme.bodySmall?.copyWith(color: colors.error),
        border: _inputBorder(colors.outline),
        enabledBorder: _inputBorder(colors.outline),
        focusedBorder: _inputBorder(colors.primary, width: 2),
        errorBorder: _inputBorder(colors.error),
        focusedErrorBorder: _inputBorder(colors.error, width: 2),
        disabledBorder: _inputBorder(colors.outlineVariant),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: Size(0, controlHeight),
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.xs,
          ),
          shape: shape,
          textStyle: textTheme.labelLarge,
        ).copyWith(
          side: WidgetStateProperty.resolveWith(
            (states) => states.contains(WidgetState.focused)
                ? BorderSide(color: semantics.focus, width: 2)
                : BorderSide.none,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: Size(0, controlHeight),
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.xs,
          ),
          shape: shape,
          textStyle: textTheme.labelLarge,
        ).copyWith(
          side: WidgetStateProperty.resolveWith(
            (states) => states.contains(WidgetState.focused)
                ? BorderSide(color: semantics.focus, width: 2)
                : BorderSide(color: colors.outline),
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          minimumSize: Size(controlHeight, controlHeight),
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
          shape: shape,
          textStyle: textTheme.labelLarge,
        ).copyWith(
          side: WidgetStateProperty.resolveWith(
            (states) => states.contains(WidgetState.focused)
                ? BorderSide(color: semantics.focus, width: 2)
                : BorderSide.none,
          ),
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          minimumSize: Size.square(controlHeight),
          iconSize: 20,
          shape: shape,
        ).copyWith(
          side: WidgetStateProperty.resolveWith(
            (states) => states.contains(WidgetState.focused)
                ? BorderSide(color: semantics.focus, width: 2)
                : BorderSide.none,
          ),
        ),
      ),
      navigationRailTheme: NavigationRailThemeData(
        backgroundColor: colors.surface,
        elevation: 0,
        minWidth: 72,
        minExtendedWidth: 232,
        useIndicator: true,
        indicatorColor: colors.primaryContainer,
        indicatorShape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadii.medium),
        ),
        selectedIconTheme: IconThemeData(color: colors.primary, size: 24),
        unselectedIconTheme:
            IconThemeData(color: colors.onSurfaceVariant, size: 24),
        selectedLabelTextStyle: textTheme.labelLarge?.copyWith(
          color: colors.primary,
          fontWeight: FontWeight.w600,
        ),
        unselectedLabelTextStyle: textTheme.labelLarge?.copyWith(
          color: colors.onSurfaceVariant,
        ),
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        elevation: 0,
        type: BottomNavigationBarType.fixed,
        backgroundColor: colors.surface,
        selectedItemColor: colors.primary,
        unselectedItemColor: colors.onSurfaceVariant,
        selectedLabelStyle: textTheme.bodySmall?.copyWith(
          fontWeight: FontWeight.w600,
        ),
        unselectedLabelStyle: textTheme.bodySmall,
        showUnselectedLabels: true,
      ),
      dialogTheme: DialogThemeData(
        elevation: 8,
        backgroundColor: colors.surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadii.dialog),
        ),
        titleTextStyle: textTheme.titleLarge,
        contentTextStyle: textTheme.bodyMedium,
        actionsPadding: const EdgeInsets.fromLTRB(
          AppSpacing.xl,
          AppSpacing.xs,
          AppSpacing.xl,
          AppSpacing.xl,
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor:
            isDark ? const Color(0xFF30343D) : const Color(0xFF292C33),
        contentTextStyle: textTheme.bodyMedium?.copyWith(color: Colors.white),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadii.medium),
        ),
      ),
      sliderTheme: SliderThemeData(
        activeTrackColor: colors.primary,
        inactiveTrackColor: colors.outlineVariant,
        thumbColor: colors.primary,
        overlayColor: colors.primary.withValues(alpha: 0.12),
        showValueIndicator: ShowValueIndicator.onlyForDiscrete,
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: colors.primary,
        linearTrackColor: colors.primaryContainer,
        circularTrackColor: colors.primaryContainer,
      ),
      tooltipTheme: TooltipThemeData(
        waitDuration: const Duration(milliseconds: 500),
        textStyle: textTheme.bodySmall?.copyWith(
          color: isDark ? AppColors.darkTextPrimary : Colors.white,
        ),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF30343D) : const Color(0xFF292C33),
          borderRadius: BorderRadius.circular(AppRadii.small),
        ),
      ),
      focusColor: semantics.focus.withValues(alpha: 0.16),
      hoverColor: colors.primary.withValues(alpha: 0.04),
      highlightColor: colors.primary.withValues(alpha: 0.08),
    );
  }

  static ColorScheme _colorScheme(Brightness brightness) {
    final isDark = brightness == Brightness.dark;
    return ColorScheme(
      brightness: brightness,
      primary: isDark ? AppColors.darkPrimary : AppColors.lightPrimary,
      onPrimary: isDark ? AppColors.darkOnPrimary : AppColors.lightOnPrimary,
      primaryContainer: isDark
          ? AppColors.darkPrimaryContainer
          : AppColors.lightPrimaryContainer,
      onPrimaryContainer: isDark
          ? AppColors.darkOnPrimaryContainer
          : AppColors.lightOnPrimaryContainer,
      secondary: isDark ? const Color(0xFFBBC6D1) : const Color(0xFF4F616D),
      onSecondary: isDark ? const Color(0xFF25313A) : Colors.white,
      secondaryContainer:
          isDark ? const Color(0xFF3B4852) : const Color(0xFFD3E5F2),
      onSecondaryContainer:
          isDark ? const Color(0xFFD7E4EE) : const Color(0xFF263640),
      tertiary: isDark ? const Color(0xFFC6C0DC) : const Color(0xFF625B71),
      onTertiary: isDark ? const Color(0xFF302D41) : Colors.white,
      error: isDark ? const Color(0xFFFFB4AB) : const Color(0xFFB3261E),
      onError: isDark ? const Color(0xFF690005) : Colors.white,
      errorContainer:
          isDark ? const Color(0xFF591B18) : const Color(0xFFFCE8E6),
      onErrorContainer:
          isDark ? const Color(0xFFFFDAD6) : const Color(0xFF601410),
      surface: isDark ? AppColors.darkSurface : AppColors.lightSurface,
      onSurface:
          isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
      onSurfaceVariant:
          isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
      outline:
          isDark ? AppColors.darkBorderStrong : AppColors.lightBorderStrong,
      outlineVariant: isDark ? AppColors.darkBorder : AppColors.lightBorder,
      shadow: Colors.black,
      scrim: isDark ? Colors.black : AppColors.darkCanvas,
      inverseSurface:
          isDark ? AppColors.lightTextPrimary : AppColors.darkTextPrimary,
      onInverseSurface: isDark ? AppColors.lightSurface : AppColors.darkSurface,
      inversePrimary: isDark ? AppColors.lightPrimary : AppColors.darkPrimary,
      surfaceTint: Colors.transparent,
      surfaceContainerLowest: isDark ? const Color(0xFF0C0E12) : Colors.white,
      surfaceContainerLow:
          isDark ? AppColors.darkCanvas : AppColors.lightCanvas,
      surfaceContainer: isDark ? AppColors.darkSurface : AppColors.lightSurface,
      surfaceContainerHigh:
          isDark ? AppColors.darkSurfaceSubtle : AppColors.lightSurfaceSubtle,
      surfaceContainerHighest:
          isDark ? const Color(0xFF272B34) : const Color(0xFFE9ECF2),
    );
  }

  static TextTheme _textTheme(Color color) {
    return TextTheme(
      displaySmall: TextStyle(
        fontSize: 32,
        height: 1.25,
        fontWeight: FontWeight.w600,
        color: color,
      ),
      headlineSmall: TextStyle(
        fontSize: 24,
        height: 32 / 24,
        fontWeight: FontWeight.w600,
        color: color,
      ),
      titleLarge: TextStyle(
        fontSize: 20,
        height: 28 / 20,
        fontWeight: FontWeight.w600,
        color: color,
      ),
      titleMedium: TextStyle(
        fontSize: 18,
        height: 26 / 18,
        fontWeight: FontWeight.w600,
        color: color,
      ),
      titleSmall: TextStyle(
        fontSize: 16,
        height: 1.5,
        fontWeight: FontWeight.w600,
        color: color,
      ),
      bodyLarge: TextStyle(
        fontSize: 16,
        height: 1.5,
        fontWeight: FontWeight.w400,
        color: color,
      ),
      bodyMedium: TextStyle(
        fontSize: 14,
        height: 22 / 14,
        fontWeight: FontWeight.w400,
        color: color,
      ),
      bodySmall: TextStyle(
        fontSize: 12,
        height: 1.5,
        fontWeight: FontWeight.w400,
        color: color,
      ),
      labelLarge: TextStyle(
        fontSize: 13,
        height: 20 / 13,
        fontWeight: FontWeight.w500,
        color: color,
      ),
      labelMedium: TextStyle(
        fontSize: 12,
        height: 1.5,
        fontWeight: FontWeight.w500,
        color: color,
      ),
    );
  }

  static OutlineInputBorder _inputBorder(Color color, {double width = 1}) {
    return OutlineInputBorder(
      borderRadius: BorderRadius.circular(AppRadii.medium),
      borderSide: BorderSide(color: color, width: width),
    );
  }
}
