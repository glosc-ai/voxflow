import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:voxflow/core/network/dio_client.dart';
import 'package:voxflow/core/theme/app_theme.dart';
import 'package:voxflow/features/history/models/history_record.dart';
import 'package:voxflow/features/history/providers/history_provider.dart';
import 'package:voxflow/features/history/services/history_repository.dart';
import 'package:voxflow/features/settings/models/settings_state.dart';
import 'package:voxflow/features/settings/providers/settings_provider.dart';
import 'package:voxflow/features/shell/views/app_shell.dart';
import 'package:voxflow/features/stt/models/stt_state.dart';
import 'package:voxflow/features/stt/providers/stt_provider.dart';
import 'package:voxflow/features/stt/services/audio_record_manager.dart';
import 'package:voxflow/features/stt/services/whisper_api_service.dart';
import 'package:voxflow/features/tts/providers/tts_provider.dart';
import 'package:voxflow/features/tts/services/audio_playback_manager.dart';
import 'package:voxflow/l10n/app_localizations.dart';

void main() {
  testWidgets('Windows 窄窗口仍使用紧凑侧边导航', (tester) async {
    await _pumpAppShell(
      tester,
      platform: TargetPlatform.windows,
      size: const Size(600, 900),
    );

    final rail = find.byKey(const Key('desktopNavigation'));
    expect(rail, findsOneWidget);
    expect(tester.getSize(rail).width, 76);
    expect(find.byKey(const Key('appBottomNavigation')), findsNothing);
    expect(find.byType(BottomNavigationBar), findsNothing);
  });

  testWidgets('Android 大屏和 200% 字体仍使用自定义底部导航', (tester) async {
    await _pumpAppShell(
      tester,
      platform: TargetPlatform.android,
      size: const Size(1200, 700),
      textScaleFactor: 2,
    );

    expect(find.byType(NavigationRail), findsNothing);
    expect(find.byType(BottomNavigationBar), findsNothing);
    expect(find.byKey(const Key('appBottomNavigation')), findsOneWidget);
    for (var index = 0; index < 4; index++) {
      final item = find.byKey(
        ValueKey('bottomNavigationDestination:$index'),
      );
      expect(item, findsOneWidget);
      expect(tester.getSize(item).height, greaterThanOrEqualTo(48));
      expect(
        find.descendant(of: item, matching: find.byType(Text)),
        findsOneWidget,
      );
    }
    expect(tester.takeException(), isNull);
  });

  testWidgets('全局导航后焦点进入新页面且页内快捷键仍可用', (tester) async {
    await _pumpAppShell(
      tester,
      platform: TargetPlatform.windows,
      size: const Size(1200, 800),
    );

    expect(_pageFocusNode(tester, 'sttPageFocus').hasPrimaryFocus, isTrue);

    await tester.tap(find.byIcon(Icons.settings_outlined));
    await tester.pumpAndSettle();
    expect(_selectedNavigationIndex(tester), 3);
    expect(
      _pageFocusNode(tester, 'settingsPageFocus').hasPrimaryFocus,
      isTrue,
    );
    expect(_pageFocusNode(tester, 'sttPageFocus').hasFocus, isFalse);

    await _sendControlShortcut(tester, LogicalKeyboardKey.digit3);
    expect(_selectedNavigationIndex(tester), 2);
    expect(
      _pageFocusNode(tester, 'historyPageFocus').hasPrimaryFocus,
      isTrue,
    );

    await _sendControlShortcut(tester, LogicalKeyboardKey.keyF);
    final searchField = tester.widget<TextField>(
      find.byKey(const Key('historySearchField')),
    );
    expect(searchField.focusNode?.hasFocus, isTrue);

    await _sendControlShortcut(tester, LogicalKeyboardKey.digit2);
    expect(_selectedNavigationIndex(tester), 1);
    expect(_pageFocusNode(tester, 'ttsPageFocus').hasPrimaryFocus, isTrue);
    expect(searchField.focusNode?.hasFocus, isFalse);

    await _sendControlShortcut(tester, LogicalKeyboardKey.digit3);
    await _sendControlShortcut(tester, LogicalKeyboardKey.keyF);
    expect(searchField.focusNode?.hasFocus, isTrue);
  });

  testWidgets('桌面页面往返保留 TTS 草稿与 IndexedStack 状态', (tester) async {
    await _pumpAppShell(
      tester,
      platform: TargetPlatform.windows,
      size: const Size(1200, 800),
    );

    await tester.tap(find.byIcon(Icons.record_voice_over_outlined));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('ttsTextField')),
      '保留这段尚未生成的桌面草稿',
    );

    await tester.tap(find.byIcon(Icons.history_outlined));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.record_voice_over_outlined));
    await tester.pumpAndSettle();

    expect(find.text('保留这段尚未生成的桌面草稿'), findsOneWidget);
  });

  testWidgets('桌面标题栏窗口按钮调用原生桥且关闭 hover 使用危险色', (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.windows;
    const channel = MethodChannel('ai.glosc.voxflow/window');
    final calls = <MethodCall>[];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
      calls.add(call);
      if (call.method == 'getVersion') {
        return '1.0.0+1';
      }
      if (call.method == 'isMaximized') {
        return false;
      }
      return null;
    });
    addTearDown(() {
      debugDefaultTargetPlatformOverride = null;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null);
    });

    await _pumpAppShell(
      tester,
      platform: TargetPlatform.windows,
      size: const Size(1200, 800),
    );

    expect(find.text('v1.0.0+1 · Windows'), findsOneWidget);
    for (final key in const [
      Key('windowMinimizeButton'),
      Key('windowMaximizeButton'),
      Key('windowCloseButton'),
    ]) {
      final buttonFinder = find.descendant(
        of: find.byKey(key),
        matching: find.byType(IconButton),
      );
      final button = tester.widget<IconButton>(buttonFinder);
      expect(button.onPressed, isNotNull);
      await tester.tap(find.byKey(key));
      await tester.pump();
    }

    final gesture = await tester.startGesture(
      tester.getCenter(find.byKey(const Key('desktopTitleBar'))),
    );
    await gesture.moveBy(const Offset(24, 0));
    await gesture.up();
    await tester.pump(const Duration(milliseconds: 400));

    expect(
        calls.map((call) => call.method),
        containsAll(<String>[
          'enableFrameless',
          'getVersion',
          'setBrightness',
          'minimize',
          'maximizeOrRestore',
          'close',
          'startDrag',
        ]));
    expect(
      calls.firstWhere((call) => call.method == 'setBrightness').arguments,
      'light',
    );

    final closeButton = tester.widget<IconButton>(
      find.descendant(
        of: find.byKey(const Key('windowCloseButton')),
        matching: find.byType(IconButton),
      ),
    );
    final context = tester.element(find.byKey(const Key('desktopShell')));
    expect(
      closeButton.style?.backgroundColor?.resolve({WidgetState.hovered}),
      Theme.of(context).colorScheme.error,
    );
    debugDefaultTargetPlatformOverride = null;
  });

  testWidgets('录音中离开 STT 必须确认，取消继续录音，确认后取消录音再导航', (tester) async {
    final recorder = _TrackingRecorder();
    final sttNotifier = _RecordingSttNotifier(recorder);
    await _pumpAppShell(
      tester,
      platform: TargetPlatform.windows,
      size: const Size(1200, 800),
      sttNotifier: sttNotifier,
    );

    await tester.tap(find.byIcon(Icons.record_voice_over_outlined));
    await tester.pumpAndSettle();

    expect(find.text('停止录音并离开？'), findsOneWidget);
    expect(_selectedNavigationIndex(tester), 0);
    expect(recorder.cancelCalls, 0);

    await tester.tap(find.text('取消'));
    await tester.pumpAndSettle();

    expect(_selectedNavigationIndex(tester), 0);
    expect(sttNotifier.state.phase, SttPhase.recording);
    expect(recorder.cancelCalls, 0);

    await _sendControlShortcut(tester, LogicalKeyboardKey.digit4);
    expect(find.text('停止录音并离开？'), findsOneWidget);
    expect(_selectedNavigationIndex(tester), 0);

    await tester.tap(find.byKey(const Key('leaveRecordingConfirmButton')));
    await tester.pumpAndSettle();

    expect(recorder.cancelCalls, 1);
    expect(sttNotifier.state.phase, SttPhase.idle);
    expect(_selectedNavigationIndex(tester), 3);
  });

  testWidgets('录音转录失败显示重试此录音操作', (tester) async {
    await _pumpAppShell(
      tester,
      platform: TargetPlatform.windows,
      size: const Size(1200, 800),
      sttNotifier: _FailedRecordingSttNotifier(_TrackingRecorder()),
    );

    expect(
      find.byKey(const Key('retrySelectedSttSourceButton')),
      findsOneWidget,
    );
    expect(find.text('重试此录音'), findsOneWidget);
  });
}

Future<void> _pumpAppShell(
  WidgetTester tester, {
  required TargetPlatform platform,
  required Size size,
  double textScaleFactor = 1,
  SttNotifier? sttNotifier,
}) async {
  SharedPreferences.setMockInitialValues({});
  final preferences = await SharedPreferences.getInstance();
  await tester.binding.setSurfaceSize(size);
  tester.platformDispatcher.textScaleFactorTestValue = textScaleFactor;
  addTearDown(() async {
    await tester.binding.setSurfaceSize(null);
    tester.platformDispatcher.clearTextScaleFactorTestValue();
  });

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(preferences),
        ttsPlaybackManagerProvider.overrideWithValue(
          const _SilentPlaybackController(),
        ),
        historyPlaybackManagerProvider.overrideWithValue(
          const _SilentPlaybackController(),
        ),
        historyRepositoryProvider.overrideWithValue(
          _MemoryHistoryRepository(),
        ),
        if (sttNotifier != null) sttProvider.overrideWith((ref) => sttNotifier),
      ],
      child: MaterialApp(
        locale: AppLocalizations.simplifiedChineseLocale,
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: AppLocalizations.delegates,
        theme: AppTheme.light.copyWith(platform: platform),
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(disableAnimations: true),
          child: child!,
        ),
        home: const AppShell(),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

FocusNode _pageFocusNode(WidgetTester tester, String key) {
  return tester
      .widget<Focus>(find.byKey(Key(key), skipOffstage: false))
      .focusNode!;
}

int? _selectedNavigationIndex(WidgetTester tester) {
  for (var index = 0; index < 4; index++) {
    if (find
        .byKey(
          ValueKey('desktopSelectedNavigationDestination:${index + 1}'),
          skipOffstage: false,
        )
        .evaluate()
        .isNotEmpty) {
      return index;
    }
  }
  return null;
}

Future<void> _sendControlShortcut(
  WidgetTester tester,
  LogicalKeyboardKey key,
) async {
  await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
  await tester.sendKeyEvent(key);
  await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
  await tester.pumpAndSettle();
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
  Future<void> setVolume(double volume) async {}

  @override
  Future<void> stop() async {}
}

class _MemoryHistoryRepository extends HistoryRepository {
  @override
  Future<void> close() async {}

  @override
  Future<void> delete(int id) async {}

  @override
  Future<HistoryRecord> insert(HistoryRecord record) async => record;

  @override
  Future<List<HistoryRecord>> search([String query = '']) async => const [];
}

class _RecordingSttNotifier extends SttNotifier {
  _RecordingSttNotifier(_TrackingRecorder recorder)
      : super(
          recorder: recorder,
          apiService: WhisperApiService(DioClient(const SettingsState())),
          historyWriter: (
              {required type, required text, required audioPath}) async {},
        ) {
    state = const SttState(phase: SttPhase.recording);
  }
}

class _FailedRecordingSttNotifier extends SttNotifier {
  _FailedRecordingSttNotifier(_TrackingRecorder recorder)
      : super(
          recorder: recorder,
          apiService: WhisperApiService(DioClient(const SettingsState())),
          historyWriter: (
              {required type, required text, required audioPath}) async {},
        ) {
    state = const SttState(
      phase: SttPhase.failure,
      selectedFilePath: 'recording.wav',
      selectedSourceIsTemporaryRecording: true,
      errorMessage: '转录失败',
    );
  }
}

class _TrackingRecorder implements AudioRecordManager {
  int cancelCalls = 0;

  @override
  Future<void> cancel() async {
    cancelCalls++;
  }

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
