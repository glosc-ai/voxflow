import 'package:flutter/material.dart';
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
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: switch (themePreference) {
        AppThemePreference.system => ThemeMode.system,
        AppThemePreference.light => ThemeMode.light,
        AppThemePreference.dark => ThemeMode.dark,
      },
      themeAnimationDuration: const Duration(milliseconds: 160),
      themeAnimationCurve: Curves.easeOutCubic,
      home: const PrivacyNoticeGate(child: AppShell()),
    );
  }
}
