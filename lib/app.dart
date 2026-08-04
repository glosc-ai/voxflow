import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/theme/app_theme.dart';
import 'l10n/app_localizations.dart';
import 'features/settings/views/privacy_notice_gate.dart';
import 'features/settings/models/settings_state.dart';
import 'features/settings/providers/settings_provider.dart';
import 'features/shell/views/app_shell.dart';

class VoxFlowApp extends ConsumerWidget {
  const VoxFlowApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final platform = defaultTargetPlatform;
    final reduceMotion = WidgetsBinding
        .instance.platformDispatcher.accessibilityFeatures.disableAnimations;
    final themePreference = ref.watch(
      settingsProvider.select((settings) => settings.themePreference),
    );
    final localePreference = ref.watch(
      settingsProvider.select((settings) => settings.localePreference),
    );
    return MaterialApp(
      onGenerateTitle: (context) => context.l10n.text(
        zh: '声流 VoxFlow',
        en: 'VoxFlow',
      ),
      debugShowCheckedModeBanner: false,
      locale: switch (localePreference) {
        AppLocalePreference.system => null,
        AppLocalePreference.zhHans => AppLocalizations.simplifiedChineseLocale,
        AppLocalePreference.english => AppLocalizations.englishLocale,
      },
      supportedLocales: AppLocalizations.supportedLocales,
      localeListResolutionCallback:
          AppLocalizations.localeListResolutionCallback,
      localizationsDelegates: AppLocalizations.delegates,
      theme: AppTheme.lightFor(platform),
      darkTheme: AppTheme.darkFor(platform),
      themeMode: switch (themePreference) {
        AppThemePreference.system => ThemeMode.system,
        AppThemePreference.light => ThemeMode.light,
        AppThemePreference.dark => ThemeMode.dark,
      },
      themeAnimationDuration:
          reduceMotion ? Duration.zero : const Duration(milliseconds: 200),
      themeAnimationCurve: Curves.ease,
      builder: (context, child) {
        if (platform != TargetPlatform.android) {
          return child!;
        }
        final brightness = Theme.of(context).brightness;
        final overlayBrightness =
            brightness == Brightness.dark ? Brightness.light : Brightness.dark;
        return AnnotatedRegion<SystemUiOverlayStyle>(
          value: SystemUiOverlayStyle(
            statusBarColor: Colors.transparent,
            statusBarIconBrightness: overlayBrightness,
            statusBarBrightness: brightness,
            systemNavigationBarColor: Colors.transparent,
            systemNavigationBarDividerColor: Colors.transparent,
            systemNavigationBarIconBrightness: overlayBrightness,
            systemNavigationBarContrastEnforced: false,
          ),
          child: child!,
        );
      },
      home: const PrivacyNoticeGate(child: AppShell()),
    );
  }
}
