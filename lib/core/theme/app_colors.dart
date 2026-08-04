import 'package:flutter/material.dart';

class AppColors {
  AppColors._();

  // Windows and Android share the handoff palette. The desktop-prefixed
  // constants remain explicit because the native desktop shell consumes them
  // directly, while the unprefixed constants feed Android's Material theme.
  static const desktopLightAccent = Color(0xFF5D5FEF);
  static const desktopLightOnAccent = Color(0xFFFFFFFF);
  static const desktopLightCanvas = Color(0xFFF8F9FA);
  static const desktopLightSurface = Color(0xFFFFFFFF);
  static const desktopLightTextPrimary = Color(0xFF0F172A);
  static const desktopLightTextSecondary = Color(0xFF64748B);
  static const desktopLightBorder = Color(0xFFE2E8F0);
  static const desktopLightBorderStrong = Color(0xFFCBD5E1);
  static const desktopLightSurfaceSelected = Color(0xFFEFEFFD);
  static const desktopLightSuccess = Color(0xFF10B981);
  static const desktopLightDanger = Color(0xFFEF4444);

  static const desktopDarkAccent = Color(0xFF6366F1);
  static const desktopDarkOnAccent = Color(0xFFF8FAFC);
  static const desktopDarkCanvas = Color(0xFF121316);
  static const desktopDarkSurface = Color(0xFF1E1F23);
  static const desktopDarkTextPrimary = Color(0xFFF8FAFC);
  static const desktopDarkTextSecondary = Color(0xFF94A3B8);
  static const desktopDarkBorder = Color(0xFF2E3038);
  static const desktopDarkBorderStrong = Color(0xFF454854);
  static const desktopDarkSurfaceSelected = Color(0xFF282840);
  static const desktopDarkSuccess = Color(0xFF34D399);
  static const desktopDarkDanger = Color(0xFFF87171);

  static const lightPrimary = Color(0xFF5D5FEF);
  static const lightOnPrimary = Color(0xFFFFFFFF);
  static const lightPrimaryContainer = Color(0xFFEFEFFD);
  static const lightOnPrimaryContainer = Color(0xFF5D5FEF);
  static const lightCanvas = Color(0xFFF8F9FA);
  static const lightSurface = Color(0xFFFFFFFF);
  static const lightSurfaceSubtle = Color(0xFFF8F9FA);
  static const lightSurfaceSelected = Color(0xFFEFEFFD);
  static const lightTextPrimary = Color(0xFF0F172A);
  static const lightTextSecondary = Color(0xFF64748B);
  static const lightTextTertiary = Color(0xFF64748B);
  static const lightBorder = Color(0xFFE2E8F0);
  static const lightBorderStrong = Color(0xFFCBD5E1);
  static const lightDivider = Color(0xFFE2E8F0);
  static const lightFocus = Color(0xFF5D5FEF);
  static const lightSuccess = Color(0xFF10B981);
  static const lightDanger = Color(0xFFEF4444);

  static const darkPrimary = Color(0xFF6366F1);
  static const darkOnPrimary = Color(0xFFF8FAFC);
  static const darkPrimaryContainer = Color(0xFF282840);
  static const darkOnPrimaryContainer = Color(0xFFC7D2FE);
  static const darkCanvas = Color(0xFF121316);
  static const darkSurface = Color(0xFF1E1F23);
  static const darkSurfaceSubtle = Color(0xFF2B2C30);
  static const darkSurfaceSelected = Color(0xFF282840);
  static const darkTextPrimary = Color(0xFFF8FAFC);
  static const darkTextSecondary = Color(0xFF94A3B8);
  static const darkTextTertiary = Color(0xFF94A3B8);
  static const darkBorder = Color(0xFF2E3038);
  static const darkBorderStrong = Color(0xFF454854);
  static const darkDivider = Color(0xFF2E3038);
  static const darkFocus = Color(0xFFA5B4FC);
  static const darkSuccess = Color(0xFF34D399);
  static const darkDanger = Color(0xFFF87171);
}

@immutable
class AppSemanticColors extends ThemeExtension<AppSemanticColors> {
  const AppSemanticColors({
    required this.success,
    required this.successContainer,
    required this.info,
    required this.infoContainer,
    required this.warning,
    required this.warningContainer,
    required this.recording,
    required this.recordingContainer,
    required this.focus,
    required this.surfaceSubtle,
    required this.surfaceSelected,
    required this.textTertiary,
    required this.borderStrong,
  });

  static const light = AppSemanticColors(
    success: AppColors.lightSuccess,
    successContainer: Color(0xFFE7F8F2),
    info: Color(0xFF5D5FEF),
    infoContainer: Color(0xFFEFEFFD),
    warning: Color(0xFF9A6700),
    warningContainer: Color(0xFFFFF4D6),
    recording: AppColors.lightSuccess,
    recordingContainer: Color(0xFFE7F8F2),
    focus: AppColors.lightFocus,
    surfaceSubtle: AppColors.lightSurfaceSubtle,
    surfaceSelected: AppColors.lightSurfaceSelected,
    textTertiary: AppColors.lightTextTertiary,
    borderStrong: AppColors.lightBorderStrong,
  );

  static const dark = AppSemanticColors(
    success: AppColors.darkSuccess,
    successContainer: Color(0xFF23402F),
    info: Color(0xFFA5B4FC),
    infoContainer: Color(0xFF282840),
    warning: Color(0xFFF6C453),
    warningContainer: Color(0xFF40351C),
    recording: AppColors.darkSuccess,
    recordingContainer: Color(0xFF23402F),
    focus: AppColors.darkFocus,
    surfaceSubtle: AppColors.darkSurfaceSubtle,
    surfaceSelected: AppColors.darkSurfaceSelected,
    textTertiary: AppColors.darkTextTertiary,
    borderStrong: AppColors.darkBorderStrong,
  );

  static const desktopLight = AppSemanticColors(
    success: AppColors.desktopLightSuccess,
    successContainer: Color(0xFFE7F8F2),
    info: AppColors.desktopLightAccent,
    infoContainer: Color(0xFFEFEFFD),
    warning: Color(0xFF9A6700),
    warningContainer: Color(0xFFFFF4D6),
    recording: AppColors.desktopLightSuccess,
    recordingContainer: Color(0xFFE7F8F2),
    focus: AppColors.desktopLightAccent,
    surfaceSubtle: AppColors.desktopLightCanvas,
    surfaceSelected: AppColors.desktopLightSurfaceSelected,
    textTertiary: AppColors.desktopLightTextSecondary,
    borderStrong: AppColors.desktopLightBorderStrong,
  );

  static const desktopDark = AppSemanticColors(
    success: AppColors.desktopDarkSuccess,
    successContainer: Color(0xFF23402F),
    info: Color(0xFFA5B4FC),
    infoContainer: AppColors.desktopDarkSurfaceSelected,
    warning: Color(0xFFF6C453),
    warningContainer: Color(0xFF40351C),
    recording: AppColors.desktopDarkSuccess,
    recordingContainer: Color(0xFF23402F),
    focus: Color(0xFFA5B4FC),
    surfaceSubtle: Color(0xFF2B2C30),
    surfaceSelected: AppColors.desktopDarkSurfaceSelected,
    textTertiary: AppColors.desktopDarkTextSecondary,
    borderStrong: AppColors.desktopDarkBorderStrong,
  );

  static const mobileLight = desktopLight;
  static const mobileDark = desktopDark;

  final Color success;
  final Color successContainer;
  final Color info;
  final Color infoContainer;
  final Color warning;
  final Color warningContainer;
  final Color recording;
  final Color recordingContainer;
  final Color focus;
  final Color surfaceSubtle;
  final Color surfaceSelected;
  final Color textTertiary;
  final Color borderStrong;

  @override
  AppSemanticColors copyWith({
    Color? success,
    Color? successContainer,
    Color? info,
    Color? infoContainer,
    Color? warning,
    Color? warningContainer,
    Color? recording,
    Color? recordingContainer,
    Color? focus,
    Color? surfaceSubtle,
    Color? surfaceSelected,
    Color? textTertiary,
    Color? borderStrong,
  }) {
    return AppSemanticColors(
      success: success ?? this.success,
      successContainer: successContainer ?? this.successContainer,
      info: info ?? this.info,
      infoContainer: infoContainer ?? this.infoContainer,
      warning: warning ?? this.warning,
      warningContainer: warningContainer ?? this.warningContainer,
      recording: recording ?? this.recording,
      recordingContainer: recordingContainer ?? this.recordingContainer,
      focus: focus ?? this.focus,
      surfaceSubtle: surfaceSubtle ?? this.surfaceSubtle,
      surfaceSelected: surfaceSelected ?? this.surfaceSelected,
      textTertiary: textTertiary ?? this.textTertiary,
      borderStrong: borderStrong ?? this.borderStrong,
    );
  }

  @override
  AppSemanticColors lerp(
    covariant AppSemanticColors? other,
    double t,
  ) {
    if (other == null) {
      return this;
    }
    return AppSemanticColors(
      success: Color.lerp(success, other.success, t)!,
      successContainer:
          Color.lerp(successContainer, other.successContainer, t)!,
      info: Color.lerp(info, other.info, t)!,
      infoContainer: Color.lerp(infoContainer, other.infoContainer, t)!,
      warning: Color.lerp(warning, other.warning, t)!,
      warningContainer:
          Color.lerp(warningContainer, other.warningContainer, t)!,
      recording: Color.lerp(recording, other.recording, t)!,
      recordingContainer:
          Color.lerp(recordingContainer, other.recordingContainer, t)!,
      focus: Color.lerp(focus, other.focus, t)!,
      surfaceSubtle: Color.lerp(surfaceSubtle, other.surfaceSubtle, t)!,
      surfaceSelected: Color.lerp(surfaceSelected, other.surfaceSelected, t)!,
      textTertiary: Color.lerp(textTertiary, other.textTertiary, t)!,
      borderStrong: Color.lerp(borderStrong, other.borderStrong, t)!,
    );
  }
}

@immutable
class AppSurfaceEffects extends ThemeExtension<AppSurfaceEffects> {
  const AppSurfaceEffects({
    required this.cardShadow,
    required this.floatingShadow,
    required this.glassOpacity,
  });

  static const flat = AppSurfaceEffects(
    cardShadow: BoxShadow(color: Colors.transparent),
    floatingShadow: BoxShadow(color: Colors.transparent),
    glassOpacity: 1,
  );

  static const desktopLight = AppSurfaceEffects(
    cardShadow: BoxShadow(
      color: Color(0x0A0F172A),
      offset: Offset(0, 4),
      blurRadius: 16,
    ),
    floatingShadow: BoxShadow(
      color: Color(0x140F172A),
      offset: Offset(0, 8),
      blurRadius: 32,
    ),
    glassOpacity: 0.78,
  );

  static const desktopDark = AppSurfaceEffects(
    cardShadow: BoxShadow(
      color: Color(0x3D000000),
      offset: Offset(0, 4),
      blurRadius: 16,
    ),
    floatingShadow: BoxShadow(
      color: Color(0x6B000000),
      offset: Offset(0, 12),
      blurRadius: 40,
    ),
    glassOpacity: 0.74,
  );

  static const mobileLight = desktopLight;
  static const mobileDark = desktopDark;

  final BoxShadow cardShadow;
  final BoxShadow floatingShadow;
  final double glassOpacity;

  @override
  AppSurfaceEffects copyWith({
    BoxShadow? cardShadow,
    BoxShadow? floatingShadow,
    double? glassOpacity,
  }) {
    return AppSurfaceEffects(
      cardShadow: cardShadow ?? this.cardShadow,
      floatingShadow: floatingShadow ?? this.floatingShadow,
      glassOpacity: glassOpacity ?? this.glassOpacity,
    );
  }

  @override
  AppSurfaceEffects lerp(
    covariant AppSurfaceEffects? other,
    double t,
  ) {
    if (other == null) {
      return this;
    }
    return AppSurfaceEffects(
      cardShadow: BoxShadow.lerp(cardShadow, other.cardShadow, t)!,
      floatingShadow: BoxShadow.lerp(floatingShadow, other.floatingShadow, t)!,
      glassOpacity: glassOpacity + (other.glassOpacity - glassOpacity) * t,
    );
  }
}

extension AppThemeColors on BuildContext {
  AppSemanticColors get semanticColors {
    final theme = Theme.of(this);
    return theme.extension<AppSemanticColors>() ??
        (theme.brightness == Brightness.dark
            ? AppSemanticColors.dark
            : AppSemanticColors.light);
  }

  AppSurfaceEffects get surfaceEffects =>
      Theme.of(this).extension<AppSurfaceEffects>() ?? AppSurfaceEffects.flat;
}
