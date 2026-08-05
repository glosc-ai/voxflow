import 'dart:ui' show SemanticsAction;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:voxflow/core/constants/app_constants.dart';
import 'package:voxflow/core/network/dio_client.dart';
import 'package:voxflow/core/theme/app_theme.dart';
import 'package:voxflow/features/settings/models/settings_state.dart';
import 'package:voxflow/features/settings/providers/settings_provider.dart';
import 'package:voxflow/features/tts/models/tts_state.dart';
import 'package:voxflow/features/tts/providers/tts_provider.dart';
import 'package:voxflow/features/tts/services/audio_playback_manager.dart';
import 'package:voxflow/features/tts/services/tts_api_service.dart';
import 'package:voxflow/features/tts/views/tts_screen.dart';
import 'package:voxflow/l10n/app_localizations.dart';

void main() {
  testWidgets('Android TTS uses the mobile handoff at 200% text scale', (
    tester,
  ) async {
    await _pumpTtsScreen(
      tester,
      locale: AppLocalizations.englishLocale,
      platform: TargetPlatform.android,
      textScaleFactor: 2,
    );

    expect(find.byType(AppBar), findsNothing);
    expect(find.byKey(const Key('mobileTtsWorkspace')), findsOneWidget);
    expect(find.byKey(const Key('mobileTtsInputCard')), findsOneWidget);
    expect(find.byKey(const Key('mobileVoiceList')), findsOneWidget);
    expect(find.text('Text to speech'), findsOneWidget);
    expect(find.text('Choose a voice'), findsOneWidget);
    final alloySemantics = tester.getSemantics(
      find.bySemanticsLabel('Alloy, Neutral · versatile'),
    );
    expect(
      alloySemantics.getSemanticsData().hasAction(SemanticsAction.tap),
      isTrue,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('large text keeps the full Seed TTS Speaker ID visible', (
    tester,
  ) async {
    await _pumpTtsScreen(
      tester,
      locale: AppLocalizations.englishLocale,
      platform: TargetPlatform.android,
      textScaleFactor: 2,
      notifier: _TestTtsNotifier(model: AppConstants.seedTtsModel),
    );

    const speakerId = 'zh_female_cancan_uranus_bigtts';
    final speaker = find.text(speakerId);
    final text = tester.widget<Text>(speaker);
    final card = find
        .ancestor(of: speaker, matching: find.byType(AnimatedContainer))
        .first;

    expect(text.maxLines, isNull);
    expect(text.overflow, TextOverflow.visible);
    expect(tester.getSize(card).width, greaterThanOrEqualTo(240));
    expect(tester.takeException(), isNull);
  });

  testWidgets('TTS clear confirmation is localized and keyboard-safe', (
    tester,
  ) async {
    await _pumpTtsScreen(
      tester,
      locale: AppLocalizations.englishLocale,
      platform: TargetPlatform.android,
      textScaleFactor: 2,
    );
    final textField = find.byKey(const Key('ttsTextField'));

    await tester.enterText(textField, 'Unsaved draft');
    final clearButton = find.byTooltip('Clear text');
    await tester.ensureVisible(clearButton);
    await tester.pumpAndSettle();
    await tester.tap(clearButton);
    await tester.pumpAndSettle();

    expect(find.text('Clear input text?'), findsOneWidget);
    expect(
      find.text(
        'Unsaved input will be permanently deleted and cannot be recovered. '
        'Generated or saved audio will not be affected.',
      ),
      findsOneWidget,
    );
    expect(find.text('Cancel'), findsOneWidget);
    expect(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.text('Clear'),
      ),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);

    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();

    expect(find.byType(AlertDialog), findsNothing);
    expect(_text(tester), 'Unsaved draft');

    await tester.ensureVisible(clearButton);
    await tester.pumpAndSettle();
    await tester.tap(clearButton);
    await tester.pumpAndSettle();
    final confirmButton = find.byKey(const Key('confirmClearTtsTextButton'));
    await tester.ensureVisible(confirmButton);
    await tester.tap(confirmButton);
    await tester.pumpAndSettle();

    expect(find.byType(AlertDialog), findsNothing);
    expect(_text(tester), isEmpty);
  });

  testWidgets('TTS clear confirmation provides Chinese copy', (tester) async {
    await _pumpTtsScreen(
      tester,
      locale: AppLocalizations.simplifiedChineseLocale,
      platform: TargetPlatform.android,
    );

    await tester.enterText(find.byKey(const Key('ttsTextField')), '未保存的草稿');
    final clearButton = find.byTooltip('清空文字');
    await tester.ensureVisible(clearButton);
    await tester.pumpAndSettle();
    await tester.tap(clearButton);
    await tester.pumpAndSettle();

    expect(find.text('清空输入文字？'), findsOneWidget);
    expect(find.text('未保存的输入将被永久删除且无法撤销。已生成或已保存的音频不会受影响。'), findsOneWidget);
    expect(find.text('取消'), findsOneWidget);
    expect(
      find.descendant(of: find.byType(AlertDialog), matching: find.text('清空')),
      findsOneWidget,
    );
  });

  testWidgets('generate button loading state keeps size and spinner contrast', (
    tester,
  ) async {
    final notifier = _TestTtsNotifier();
    await _pumpTtsScreen(
      tester,
      locale: AppLocalizations.englishLocale,
      platform: TargetPlatform.android,
      notifier: notifier,
    );

    final buttonFinder = find.byKey(const Key('synthesizeButton'));
    final labelStackFinder = find.byKey(const Key('ttsGenerateLabelStack'));
    final buttonSize = tester.getSize(buttonFinder);
    final labelStackSize = tester.getSize(labelStackFinder);
    expect(
      tester.getSize(find.byKey(const Key('ttsGenerateIconSlot'))),
      const Size.square(24),
    );

    notifier.setGenerating();
    await tester.pump();

    final indicatorFinder = find.byKey(const Key('ttsGeneratingIndicator'));
    final indicator = tester.widget<CircularProgressIndicator>(indicatorFinder);
    final indicatorContext = tester.element(indicatorFinder);
    final theme = Theme.of(indicatorContext);

    expect(indicator.color, theme.colorScheme.onSurface);
    expect(tester.getSize(buttonFinder), buttonSize);
    expect(tester.getSize(labelStackFinder), labelStackSize);
  });

  testWidgets('generated audio opens and dismisses the mobile player dock', (
    tester,
  ) async {
    await _pumpTtsScreen(
      tester,
      locale: AppLocalizations.englishLocale,
      platform: TargetPlatform.android,
      textScaleFactor: 2,
      notifier: _TestTtsNotifier(ready: true),
    );

    expect(find.byKey(const Key('mobileTtsPlayer')), findsOneWidget);
    expect(find.byTooltip('Save MP3'), findsOneWidget);
    expect(find.byTooltip('Close player'), findsOneWidget);
    expect(
      find.descendant(
        of: find.byKey(const Key('mobileTtsPlayer')),
        matching: find.text('1×'),
      ),
      findsOneWidget,
    );
    final rateButton = find.byKey(const Key('ttsPlaybackRateButton'));
    expect(tester.getSize(rateButton).height, greaterThanOrEqualTo(48));
    expect(
      tester.getSize(find.byKey(const Key('ttsWaveProgressHitTarget'))).height,
      greaterThanOrEqualTo(48),
    );

    await tester.tap(rateButton);
    await tester.pump();
    expect(
      find.descendant(
        of: find.byKey(const Key('mobileTtsPlayer')),
        matching: find.text('1.25×'),
      ),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);

    await tester.tap(find.byTooltip('Close player'));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('mobileTtsPlayer')), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('mobile player is unavailable while replacing existing audio', (
    tester,
  ) async {
    final notifier = _TestTtsNotifier(ready: true);
    await _pumpTtsScreen(
      tester,
      locale: AppLocalizations.englishLocale,
      platform: TargetPlatform.android,
      notifier: notifier,
    );
    expect(find.byKey(const Key('mobileTtsPlayer')), findsOneWidget);

    notifier.setGenerating();
    await tester.pump();

    expect(notifier.state.hasAudio, isTrue);
    expect(find.byKey(const Key('mobileTtsPlayer')), findsNothing);
  });
}

Future<void> _pumpTtsScreen(
  WidgetTester tester, {
  required Locale locale,
  required TargetPlatform platform,
  double textScaleFactor = 1,
  _TestTtsNotifier? notifier,
}) async {
  SharedPreferences.setMockInitialValues({});
  final preferences = await SharedPreferences.getInstance();
  debugDefaultTargetPlatformOverride = platform;
  await tester.binding.setSurfaceSize(const Size(360, 640));
  tester.platformDispatcher.textScaleFactorTestValue = textScaleFactor;
  addTearDown(() async {
    await tester.binding.setSurfaceSize(null);
    tester.platformDispatcher.clearTextScaleFactorTestValue();
  });

  try {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(preferences),
          ttsProvider.overrideWith((ref) => notifier ?? _TestTtsNotifier()),
        ],
        child: MaterialApp(
          locale: locale,
          supportedLocales: AppLocalizations.supportedLocales,
          localeListResolutionCallback:
              AppLocalizations.localeListResolutionCallback,
          localizationsDelegates: AppLocalizations.delegates,
          theme: AppTheme.light,
          home: const TtsScreen(),
        ),
      ),
    );
  } finally {
    debugDefaultTargetPlatformOverride = null;
  }
  if (notifier?.state.isGenerating ?? false) {
    await tester.pump();
  } else {
    await tester.pumpAndSettle();
  }
}

String _text(WidgetTester tester) {
  return tester
      .widget<TextField>(find.byKey(const Key('ttsTextField')))
      .controller!
      .text;
}

class _TestTtsNotifier extends TtsNotifier {
  _TestTtsNotifier({
    bool generating = false,
    bool ready = false,
    super.model = 'tts-1',
  }) : super(
         apiService: TtsApiService(DioClient(const SettingsState())),
         playback: const _SilentPlaybackController(),
         historyWriter: ({required text, required audioPath}) async {},
       ) {
    if (generating) {
      state = const TtsState(phase: TtsPhase.generating);
    } else if (ready) {
      state = const TtsState(
        phase: TtsPhase.ready,
        audioPath: 'generated.mp3',
        duration: Duration(seconds: 12),
        position: Duration(seconds: 2),
      );
    }
  }

  void setGenerating() {
    state = state.copyWith(phase: TtsPhase.generating);
  }
}

class _SilentPlaybackController implements PlaybackController {
  const _SilentPlaybackController();

  @override
  Stream<void> get completions => const Stream.empty();

  @override
  Stream<Duration> get durationChanges => const Stream.empty();

  @override
  Stream<Duration> get positionChanges => const Stream.empty();

  @override
  Future<void> load(String path) async {}

  @override
  Future<void> pause() async {}

  @override
  Future<void> play() async {}

  @override
  Future<void> seek(Duration position) async {}

  @override
  Future<void> setPlaybackRate(double rate) async {}

  @override
  Future<void> setVolume(double volume) async {}

  @override
  Future<void> stop() async {}
}
