import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:voxflow/core/theme/app_theme.dart';
import 'package:voxflow/features/settings/providers/settings_provider.dart';
import 'package:voxflow/features/settings/services/settings_repository.dart';
import 'package:voxflow/features/settings/views/settings_screen.dart';
import 'package:voxflow/features/settings/widgets/masked_text_editing_controller.dart';
import 'package:voxflow/l10n/app_localizations.dart';

import '../../support/memory_api_key_store.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Windows API key field pastes and saves the complete value', (
    tester,
  ) async {
    const pastedValue = 'paste-sentinel-not-a-secret-42';
    final clipboard = _TestClipboard(pastedValue);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          SystemChannels.platform,
          clipboard.handleMethodCall,
        );
    addTearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, null);
    });

    await tester.binding.setSurfaceSize(const Size(1200, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();
    final apiKeyStore = MemoryApiKeyStore();
    final repository = SettingsRepository(preferences, apiKeyStore);
    final notifier = SettingsNotifier(repository);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [settingsProvider.overrideWith((ref) => notifier)],
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

    final apiKeyField = find.byKey(const Key('apiKeyField'));
    await tester.ensureVisible(apiKeyField);
    await tester.pumpAndSettle();
    await tester.tap(apiKeyField);
    await tester.pump();

    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyV);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    await tester.pumpAndSettle();

    final controller =
        tester.widget<TextFormField>(apiKeyField).controller!
            as MaskedTextEditingController;
    expect(
      controller.text,
      pastedValue,
      reason: 'Ctrl+V must paste the complete API key into the focused field.',
    );
    expect(controller.masked, isTrue);
    expect(
      controller
          .buildTextSpan(
            context: tester.element(apiKeyField),
            withComposing: false,
          )
          .toPlainText(),
      isNot(contains(pastedValue)),
    );
    final apiKeySemantics = tester
        .widget<Semantics>(find.byKey(const Key('apiKeySemantics')))
        .properties;
    expect(apiKeySemantics.obscured, isTrue);
    expect(apiKeySemantics.value, 'Entered');
    expect(apiKeySemantics.value, isNot(contains(pastedValue)));

    controller.clear();
    await tester.pump();
    await tester.tap(find.byKey(const Key('pasteApiKeyButton')));
    await tester.pumpAndSettle();
    expect(
      controller.text,
      pastedValue,
      reason: 'The paste button must support touch-only platforms as well.',
    );

    final saveButton = find.byKey(const Key('settingsSaveButton'));
    await tester.ensureVisible(saveButton);
    await tester.pumpAndSettle();
    await tester.tap(saveButton);
    await tester.pumpAndSettle();

    expect(repository.load().apiKey, pastedValue);
  });
}

class _TestClipboard {
  _TestClipboard(this.text);

  final String text;

  Future<Object?> handleMethodCall(MethodCall call) async {
    return switch (call.method) {
      'Clipboard.getData' => <String, Object?>{'text': text},
      'Clipboard.hasStrings' => <String, Object?>{'value': true},
      _ => null,
    };
  }
}
