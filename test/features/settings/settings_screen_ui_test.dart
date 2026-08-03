import 'package:flutter/material.dart';
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
  testWidgets('save loading state keeps button size and visible progress',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();
    final notifier = _TestSettingsNotifier(SettingsRepository(preferences));
    await tester.binding.setSurfaceSize(const Size(900, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          settingsProvider.overrideWith((ref) => notifier),
        ],
        child: MaterialApp(
          locale: AppLocalizations.englishLocale,
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: AppLocalizations.delegates,
          theme: AppTheme.light,
          home: const SettingsScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final button = find.byKey(const Key('settingsSaveButton'));
    await tester.ensureVisible(button);
    await tester.pumpAndSettle();
    final buttonSize = tester.getSize(button);
    final labelSize = tester.getSize(
      find.byKey(const Key('settingsSaveLabelStack')),
    );
    expect(
      tester.getSize(find.byKey(const Key('settingsSaveIconSlot'))),
      const Size.square(24),
    );

    notifier.setSaving();
    await tester.pump();

    final indicatorFinder = find.byKey(
      const Key('settingsSavingIndicator'),
    );
    final indicator = tester.widget<CircularProgressIndicator>(
      indicatorFinder,
    );
    final theme = Theme.of(tester.element(indicatorFinder));
    expect(indicator.color, theme.colorScheme.onSurface);
    expect(tester.getSize(button), buttonSize);
    expect(
      tester.getSize(find.byKey(const Key('settingsSaveLabelStack'))),
      labelSize,
    );
  });

  testWidgets('Windows 桌面设置确认后只重置偏好并同步表单', (tester) async {
    SharedPreferences.setMockInitialValues({
      'privacy_notice.acknowledged.v1': true,
    });
    final preferences = await SharedPreferences.getInstance();
    final repository = SettingsRepository(preferences);
    await repository.save(
      const SettingsState(
        apiKey: 'desktop-secret',
        baseUrl: 'https://proxy.example/v1',
        sttModel: 'gpt-4o-transcribe',
        ttsModel: 'gpt-4o-mini-tts',
        themePreference: AppThemePreference.dark,
        localePreference: AppLocalePreference.english,
      ),
    );
    final notifier = SettingsNotifier(repository);
    await tester.binding.setSurfaceSize(const Size(1200, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          settingsProvider.overrideWith((ref) => notifier),
        ],
        child: MaterialApp(
          locale: AppLocalizations.englishLocale,
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: AppLocalizations.delegates,
          theme: AppTheme.light.copyWith(platform: TargetPlatform.windows),
          home: const SettingsScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final resetButton = find.byKey(
      const Key('resetLocalPreferencesButton'),
    );
    await tester.ensureVisible(resetButton);
    await tester.tap(resetButton);
    await tester.pumpAndSettle();
    expect(
      find.byKey(const Key('resetLocalPreferencesConfirmButton')),
      findsOneWidget,
    );

    await tester.tap(
      find.byKey(const Key('resetLocalPreferencesConfirmButton')),
    );
    await tester.pumpAndSettle();

    const defaults = SettingsState();
    expect(notifier.state.apiKey, defaults.apiKey);
    expect(notifier.state.baseUrl, defaults.baseUrl);
    expect(notifier.state.sttModel, defaults.sttModel);
    expect(notifier.state.ttsModel, defaults.ttsModel);
    expect(preferences.getBool('privacy_notice.acknowledged.v1'), isTrue);
    expect(
      tester
          .widget<TextFormField>(
            find.byKey(const Key('apiKeyField')),
          )
          .controller
          ?.text,
      isEmpty,
    );
    expect(
      tester
          .widget<TextFormField>(
            find.byKey(const Key('baseUrlField')),
          )
          .controller
          ?.text,
      defaults.baseUrl,
    );
  });
}

class _TestSettingsNotifier extends SettingsNotifier {
  _TestSettingsNotifier(super.repository);

  void setSaving() {
    state = state.copyWith(activeOperation: SettingsOperation.saving);
  }
}
