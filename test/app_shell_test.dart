import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:voxflow/core/errors/app_exception.dart';
import 'package:voxflow/core/network/dio_client.dart';
import 'package:voxflow/core/theme/app_spacing.dart';
import 'package:voxflow/core/theme/app_theme.dart';
import 'package:voxflow/features/history/models/history_record.dart';
import 'package:voxflow/features/history/providers/history_provider.dart';
import 'package:voxflow/features/history/services/history_repository.dart';
import 'package:voxflow/features/settings/models/settings_state.dart';
import 'package:voxflow/features/settings/providers/application_data_reset_provider.dart';
import 'package:voxflow/features/settings/providers/settings_provider.dart';
import 'package:voxflow/features/settings/services/settings_repository.dart';
import 'package:voxflow/features/shell/views/app_shell.dart';
import 'package:voxflow/features/stt/models/stt_state.dart';
import 'package:voxflow/features/stt/providers/stt_provider.dart';
import 'package:voxflow/features/stt/services/audio_record_manager.dart';
import 'package:voxflow/features/stt/services/whisper_api_service.dart';
import 'package:voxflow/features/tts/models/tts_state.dart';
import 'package:voxflow/features/tts/providers/tts_provider.dart';
import 'package:voxflow/features/tts/services/audio_playback_manager.dart';
import 'package:voxflow/features/tts/services/tts_api_service.dart';
import 'package:voxflow/l10n/app_localizations.dart';

import 'support/memory_api_key_store.dart';

void main() {
  testWidgets('Windows 启动时自动检查已保存 API 并更新状态区域', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();
    final repository = SettingsRepository(preferences, MemoryApiKeyStore());
    await repository.save(
      const SettingsState(
        apiKey: 'test-key',
        baseUrl: 'https://proxy.example/v1',
      ),
    );
    final completion = Completer<void>();
    final notifier = SettingsNotifier(
      repository,
      connectionTester: (_) => completion.future,
    );

    await _pumpAppShell(
      tester,
      platform: TargetPlatform.windows,
      size: const Size(1200, 800),
      settingsNotifier: notifier,
      settle: false,
    );

    expect(find.byKey(const Key('apiConnectionStatus')), findsOneWidget);
    expect(find.text('正在检测 API'), findsOneWidget);

    completion.complete();
    await tester.pumpAndSettle();

    expect(find.text('API 已连接'), findsOneWidget);
  });

  testWidgets('Windows 启动时在状态区域提示 API 尚未配置', (tester) async {
    await _pumpAppShell(
      tester,
      platform: TargetPlatform.windows,
      size: const Size(1200, 800),
    );

    expect(find.byKey(const Key('apiConnectionStatus')), findsOneWidget);
    expect(find.text('API 尚未配置'), findsWidgets);
  });

  testWidgets('Windows 启动检查失败时在状态区域提示 API 不可用', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();
    final repository = SettingsRepository(preferences, MemoryApiKeyStore());
    await repository.save(const SettingsState(apiKey: 'test-key'));
    final notifier = SettingsNotifier(
      repository,
      connectionTester: (_) async =>
          throw const AppException(AppErrorCode.unauthorized, '测试失败。'),
    );

    await _pumpAppShell(
      tester,
      platform: TargetPlatform.windows,
      size: const Size(1200, 800),
      settingsNotifier: notifier,
    );

    expect(find.byKey(const Key('apiConnectionStatus')), findsOneWidget);
    expect(find.text('API 连接失败'), findsWidgets);
  });

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

  testWidgets('完整数据重置期间阻止鼠标和键盘切换页面', (tester) async {
    await _pumpAppShell(
      tester,
      platform: TargetPlatform.windows,
      size: const Size(1200, 800),
      resetInProgress: true,
      settle: false,
    );

    await tester.tap(find.byIcon(Icons.history_outlined), warnIfMissed: false);
    await tester.pump();
    expect(_selectedNavigationIndex(tester), 0);

    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.digit3);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    await tester.pump();
    expect(_selectedNavigationIndex(tester), 0);
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
      final item = find.byKey(ValueKey('bottomNavigationDestination:$index'));
      expect(item, findsOneWidget);
      expect(tester.getSize(item).height, greaterThanOrEqualTo(48));
      expect(
        find.descendant(of: item, matching: find.byType(Text)),
        findsOneWidget,
      );
    }
    expect(tester.takeException(), isNull);
  });

  testWidgets('Android 200% 字体下悬浮播放器位于底部导航上方', (tester) async {
    await _pumpAppShell(
      tester,
      platform: TargetPlatform.android,
      size: const Size(360, 640),
      textScaleFactor: 2,
      ttsNotifier: _ReadyTtsNotifier(),
    );

    await tester.tap(
      find.byKey(const ValueKey('bottomNavigationDestination:1')),
    );
    await tester.pumpAndSettle();

    final player = find.byKey(const Key('mobileTtsPlayer'));
    final navigation = find.byKey(const Key('appBottomNavigation'));
    expect(player, findsOneWidget);
    expect(
      tester.getRect(player).bottom,
      lessThanOrEqualTo(tester.getRect(navigation).top - 8),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('Android 底栏按交付稿悬浮并使用毛玻璃表面', (tester) async {
    await _pumpAppShell(
      tester,
      platform: TargetPlatform.android,
      size: const Size(412, 892),
    );

    final shell = tester.widget<Scaffold>(
      find.byKey(const Key('compactShell')),
    );
    final bar = find.byKey(const Key('appBottomNavigation'));
    final barRect = tester.getRect(bar);

    expect(shell.extendBody, isTrue);
    expect(barRect.left, closeTo(16, 0.01));
    expect(barRect.right, closeTo(396, 0.01));
    expect(barRect.bottom, closeTo(876, 0.01));
    expect(
      find.descendant(of: bar, matching: find.byType(BackdropFilter)),
      findsOneWidget,
    );
    final clip = tester.widget<ClipRRect>(
      find.descendant(of: bar, matching: find.byType(ClipRRect)).first,
    );
    expect(clip.borderRadius, BorderRadius.circular(AppRadii.mobileHero));
    expect(find.text('转文字'), findsOneWidget);
    expect(find.text('转语音'), findsOneWidget);
  });

  testWidgets('Android 页面切换使用 260ms 淡入位移动效', (tester) async {
    await _pumpAppShell(
      tester,
      platform: TargetPlatform.android,
      size: const Size(412, 892),
      disableAnimations: false,
    );

    await tester.tap(
      find.byKey(const ValueKey('bottomNavigationDestination:1')),
    );
    await tester.pump();

    var opacity = tester.widget<Opacity>(
      find.byKey(const Key('mobilePageTransitionOpacity')),
    );
    var transform = tester.widget<Transform>(
      find.byKey(const Key('mobilePageTransitionOffset')),
    );
    expect(opacity.opacity, 0);
    expect(transform.transform.getTranslation().y, 6);

    await tester.pump(const Duration(milliseconds: 130));
    opacity = tester.widget<Opacity>(
      find.byKey(const Key('mobilePageTransitionOpacity')),
    );
    transform = tester.widget<Transform>(
      find.byKey(const Key('mobilePageTransitionOffset')),
    );
    expect(opacity.opacity, inExclusiveRange(0, 1));
    expect(transform.transform.getTranslation().y, inExclusiveRange(0, 6));

    await tester.pump(const Duration(milliseconds: 130));
    opacity = tester.widget<Opacity>(
      find.byKey(const Key('mobilePageTransitionOpacity')),
    );
    transform = tester.widget<Transform>(
      find.byKey(const Key('mobilePageTransitionOffset')),
    );
    expect(opacity.opacity, 1);
    expect(transform.transform.getTranslation().y, 0);
  });

  testWidgets('Android 页面切换在减少动态效果时立即完成', (tester) async {
    await _pumpAppShell(
      tester,
      platform: TargetPlatform.android,
      size: const Size(412, 892),
    );

    await tester.tap(
      find.byKey(const ValueKey('bottomNavigationDestination:1')),
    );
    await tester.pump();

    expect(find.byKey(const Key('mobilePageTransition')), findsNothing);
    expect(_selectedNavigationIndex(tester), isNull);
    expect(find.text('文字转语音'), findsOneWidget);
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
    expect(_pageFocusNode(tester, 'settingsPageFocus').hasPrimaryFocus, isTrue);
    expect(_pageFocusNode(tester, 'sttPageFocus').hasFocus, isFalse);

    await _sendControlShortcut(tester, LogicalKeyboardKey.digit3);
    expect(_selectedNavigationIndex(tester), 2);
    expect(_pageFocusNode(tester, 'historyPageFocus').hasPrimaryFocus, isTrue);

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

    expect(find.text('声流'), findsOneWidget);
    expect(find.text('声流 · 语音转文字'), findsOneWidget);
    expect(find.text('v1.0.0 · Windows'), findsOneWidget);
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
      ]),
    );
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
  bool disableAnimations = true,
  SttNotifier? sttNotifier,
  TtsNotifier? ttsNotifier,
  SettingsNotifier? settingsNotifier,
  bool resetInProgress = false,
  bool settle = true,
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
        historyRepositoryProvider.overrideWithValue(_MemoryHistoryRepository()),
        if (settingsNotifier != null)
          settingsProvider.overrideWith((ref) => settingsNotifier),
        if (resetInProgress)
          applicationDataResetProvider.overrideWith(
            (ref) => _LoadingApplicationDataResetNotifier(ref),
          ),
        if (sttNotifier != null) sttProvider.overrideWith((ref) => sttNotifier),
        if (ttsNotifier != null) ttsProvider.overrideWith((ref) => ttsNotifier),
      ],
      child: MaterialApp(
        locale: AppLocalizations.simplifiedChineseLocale,
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: AppLocalizations.delegates,
        theme: AppTheme.lightFor(platform),
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(disableAnimations: disableAnimations),
          child: child!,
        ),
        home: const AppShell(),
      ),
    ),
  );
  if (settle) {
    await tester.pumpAndSettle();
  } else {
    await tester.pump();
    await tester.pump();
  }
}

class _LoadingApplicationDataResetNotifier
    extends ApplicationDataResetNotifier {
  _LoadingApplicationDataResetNotifier(super.ref) {
    state = const AsyncValue.loading();
  }
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
  Future<void> setPlaybackRate(double rate) async {}

  @override
  Future<void> setVolume(double volume) async {}

  @override
  Future<void> stop() async {}
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
        historyWriter:
            ({required type, required text, required audioPath}) async {},
      ) {
    state = const SttState(phase: SttPhase.recording);
  }
}

class _FailedRecordingSttNotifier extends SttNotifier {
  _FailedRecordingSttNotifier(_TrackingRecorder recorder)
    : super(
        recorder: recorder,
        apiService: WhisperApiService(DioClient(const SettingsState())),
        historyWriter:
            ({required type, required text, required audioPath}) async {},
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
  Future<void> start() async {}

  @override
  Future<File> stop() => throw UnimplementedError();
}
