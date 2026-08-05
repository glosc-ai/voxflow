import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:voxflow/core/network/dio_client.dart';
import 'package:voxflow/core/theme/app_spacing.dart';
import 'package:voxflow/core/theme/app_theme.dart';
import 'package:voxflow/features/settings/models/settings_state.dart';
import 'package:voxflow/features/settings/providers/settings_provider.dart';
import 'package:voxflow/features/stt/providers/stt_provider.dart';
import 'package:voxflow/features/stt/services/audio_record_manager.dart';
import 'package:voxflow/features/stt/services/whisper_api_service.dart';
import 'package:voxflow/features/stt/views/stt_screen.dart';
import 'package:voxflow/features/tts/providers/tts_provider.dart';
import 'package:voxflow/features/tts/services/audio_playback_manager.dart';
import 'package:voxflow/features/tts/services/tts_api_service.dart';
import 'package:voxflow/features/tts/views/tts_screen.dart';
import 'package:voxflow/l10n/app_localizations.dart';

const _desktopSize = Size(1200, 800);

void main() {
  testWidgets(
    'Windows STT page aligns the model selector to the content right',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      final preferences = await SharedPreferences.getInstance();
      await _setDesktopSurface(tester);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(preferences),
            sttProvider.overrideWith((ref) => _AlignmentSttNotifier()),
          ],
          child: _windowsApp(home: const SttScreen()),
        ),
      );
      await tester.pump();

      _expectSelectorAtContentRight(
        tester,
        find.byKey(const Key('desktopSttModelSelector')),
        contentAnchorFinder: find.byType(Divider),
      );
    },
  );

  testWidgets(
    'Windows TTS page aligns the model selector to the content right',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      final preferences = await SharedPreferences.getInstance();
      await _setDesktopSurface(tester);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(preferences),
            ttsProvider.overrideWith((ref) => _AlignmentTtsNotifier()),
          ],
          child: _windowsApp(home: const TtsScreen()),
        ),
      );
      await tester.pump();

      _expectSelectorAtContentRight(
        tester,
        find.byKey(const Key('desktopTtsModelSelector')),
        contentAnchorFinder: find.byKey(const Key('ttsTextField')),
      );
    },
  );
}

Future<void> _setDesktopSurface(WidgetTester tester) async {
  await tester.binding.setSurfaceSize(_desktopSize);
  addTearDown(() => tester.binding.setSurfaceSize(null));
}

Widget _windowsApp({required Widget home}) {
  return MaterialApp(
    locale: AppLocalizations.englishLocale,
    supportedLocales: AppLocalizations.supportedLocales,
    localizationsDelegates: AppLocalizations.delegates,
    theme: AppTheme.light.copyWith(platform: TargetPlatform.windows),
    home: home,
  );
}

void _expectSelectorAtContentRight(
  WidgetTester tester,
  Finder selectorFinder, {
  required Finder contentAnchorFinder,
}) {
  expect(selectorFinder, findsOneWidget);
  expect(contentAnchorFinder, findsOneWidget);
  final selector = tester.getRect(selectorFinder);
  final contentAnchor = tester.getRect(contentAnchorFinder);
  final contentRight =
      (_desktopSize.width + AppLayout.desktopContentMaxWidth) / 2;

  expect(
    contentAnchor.right,
    moreOrLessEquals(contentRight, epsilon: 1.5),
    reason: 'The desktop content column should retain its expected boundary.',
  );
  expect(
    selector.right,
    moreOrLessEquals(contentRight, epsilon: 0.5),
    reason:
        'The top model selector should end at the right edge of the '
        'centered desktop content column.',
  );
  expect(
    selector.center.dx,
    greaterThan(_desktopSize.width / 2 + AppSpacing.xxl),
    reason: 'The model selector must be right-aligned, not centered.',
  );
}

class _AlignmentSttNotifier extends SttNotifier {
  _AlignmentSttNotifier()
    : super(
        recorder: _SilentRecorder(),
        apiService: WhisperApiService(DioClient(const SettingsState())),
        historyWriter:
            ({required type, required text, required audioPath}) async {},
      );
}

class _AlignmentTtsNotifier extends TtsNotifier {
  _AlignmentTtsNotifier()
    : super(
        apiService: TtsApiService(DioClient(const SettingsState())),
        playback: const _SilentPlaybackController(),
        historyWriter: ({required text, required audioPath}) async {},
        model: 'tts-1',
      );
}

class _SilentRecorder implements AudioRecordManager {
  @override
  Future<void> cancel() async {}

  @override
  Future<void> dispose() async {}

  @override
  Future<void> pause() async {}

  @override
  Future<void> resume() async {}

  @override
  Future<void> start() async {}

  @override
  Future<File> stop() => throw UnimplementedError();
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
