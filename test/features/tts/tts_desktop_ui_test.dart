import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
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
  testWidgets('desktop TTS dock adapts at 200% text without overflow',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();
    final notifier = _ReadyTtsNotifier();
    await tester.binding.setSurfaceSize(const Size(1200, 800));
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(() async {
      await tester.binding.setSurfaceSize(null);
      tester.platformDispatcher.clearTextScaleFactorTestValue();
    });

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(preferences),
          ttsProvider.overrideWith((ref) => notifier),
        ],
        child: MaterialApp(
          locale: AppLocalizations.englishLocale,
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: AppLocalizations.delegates,
          theme: AppTheme.light.copyWith(platform: TargetPlatform.windows),
          home: const TtsScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('ttsTextField')), findsOneWidget);
    expect(find.byTooltip('Close player'), findsOneWidget);
    expect(find.byTooltip('Save MP3'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.enterText(
      find.byKey(const Key('ttsTextField')),
      'Draft retained across provider updates',
    );
    notifier.setVoice('echo');
    await tester.pump();
    expect(
      tester
          .widget<TextField>(find.byKey(const Key('ttsTextField')))
          .controller!
          .text,
      'Draft retained across provider updates',
    );

    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(find.byTooltip('Close player'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}

class _ReadyTtsNotifier extends TtsNotifier {
  _ReadyTtsNotifier()
      : super(
          apiService: TtsApiService(DioClient(const SettingsState())),
          playback: const _SilentPlaybackController(),
          historyWriter: ({required text, required audioPath}) async {},
          model: 'tts-1',
        ) {
    state = const TtsState(
      phase: TtsPhase.ready,
      audioPath: 'generated.mp3',
      duration: Duration(seconds: 12),
      position: Duration(seconds: 2),
    );
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
