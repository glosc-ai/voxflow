import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:voxflow/core/network/dio_client.dart';
import 'package:voxflow/core/theme/app_theme.dart';
import 'package:voxflow/features/settings/models/settings_state.dart';
import 'package:voxflow/features/settings/providers/settings_provider.dart';
import 'package:voxflow/features/stt/models/stt_state.dart';
import 'package:voxflow/features/stt/models/transcription_result.dart';
import 'package:voxflow/features/stt/providers/stt_provider.dart';
import 'package:voxflow/features/stt/services/audio_record_manager.dart';
import 'package:voxflow/features/stt/services/whisper_api_service.dart';
import 'package:voxflow/features/stt/views/stt_screen.dart';
import 'package:voxflow/l10n/app_localizations.dart';

void main() {
  testWidgets('desktop Space shortcut does not capture the transcript editor', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();
    final notifier = _ShortcutSttNotifier();
    await tester.binding.setSurfaceSize(const Size(1000, 820));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(preferences),
          sttProvider.overrideWith((ref) => notifier),
        ],
        child: MaterialApp(
          locale: AppLocalizations.englishLocale,
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: AppLocalizations.delegates,
          theme: AppTheme.light.copyWith(platform: TargetPlatform.windows),
          home: const SttScreen(),
        ),
      ),
    );
    await tester.pump();

    final editor = find.byKey(const Key('transcriptionEditor'));
    await tester.ensureVisible(editor);
    await tester.tap(editor);
    await tester.pump();
    expect(
      tester.widget<TextField>(editor).focusNode?.hasFocus ??
          FocusManager.instance.primaryFocus != null,
      isTrue,
    );

    await tester.sendKeyEvent(LogicalKeyboardKey.space);
    await tester.pump();
    expect(notifier.stopCalls, 0);

    await tester.enterText(editor, 'Edited desktop draft');
    notifier.tick();
    await tester.pump();
    expect(
      tester.widget<TextField>(editor).controller!.text,
      'Edited desktop draft',
    );
  });

  testWidgets('desktop STT supports 200% text without overflow', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();
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
          sttProvider.overrideWith((ref) => _IdleSttNotifier()),
        ],
        child: MaterialApp(
          locale: AppLocalizations.englishLocale,
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: AppLocalizations.delegates,
          theme: AppTheme.light.copyWith(platform: TargetPlatform.windows),
          home: const SttScreen(),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('Speech to text'), findsOneWidget);
    expect(
      find.text(
        'Timestamped transcript segments will appear here after recording.',
      ),
      findsOneWidget,
    );
    expect(find.byKey(const Key('startRecordingButton')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

class _ShortcutSttNotifier extends SttNotifier {
  _ShortcutSttNotifier()
    : super(
        recorder: _SilentRecorder(),
        apiService: WhisperApiService(DioClient(const SettingsState())),
        historyWriter:
            ({required type, required text, required audioPath}) async {},
      ) {
    state = const SttState(
      phase: SttPhase.paused,
      result: TranscriptionResult(
        text: 'Editable transcript',
        segments: [
          TranscriptionSegment(
            start: Duration.zero,
            end: Duration(seconds: 1),
            text: 'Editable transcript',
          ),
        ],
      ),
      editedText: 'Editable transcript',
    );
  }

  int stopCalls = 0;

  @override
  Future<void> stopRecording() async {
    stopCalls++;
  }

  void tick() {
    state = state.copyWith(elapsed: const Duration(seconds: 4));
  }
}

class _IdleSttNotifier extends SttNotifier {
  _IdleSttNotifier()
    : super(
        recorder: _SilentRecorder(),
        apiService: WhisperApiService(DioClient(const SettingsState())),
        historyWriter:
            ({required type, required text, required audioPath}) async {},
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
