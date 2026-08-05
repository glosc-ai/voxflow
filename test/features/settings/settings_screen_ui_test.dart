import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:voxflow/core/services/external_link_service.dart';
import 'package:voxflow/core/theme/app_theme.dart';
import 'package:voxflow/features/settings/models/settings_state.dart';
import 'package:voxflow/features/settings/providers/settings_provider.dart';
import 'package:voxflow/features/settings/services/settings_repository.dart';
import 'package:voxflow/features/settings/views/settings_screen.dart';
import 'package:voxflow/l10n/app_localizations.dart';

import '../../support/memory_api_key_store.dart';

void main() {
  for (final (name, platform, size) in [
    ('Windows desktop', TargetPlatform.windows, const Size(1200, 900)),
    ('Windows compact', TargetPlatform.windows, const Size(700, 900)),
    ('Android mobile', TargetPlatform.android, const Size(360, 720)),
  ]) {
    testWidgets('$name exposes irreversible full-data reset confirmation', (
      tester,
    ) async {
      SharedPreferences.setMockInitialValues({});
      final preferences = await SharedPreferences.getInstance();
      final repository = SettingsRepository(preferences, MemoryApiKeyStore());
      final notifier = SettingsNotifier(repository);
      await tester.binding.setSurfaceSize(size);
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        ProviderScope(
          overrides: [settingsProvider.overrideWith((ref) => notifier)],
          child: MaterialApp(
            locale: AppLocalizations.englishLocale,
            supportedLocales: AppLocalizations.supportedLocales,
            localizationsDelegates: AppLocalizations.delegates,
            theme: AppTheme.lightFor(platform),
            home: const SettingsScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Protected credential storage'), findsNothing);
      final getApiKeyButton = find.byKey(const Key('getApiKeyButton'));
      expect(getApiKeyButton, findsOneWidget);
      await tester.ensureVisible(getApiKeyButton);
      await tester.pumpAndSettle();
      expect(getApiKeyButton.hitTestable(), findsOneWidget);

      final resetButton = find.byKey(const Key('resetAllDataButton'));
      expect(resetButton, findsOneWidget);
      await tester.ensureVisible(resetButton);
      await tester.pumpAndSettle();
      expect(resetButton.hitTestable(), findsOneWidget);
      await tester.tap(resetButton);
      await tester.pumpAndSettle();

      expect(
        find.text(
          'This permanently deletes saved API credentials, settings, history, '
          'managed audio, diagnostic logs, and the privacy acknowledgement, '
          'returning the app to its initial state. Original imports and files '
          'saved elsewhere are not deleted. This cannot be undone.',
        ),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('resetAllDataConfirmButton')),
        findsOneWidget,
      );
    });

    testWidgets('$name keeps credential recovery guidance visible', (
      tester,
    ) async {
      SharedPreferences.setMockInitialValues({
        'settings.credentials_update_pending': true,
        'settings.base_url': 'https://provider.example/v1',
      });
      final preferences = await SharedPreferences.getInstance();
      final repository = SettingsRepository(
        preferences,
        MemoryApiKeyStore(initialValue: 'retained-secret'),
      );
      await repository.initialize();
      final notifier = SettingsNotifier(repository);
      await tester.binding.setSurfaceSize(size);
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        ProviderScope(
          overrides: [settingsProvider.overrideWith((ref) => notifier)],
          child: MaterialApp(
            locale: AppLocalizations.englishLocale,
            supportedLocales: AppLocalizations.supportedLocales,
            localizationsDelegates: AppLocalizations.delegates,
            theme: AppTheme.lightFor(platform),
            home: const SettingsScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.byKey(const Key('credentialRecoveryRequiredBanner')),
        findsOneWidget,
      );
      expect(find.text('API credential recovery required'), findsOneWidget);
    });
  }

  testWidgets('get API key opens the configured credential page', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();
    final notifier = SettingsNotifier(
      SettingsRepository(preferences, MemoryApiKeyStore()),
    );
    final externalLinks = _RecordingExternalLinkService();
    await tester.binding.setSurfaceSize(const Size(1200, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          settingsProvider.overrideWith((ref) => notifier),
          externalLinkServiceProvider.overrideWithValue(externalLinks),
        ],
        child: MaterialApp(
          locale: AppLocalizations.englishLocale,
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: AppLocalizations.delegates,
          theme: AppTheme.lightFor(TargetPlatform.windows),
          home: const SettingsScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final button = find.byKey(const Key('getApiKeyButton'));
    await tester.ensureVisible(button);
    await tester.pumpAndSettle();
    await tester.tap(button);
    await tester.pump();

    expect(externalLinks.openedUrls, ['https://www.glosc.ai/keys']);
  });

  testWidgets('save loading state keeps button size and visible progress', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();
    final notifier = _TestSettingsNotifier(
      SettingsRepository(preferences, MemoryApiKeyStore()),
    );
    await tester.binding.setSurfaceSize(const Size(900, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      ProviderScope(
        overrides: [settingsProvider.overrideWith((ref) => notifier)],
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

    final indicatorFinder = find.byKey(const Key('settingsSavingIndicator'));
    final indicator = tester.widget<CircularProgressIndicator>(indicatorFinder);
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
    final repository = SettingsRepository(preferences, MemoryApiKeyStore());
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
        overrides: [settingsProvider.overrideWith((ref) => notifier)],
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

    final resetButton = find.byKey(const Key('resetLocalPreferencesButton'));
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
          .widget<TextFormField>(find.byKey(const Key('apiKeyField')))
          .controller
          ?.text,
      isEmpty,
    );
    expect(
      tester
          .widget<TextFormField>(find.byKey(const Key('baseUrlField')))
          .controller
          ?.text,
      defaults.baseUrl,
    );
  });

  testWidgets('Android 设置按交付稿分组且 360×640 的 200% 字体无溢出', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();
    final repository = SettingsRepository(preferences, MemoryApiKeyStore());
    await repository.save(
      const SettingsState(
        apiKey: 'mobile-restricted-secret',
        baseUrl: 'https://proxy.example/v1',
        sttModel: 'gpt-4o-transcribe',
        ttsModel: 'gpt-4o-mini-tts',
      ),
    );
    final notifier = SettingsNotifier(repository);
    await tester.binding.setSurfaceSize(const Size(360, 640));
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(() async {
      await tester.binding.setSurfaceSize(null);
      tester.platformDispatcher.clearTextScaleFactorTestValue();
    });

    await tester.pumpWidget(
      ProviderScope(
        overrides: [settingsProvider.overrideWith((ref) => notifier)],
        child: MaterialApp(
          locale: AppLocalizations.simplifiedChineseLocale,
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: AppLocalizations.delegates,
          theme: AppTheme.lightFor(TargetPlatform.android),
          home: const SettingsScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('mobileSettingsScrollView')), findsOneWidget);
    expect(find.text('设置'), findsOneWidget);
    for (final key in const [
      ValueKey('mobileThemeOption:light'),
      ValueKey('mobileThemeOption:dark'),
      ValueKey('mobileThemeOption:system'),
      ValueKey('mobileLocaleOption:zhHans'),
      ValueKey('mobileLocaleOption:english'),
      ValueKey('mobileLocaleOption:system'),
    ]) {
      final option = find.byKey(key);
      expect(option, findsOneWidget);
      expect(tester.getSize(option).height, greaterThanOrEqualTo(48));
    }

    final sttSelector = find.byKey(const Key('sttModelField'));
    await tester.ensureVisible(sttSelector);
    await tester.pumpAndSettle();
    expect(tester.getSize(sttSelector).height, greaterThanOrEqualTo(48));

    final apiKey = find.byKey(const Key('apiKeySemantics'));
    await tester.ensureVisible(apiKey);
    await tester.pumpAndSettle();
    final apiKeySemantics = tester.widget<Semantics>(apiKey).properties;
    expect(apiKeySemantics.obscured, isTrue);
    expect(apiKeySemantics.value, '已填写');
    expect(apiKeySemantics.value, isNot(contains('mobile-restricted-secret')));

    for (final key in const [
      Key('fetchModelsButton'),
      Key('testConnectionButton'),
      Key('viewLogsButton'),
      Key('exportLogsButton'),
      Key('resetLocalPreferencesButton'),
      Key('settingsSaveButton'),
    ]) {
      final control = find.byKey(key);
      expect(control, findsOneWidget);
      await tester.ensureVisible(control);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    }
    expect(
      tester.getSize(find.byKey(const Key('settingsSaveButton'))).height,
      greaterThanOrEqualTo(48),
    );
  });

  testWidgets('Android 设置确认后安全重置本地偏好并保留隐私确认', (tester) async {
    SharedPreferences.setMockInitialValues({
      'privacy_notice.acknowledged.v1': true,
    });
    final preferences = await SharedPreferences.getInstance();
    final repository = SettingsRepository(preferences, MemoryApiKeyStore());
    await repository.save(
      const SettingsState(
        apiKey: 'mobile-secret',
        baseUrl: 'https://proxy.example/v1',
        sttModel: 'gpt-4o-transcribe',
        ttsModel: 'gpt-4o-mini-tts',
        themePreference: AppThemePreference.dark,
        localePreference: AppLocalePreference.english,
      ),
    );
    final notifier = SettingsNotifier(repository);
    await tester.binding.setSurfaceSize(const Size(360, 640));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      ProviderScope(
        overrides: [settingsProvider.overrideWith((ref) => notifier)],
        child: MaterialApp(
          locale: AppLocalizations.simplifiedChineseLocale,
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: AppLocalizations.delegates,
          theme: AppTheme.lightFor(TargetPlatform.android),
          home: const SettingsScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final resetButton = find.byKey(const Key('resetLocalPreferencesButton'));
    await tester.ensureVisible(resetButton);
    await tester.pumpAndSettle();
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
    expect(notifier.state.themePreference, defaults.themePreference);
    expect(notifier.state.localePreference, defaults.localePreference);
    expect(preferences.getBool('privacy_notice.acknowledged.v1'), isTrue);
    expect(
      tester
          .widget<TextFormField>(find.byKey(const Key('apiKeyField')))
          .controller
          ?.text,
      isEmpty,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('Android 模型选择与工作台实时同步并由显式保存保留', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();
    final repository = SettingsRepository(preferences, MemoryApiKeyStore());
    await repository.save(
      const SettingsState(
        apiKey: 'mobile-restricted-secret',
        baseUrl: 'https://proxy.example/v1',
      ),
    );
    final notifier = _TestSettingsNotifier(repository)..setFetchedModels();
    await tester.binding.setSurfaceSize(const Size(360, 720));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      ProviderScope(
        overrides: [settingsProvider.overrideWith((ref) => notifier)],
        child: MaterialApp(
          locale: AppLocalizations.simplifiedChineseLocale,
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: AppLocalizations.delegates,
          theme: AppTheme.lightFor(TargetPlatform.android),
          home: const SettingsScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final selector = find.byKey(const Key('sttModelField'));
    await tester.ensureVisible(selector);
    await tester.pumpAndSettle();
    await tester.tap(selector);
    await tester.pumpAndSettle();
    await tester.tap(find.text('gpt-4o-transcribe'));
    await tester.pumpAndSettle();

    expect(notifier.state.sttModel, 'gpt-4o-transcribe');
    expect(
      find.descendant(of: selector, matching: find.text('gpt-4o-transcribe')),
      findsOneWidget,
    );

    final saveButton = find.byKey(const Key('settingsSaveButton'));
    await tester.ensureVisible(saveButton);
    await tester.pumpAndSettle();
    await tester.tap(saveButton);
    await tester.pumpAndSettle();

    expect(repository.load().sttModel, 'gpt-4o-transcribe');
    expect(tester.takeException(), isNull);
  });
}

class _TestSettingsNotifier extends SettingsNotifier {
  _TestSettingsNotifier(super.repository);

  void setSaving() {
    state = state.copyWith(activeOperation: SettingsOperation.saving);
  }

  void setFetchedModels() {
    state = state.copyWith(
      availableSttModels: const ['whisper-1', 'gpt-4o-transcribe'],
      availableTtsModels: const ['tts-1', 'gpt-4o-mini-tts'],
      hasFetchedModels: true,
    );
  }
}

class _RecordingExternalLinkService extends ExternalLinkService {
  final openedUrls = <String>[];

  @override
  Future<void> open(String url) async {
    openedUrls.add(url);
  }
}
