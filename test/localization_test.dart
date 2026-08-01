import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:voxflow/core/theme/app_theme.dart';
import 'package:voxflow/features/settings/models/settings_state.dart';
import 'package:voxflow/features/settings/providers/settings_provider.dart';
import 'package:voxflow/features/settings/services/settings_repository.dart';
import 'package:voxflow/features/settings/views/settings_screen.dart';
import 'package:voxflow/l10n/app_localizations.dart';

void main() {
  test('system locale resolves every Chinese variant to simplified Chinese',
      () {
    expect(
      AppLocalizations.resolveLocale(const Locale('zh', 'TW')),
      AppLocalizations.simplifiedChineseLocale,
    );
    expect(
      AppLocalizations.resolveLocale(const Locale('zh', 'HK')),
      AppLocalizations.simplifiedChineseLocale,
    );
    expect(
      AppLocalizations.resolveLocale(const Locale('fr', 'FR')),
      AppLocalizations.englishLocale,
    );
  });

  test('system locale scans supported preferences and preserves English region',
      () {
    expect(
      AppLocalizations.localeListResolutionCallback(
        const [Locale('ja', 'JP'), Locale('zh', 'CN')],
        AppLocalizations.supportedLocales,
      ),
      AppLocalizations.simplifiedChineseLocale,
    );
    expect(
      AppLocalizations.localeListResolutionCallback(
        const [Locale('en', 'GB')],
        AppLocalizations.supportedLocales,
      ),
      const Locale('en', 'GB'),
    );
  });

  testWidgets('official framework localizations expose Chinese control labels',
      (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        locale: AppLocalizations.simplifiedChineseLocale,
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: AppLocalizations.delegates,
        home: SizedBox(),
      ),
    );

    final context = tester.element(find.byType(SizedBox));
    expect(MaterialLocalizations.of(context).popupMenuLabel, '弹出菜单');
    expect(
      GlobalMaterialLocalizations.delegate.isSupported(
        AppLocalizations.simplifiedChineseLocale,
      ),
      isTrue,
    );
  });

  testWidgets('language changes immediately and persists', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();
    final repository = SettingsRepository(preferences);
    await repository.save(
      const SettingsState(localePreference: AppLocalePreference.zhHans),
    );
    await tester.binding.setSurfaceSize(const Size(900, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(preferences),
        ],
        child: const _LocalizedSettingsHarness(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('设置'), findsOneWidget);
    final localeField = find.byKey(
      const ValueKey('localePreference:zhHans'),
    );
    await tester.ensureVisible(localeField);
    await tester.tap(localeField);
    await tester.pumpAndSettle();
    await tester.tap(find.text('English').last);
    await tester.pumpAndSettle();

    expect(find.text('Settings'), findsOneWidget);
    expect(
      tester.widget<MaterialApp>(find.byType(MaterialApp)).locale,
      AppLocalizations.englishLocale,
    );
    expect(
      repository.load().localePreference,
      AppLocalePreference.english,
    );
  });

  testWidgets('English settings supports 360x640 at 200% text scale',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();
    await SettingsRepository(preferences).save(
      const SettingsState(localePreference: AppLocalePreference.english),
    );
    await tester.binding.setSurfaceSize(const Size(360, 640));
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(() {
      tester.binding.setSurfaceSize(null);
      tester.platformDispatcher.clearTextScaleFactorTestValue();
    });

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(preferences),
        ],
        child: const _LocalizedSettingsHarness(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Settings'), findsOneWidget);
    expect(
        find.text('Connection, models, and local diagnostics'), findsOneWidget);
    expect(find.text('Appearance and language'), findsOneWidget);
    expect(
      tester.getSize(find.byType(AppBar)).height,
      greaterThanOrEqualTo(tester.getSize(find.text('Settings')).height + 16),
    );
    expect(tester.takeException(), isNull);

    var apiKeySemantics = tester.widget<Semantics>(
      find.byKey(const Key('apiKeySemantics')),
    );
    expect(apiKeySemantics.properties.textField, isTrue);
    expect(apiKeySemantics.properties.readOnly, isFalse);
    expect(apiKeySemantics.properties.obscured, isTrue);
    expect(apiKeySemantics.properties.customSemanticsActions, hasLength(1));
    expect(
      apiKeySemantics.properties.customSemanticsActions!.keys.single.label,
      'Show API key',
    );

    apiKeySemantics.properties.customSemanticsActions!.values.single();
    await tester.pump();
    apiKeySemantics = tester.widget<Semantics>(
      find.byKey(const Key('apiKeySemantics')),
    );
    expect(apiKeySemantics.properties.obscured, isFalse);
    expect(
      apiKeySemantics.properties.customSemanticsActions!.keys.single.label,
      'Hide API key',
    );
    expect(tester.takeException(), isNull);
  });
}

class _LocalizedSettingsHarness extends ConsumerWidget {
  const _LocalizedSettingsHarness();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final preference = ref.watch(
      settingsProvider.select((settings) => settings.localePreference),
    );
    return MaterialApp(
      locale: switch (preference) {
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
      home: const SettingsScreen(),
    );
  }
}
