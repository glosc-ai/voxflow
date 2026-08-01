import 'package:flutter/material.dart';

class AppColors {
  AppColors._();

  static const lightPrimary = Color(0xFF455BB8);
  static const lightOnPrimary = Color(0xFFFFFFFF);
  static const lightPrimaryContainer = Color(0xFFE2E6FF);
  static const lightOnPrimaryContainer = Color(0xFF18265D);
  static const lightCanvas = Color(0xFFF7F8FC);
  static const lightSurface = Color(0xFFFFFFFF);
  static const lightSurfaceSubtle = Color(0xFFF0F2F7);
  static const lightSurfaceSelected = Color(0xFFEAEDFF);
  static const lightTextPrimary = Color(0xFF191C20);
  static const lightTextSecondary = Color(0xFF5C626D);
  static const lightTextTertiary = Color(0xFF777E8A);
  static const lightBorder = Color(0xFFD9DEE8);
  static const lightBorderStrong = Color(0xFFAEB7C7);
  static const lightDivider = Color(0xFFE5E8EF);
  static const lightFocus = Color(0xFF315CE8);

  static const darkPrimary = Color(0xFFB9C4FF);
  static const darkOnPrimary = Color(0xFF14245E);
  static const darkPrimaryContainer = Color(0xFF2D3E87);
  static const darkOnPrimaryContainer = Color(0xFFE1E5FF);
  static const darkCanvas = Color(0xFF111318);
  static const darkSurface = Color(0xFF191C22);
  static const darkSurfaceSubtle = Color(0xFF21252D);
  static const darkSurfaceSelected = Color(0xFF293663);
  static const darkTextPrimary = Color(0xFFE5E8EF);
  static const darkTextSecondary = Color(0xFFB9C0CC);
  static const darkTextTertiary = Color(0xFF9098A5);
  static const darkBorder = Color(0xFF363C47);
  static const darkBorderStrong = Color(0xFF56606E);
  static const darkDivider = Color(0xFF2D323B);
  static const darkFocus = Color(0xFFAFC0FF);
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
    success: Color(0xFF18734A),
    successContainer: Color(0xFFE5F4EB),
    info: Color(0xFF2567A7),
    infoContainer: Color(0xFFE7F2FD),
    warning: Color(0xFF8A5C00),
    warningContainer: Color(0xFFFFF2D3),
    recording: Color(0xFFB42318),
    recordingContainer: Color(0xFFFEECEB),
    focus: AppColors.lightFocus,
    surfaceSubtle: AppColors.lightSurfaceSubtle,
    surfaceSelected: AppColors.lightSurfaceSelected,
    textTertiary: AppColors.lightTextTertiary,
    borderStrong: AppColors.lightBorderStrong,
  );

  static const dark = AppSemanticColors(
    success: Color(0xFF72D9A2),
    successContainer: Color(0xFF123526),
    info: Color(0xFF8DC8FF),
    infoContainer: Color(0xFF123554),
    warning: Color(0xFFF4C34F),
    warningContainer: Color(0xFF392B08),
    recording: Color(0xFFFFB4AB),
    recordingContainer: Color(0xFF591B18),
    focus: AppColors.darkFocus,
    surfaceSubtle: AppColors.darkSurfaceSubtle,
    surfaceSelected: AppColors.darkSurfaceSelected,
    textTertiary: AppColors.darkTextTertiary,
    borderStrong: AppColors.darkBorderStrong,
  );

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

extension AppThemeColors on BuildContext {
  AppSemanticColors get semanticColors {
    final theme = Theme.of(this);
    return theme.extension<AppSemanticColors>() ??
        (theme.brightness == Brightness.dark
            ? AppSemanticColors.dark
            : AppSemanticColors.light);
  }
}
