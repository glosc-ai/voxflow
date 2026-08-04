import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:voxflow/core/network/dio_client.dart';
import 'package:voxflow/core/theme/app_colors.dart';
import 'package:voxflow/core/theme/app_theme.dart';
import 'package:voxflow/features/settings/models/settings_state.dart';
import 'package:voxflow/features/settings/providers/settings_provider.dart';
import 'package:voxflow/features/stt/models/stt_state.dart';
import 'package:voxflow/features/stt/models/transcription_result.dart';
import 'package:voxflow/features/stt/providers/stt_provider.dart';
import 'package:voxflow/features/stt/services/audio_record_manager.dart';
import 'package:voxflow/features/stt/services/whisper_api_service.dart';
import 'package:voxflow/features/stt/views/stt_screen.dart';
import 'package:voxflow/features/stt/widgets/mobile_stt_workspace.dart';
import 'package:voxflow/l10n/app_localizations.dart';
import 'package:voxflow/widgets/mobile_design.dart';

void main() {
  testWidgets('Android STT handoff keeps the idle result preview at 200% text',
      (tester) async {
    final preferences = await _preferences();
    await tester.binding.setSurfaceSize(const Size(360, 640));
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(() async {
      await tester.binding.setSurfaceSize(null);
      tester.platformDispatcher.clearTextScaleFactorTestValue();
    });

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(preferences),
          sttProvider.overrideWith((ref) => _TestSttNotifier()),
        ],
        child: _testApp(const SttScreen()),
      ),
    );
    await tester.pump();

    expect(find.byType(AppBar), findsNothing);
    expect(find.text('Speech to text'), findsOneWidget);
    expect(find.text('Auto detect'), findsOneWidget);
    expect(find.text('Start recording'), findsOneWidget);
    expect(find.text('00:00.00'), findsOneWidget);
    expect(
      find.text(
        'Timestamped transcript segments will appear here after recording.',
      ),
      findsOneWidget,
    );
    expect(
      tester.getSize(find.byKey(const Key('startRecordingButton'))),
      const Size.square(120),
    );
    expect(find.byKey(const Key('mobileSttUploadZone')), findsOneWidget);
    expect(find.byKey(const Key('mobileSttTranscriptCard')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('mobile transcript switches formats and copies the real SRT',
      (tester) async {
    final preferences = await _preferences();
    const state = SttState(
      phase: SttPhase.success,
      elapsed: Duration(milliseconds: 3840),
      result: TranscriptionResult(
        text: 'Hello mobile',
        duration: Duration(milliseconds: 3840),
        segments: [
          TranscriptionSegment(
            start: Duration.zero,
            end: Duration(milliseconds: 3840),
            text: 'Hello mobile',
          ),
        ],
      ),
      editedText: 'Hello mobile',
    );
    final notifier = _TestSttNotifier(state);
    final controller = TextEditingController(text: state.editedText);
    addTearDown(controller.dispose);
    bool? exportedAsSrt;
    String? clipboardText;
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'Clipboard.setData') {
          clipboardText =
              (call.arguments as Map<Object?, Object?>)['text'] as String?;
        }
        return null;
      },
    );
    addTearDown(() {
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      );
    });

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(preferences),
          sttProvider.overrideWith((ref) => notifier),
        ],
        child: _testApp(
          Scaffold(
            body: MobileSttWorkspace(
              state: state,
              controller: controller,
              onExport: ({required isSrt}) async {
                exportedAsSrt = isSrt;
              },
              onNewTranscript: () async {},
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('00:00.00 → 00:03.84'), findsOneWidget);
    expect(find.text('Hello mobile'), findsWidgets);

    await tester.tap(find.text('SRT'));
    await tester.pump();
    expect(find.textContaining('00:00:00,000'), findsOneWidget);

    await tester.tap(find.byKey(const Key('mobileSttCopyButton')));
    await tester.pump();
    expect(clipboardText, contains('00:00:00,000 --> 00:00:03,840'));
    expect(clipboardText, contains('Hello mobile'));

    await tester.tap(find.byKey(const Key('mobileSttExportButton')));
    await tester.pump();
    expect(exportedAsSrt, isTrue);

    final editorExpander = find.byKey(
      const Key('mobileTranscriptEditorExpander'),
    );
    await tester.ensureVisible(editorExpander);
    await tester.tap(editorExpander);
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('transcriptionEditor')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Android Tab focus gives recorder and upload a 2px focus ring',
      (tester) async {
    final preferences = await _preferences();
    await tester.binding.setSurfaceSize(const Size(412, 892));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(preferences),
          sttProvider.overrideWith((ref) => _TestSttNotifier()),
        ],
        child: _testApp(const SttScreen()),
      ),
    );
    await tester.pump();

    final recorder = find.byKey(const Key('startRecordingButton'));
    await _tabUntilFocused(tester, recorder);
    final focusColor = tester.element(recorder).semanticColors.focus;
    final recorderDecoration =
        tester.widget<AnimatedContainer>(recorder).decoration! as BoxDecoration;
    final recorderBorder = recorderDecoration.border! as Border;
    expect(recorderBorder.top.color, focusColor);
    expect(recorderBorder.top.width, 2);
    expect(tester.getSize(recorder), const Size.square(120));

    final upload = find.byKey(const Key('mobileSttUploadZone'));
    await _tabUntilFocused(tester, upload);
    final uploadOutlineFinder = find.descendant(
      of: upload,
      matching: find.byType(MobileDashedOutline),
    );
    final uploadOutline =
        tester.widget<MobileDashedOutline>(uploadOutlineFinder);
    expect(uploadOutline.color, focusColor);
    expect(uploadOutline.strokeWidth, 2);
    expect(tester.getSize(upload).height, greaterThanOrEqualTo(48));
    expect(tester.takeException(), isNull);
  });

  testWidgets('mobile recorder exposes countdown recording pause and recovery',
      (tester) async {
    final preferences = await _preferences();
    final notifier = _TestSttNotifier();
    await tester.binding.setSurfaceSize(const Size(412, 892));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(preferences),
          sttProvider.overrideWith((ref) => notifier),
        ],
        child: _testApp(const SttScreen()),
      ),
    );
    await tester.pump();

    notifier.show(
      const SttState(phase: SttPhase.countdown, countdown: 3),
    );
    await tester.pump();
    expect(find.text('3'), findsOneWidget);
    expect(find.text('Preparing to record · tap to cancel'), findsOneWidget);

    notifier.show(
      const SttState(
        phase: SttPhase.recording,
        elapsed: Duration(milliseconds: 1250),
      ),
    );
    await tester.pump();
    expect(find.text('00:01.25'), findsOneWidget);
    expect(find.text('Recording · tap to stop'), findsOneWidget);
    expect(find.text('Pause'), findsOneWidget);

    notifier.show(
      const SttState(
        phase: SttPhase.paused,
        elapsed: Duration(milliseconds: 1250),
      ),
    );
    await tester.pump();
    expect(find.text('Recording paused · tap to finish'), findsOneWidget);
    expect(find.text('Resume'), findsOneWidget);

    notifier.show(
      const SttState(
        phase: SttPhase.failure,
        selectedFilePath: 'failed-recording.wav',
        selectedSourceIsTemporaryRecording: true,
        errorMessage: 'Test transcription failure.',
      ),
    );
    await tester.pump();
    expect(find.text('Test transcription failure.'), findsWidgets);
    expect(find.text('Retry this recording'), findsOneWidget);
    expect(find.text('Discard and start new'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('mobile transcript disables SRT without timestamped segments',
      (tester) async {
    final preferences = await _preferences();
    const state = SttState(
      phase: SttPhase.success,
      result: TranscriptionResult(
        text: 'Plain transcript',
        segments: [],
      ),
      editedText: 'Plain transcript',
    );
    final controller = TextEditingController(text: state.editedText);
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(preferences),
          sttProvider.overrideWith((ref) => _TestSttNotifier(state)),
        ],
        child: _testApp(
          Scaffold(
            body: MobileSttWorkspace(
              state: state,
              controller: controller,
              onExport: ({required isSrt}) async {},
              onNewTranscript: () async {},
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(
      find.text(
        'The service did not return timestamped segments, so SRT export is unavailable.',
      ),
      findsOneWidget,
    );
    final selector = tester.widget<SegmentedButton>(
      find.byKey(const Key('mobileSttFormatSelector')),
    );
    expect(selector.segments.last.enabled, isFalse);
    expect(
      selector.style?.minimumSize?.resolve(const <WidgetState>{}),
      const Size(48, 48),
    );
    expect(tester.takeException(), isNull);
  });
}

Future<SharedPreferences> _preferences() async {
  SharedPreferences.setMockInitialValues({});
  return SharedPreferences.getInstance();
}

Widget _testApp(Widget home) {
  return MaterialApp(
    locale: AppLocalizations.englishLocale,
    supportedLocales: AppLocalizations.supportedLocales,
    localizationsDelegates: AppLocalizations.delegates,
    theme: AppTheme.lightFor(TargetPlatform.android),
    builder: (context, child) => MediaQuery(
      data: MediaQuery.of(context).copyWith(disableAnimations: true),
      child: child!,
    ),
    home: home,
  );
}

Future<void> _tabUntilFocused(
  WidgetTester tester,
  Finder target, {
  int maxTabs = 20,
}) async {
  for (var index = 0; index < maxTabs; index++) {
    if (_primaryFocusIsWithin(target)) {
      return;
    }
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();
  }
  throw TestFailure('Tab focus did not reach $target.');
}

bool _primaryFocusIsWithin(Finder target) {
  final targetElements = target.evaluate().toList(growable: false);
  if (targetElements.length != 1) {
    return false;
  }
  final targetElement = targetElements.single;
  final focusContext = FocusManager.instance.primaryFocus?.context;
  if (focusContext == null) {
    return false;
  }
  if (identical(focusContext, targetElement)) {
    return true;
  }
  var within = false;
  focusContext.visitAncestorElements((element) {
    if (identical(element, targetElement)) {
      within = true;
      return false;
    }
    return true;
  });
  return within;
}

class _TestSttNotifier extends SttNotifier {
  _TestSttNotifier([SttState initial = const SttState()])
      : super(
          recorder: _SilentRecorder(),
          apiService: WhisperApiService(DioClient(const SettingsState())),
          historyWriter: (
              {required type, required text, required audioPath}) async {},
        ) {
    state = initial;
  }

  void show(SttState next) {
    state = next;
  }
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
  Future<void> start({bool requireWav = false}) async {}

  @override
  Future<File> stop() => throw UnimplementedError();
}
