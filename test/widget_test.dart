import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:voxflow/app.dart';
import 'package:voxflow/core/network/dio_client.dart';
import 'package:voxflow/features/history/models/history_record.dart';
import 'package:voxflow/features/history/providers/history_provider.dart';
import 'package:voxflow/features/history/services/history_repository.dart';
import 'package:voxflow/features/history/views/history_screen.dart';
import 'package:voxflow/features/settings/providers/settings_provider.dart';
import 'package:voxflow/features/settings/models/settings_state.dart';
import 'package:voxflow/features/settings/services/settings_repository.dart';
import 'package:voxflow/features/settings/services/privacy_notice_repository.dart';
import 'package:voxflow/features/settings/views/settings_screen.dart';
import 'package:voxflow/features/settings/widgets/masked_text_editing_controller.dart';
import 'package:voxflow/features/tts/models/tts_state.dart';
import 'package:voxflow/features/tts/providers/tts_provider.dart';
import 'package:voxflow/features/tts/services/audio_playback_manager.dart';
import 'package:voxflow/features/tts/services/tts_api_service.dart';
import 'package:voxflow/features/tts/views/tts_screen.dart';

import 'support/memory_api_key_store.dart';

void main() {
  testWidgets('首次提交敏感数据前显示数据与隐私说明', (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.windows;
    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();
    await SettingsRepository(
      preferences,
    ).save(const SettingsState(localePreference: AppLocalePreference.zhHans));
    addTearDown(() => debugDefaultTargetPlatformOverride = null);

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
        ],
        child: const VoxFlowApp(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('数据与隐私说明'), findsOneWidget);
    expect(find.textContaining('当前用户作用域的 DPAPI 加密'), findsOneWidget);
    expect(find.textContaining('Android 应用数据备份已禁用'), findsOneWidget);
    expect(find.textContaining('当前用户注册表'), findsOneWidget);
    expect(find.textContaining('不防御已控制同一 Windows 用户的进程'), findsOneWidget);
    expect(find.textContaining('可随时撤销、设置了低额度上限的测试密钥'), findsOneWidget);
    expect(find.textContaining('不会写入普通应用设置、系统备份'), findsNothing);
    expect(find.textContaining('发送到你配置的 API 服务商'), findsOneWidget);
    expect(find.textContaining('历史文本和受管音频保存在本机'), findsOneWidget);
    expect(find.textContaining('文件删除失败时会提示'), findsOneWidget);
    expect(find.textContaining('错误原因可能回显部分输入内容'), findsOneWidget);
    expect(find.byKey(const Key('apiKeyField')), findsNothing);

    await tester.tap(find.byKey(const Key('privacyNoticeAcceptButton')));
    await tester.pumpAndSettle();

    expect(find.text('数据与隐私说明'), findsNothing);
    expect(find.byKey(const Key('desktopNavigation')), findsOneWidget);
    debugDefaultTargetPlatformOverride = null;
  });

  testWidgets('Android 隐私说明在 360x640 与 200% 字体下保持可用', (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();
    await SettingsRepository(
      preferences,
    ).save(const SettingsState(localePreference: AppLocalePreference.english));
    await tester.binding.setSurfaceSize(const Size(360, 640));
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(() async {
      debugDefaultTargetPlatformOverride = null;
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
        ],
        child: const VoxFlowApp(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(AppBar), findsNothing);
    expect(
      find.byKey(const Key('mobilePrivacyNoticeScrollView')),
      findsOneWidget,
    );
    expect(find.text('Data and privacy'), findsOneWidget);
    expect(
      find.textContaining('revocable test key with a low quota limit'),
      findsOneWidget,
    );
    expect(find.byKey(const Key('privacyNoticeAcceptButton')), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.tap(find.byKey(const Key('privacyNoticeAcceptButton')));
    await tester.pumpAndSettle();

    expect(find.text('Data and privacy'), findsNothing);
    expect(
      find.byKey(const ValueKey('bottomNavigationDestination:0')),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
    debugDefaultTargetPlatformOverride = null;
  });

  testWidgets('移动端使用底部导航', (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();
    await PrivacyNoticeRepository(preferences).acknowledge();
    await tester.binding.setSurfaceSize(const Size(600, 900));
    addTearDown(() {
      debugDefaultTargetPlatformOverride = null;
      tester.binding.setSurfaceSize(null);
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
        ],
        child: const VoxFlowApp(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('appBottomNavigation')), findsOneWidget);
    expect(find.byType(BottomNavigationBar), findsNothing);
    expect(find.byType(NavigationRail), findsNothing);
    debugDefaultTargetPlatformOverride = null;
  });

  testWidgets('桌面端使用侧边导航', (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.windows;
    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();
    await PrivacyNoticeRepository(preferences).acknowledge();
    await tester.binding.setSurfaceSize(const Size(1200, 800));
    addTearDown(() {
      debugDefaultTargetPlatformOverride = null;
      tester.binding.setSurfaceSize(null);
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
        ],
        child: const VoxFlowApp(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('desktopNavigation')), findsOneWidget);
    expect(find.byType(BottomNavigationBar), findsNothing);
    debugDefaultTargetPlatformOverride = null;
  });

  testWidgets('AppShell 支持 1 至 4 与 Ctrl+1 至 Ctrl+4 键盘导航', (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.windows;
    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();
    await PrivacyNoticeRepository(preferences).acknowledge();
    await tester.binding.setSurfaceSize(const Size(1200, 800));
    addTearDown(() {
      debugDefaultTargetPlatformOverride = null;
      tester.binding.setSurfaceSize(null);
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
        ],
        child: const VoxFlowApp(),
      ),
    );
    await tester.pumpAndSettle();

    expect(_selectedNavigationIndex(tester), 0);
    for (final (key, expectedIndex) in [
      (LogicalKeyboardKey.digit2, 1),
      (LogicalKeyboardKey.digit3, 2),
      (LogicalKeyboardKey.digit4, 3),
      (LogicalKeyboardKey.digit1, 0),
    ]) {
      await _sendControlShortcut(tester, key);
      expect(_selectedNavigationIndex(tester), expectedIndex);
    }

    for (final (key, expectedIndex) in [
      (LogicalKeyboardKey.digit2, 1),
      (LogicalKeyboardKey.digit3, 2),
      (LogicalKeyboardKey.digit4, 3),
      (LogicalKeyboardKey.digit1, 0),
    ]) {
      await tester.sendKeyEvent(key);
      await tester.pumpAndSettle();
      expect(_selectedNavigationIndex(tester), expectedIndex);
    }

    await tester.sendKeyEvent(LogicalKeyboardKey.digit2);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('ttsTextField')));
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.digit3);
    await tester.pumpAndSettle();
    expect(_selectedNavigationIndex(tester), 1, reason: '裸数字快捷键不应劫持文本输入');
    debugDefaultTargetPlatformOverride = null;
  });

  testWidgets('浅色、深色与系统主题可切换并持久化', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();
    await PrivacyNoticeRepository(preferences).acknowledge();
    await tester.binding.setSurfaceSize(const Size(1200, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

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
        ],
        child: const VoxFlowApp(),
      ),
    );
    await tester.pumpAndSettle();
    await _sendControlShortcut(tester, LogicalKeyboardKey.digit4);

    expect(_appThemeMode(tester), ThemeMode.system);
    var current = AppThemePreference.system;
    for (final (preference, expectedMode) in [
      (AppThemePreference.dark, ThemeMode.dark),
      (AppThemePreference.light, ThemeMode.light),
      (AppThemePreference.system, ThemeMode.system),
    ]) {
      final themeField = find.byKey(ValueKey('themeMode:${current.name}'));
      await tester.ensureVisible(themeField);
      await tester.pumpAndSettle();
      if (tester.widget(themeField)
          is DropdownButtonFormField<AppThemePreference>) {
        await tester.tap(themeField);
        await tester.pumpAndSettle();
        await tester.tap(find.text(_englishThemeLabel(preference)).last);
      } else {
        await tester.tap(
          find.descendant(
            of: themeField,
            matching: find.text(_englishThemeLabel(preference)),
          ),
        );
      }
      await tester.pumpAndSettle();

      expect(_appThemeMode(tester), expectedMode);
      expect(
        SettingsRepository(preferences).load().themePreference,
        preference,
      );
      current = preference;
    }
  });

  testWidgets('200% 大字体下窄屏主界面无溢出或异常', (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();
    await PrivacyNoticeRepository(preferences).acknowledge();
    await tester.binding.setSurfaceSize(const Size(360, 640));
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(() {
      debugDefaultTargetPlatformOverride = null;
      tester.binding.setSurfaceSize(null);
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
        ],
        child: const VoxFlowApp(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('appBottomNavigation')), findsOneWidget);
    expect(find.byType(BottomNavigationBar), findsNothing);
    expect(tester.takeException(), isNull);
    for (final icon in [
      Icons.record_voice_over_outlined,
      Icons.history_outlined,
      Icons.settings_outlined,
      Icons.graphic_eq_outlined,
    ]) {
      final destination = find.descendant(
        of: find.byKey(const Key('appBottomNavigation')),
        matching: find.byIcon(icon),
      );
      await tester.tap(destination);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    }
    debugDefaultTargetPlatformOverride = null;
  });

  testWidgets('历史记录可搜索并确认删除', (tester) async {
    final repository = _MemoryHistoryRepository();
    repository.records.add(
      HistoryRecord(
        id: 1,
        type: HistoryType.stt,
        text: '需要查找的转录',
        audioPath: 'external.wav',
        createdAt: DateTime.utc(2026, 7, 20),
      ),
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          historyRepositoryProvider.overrideWithValue(repository),
          historyPlaybackManagerProvider.overrideWithValue(
            const _SilentPlaybackController(),
          ),
        ],
        child: const MaterialApp(home: HistoryScreen()),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('需要查找的转录'), findsOneWidget);

    await tester.enterText(find.byKey(const Key('historySearchField')), '不存在');
    await tester.testTextInput.receiveAction(TextInputAction.search);
    await tester.pumpAndSettle();
    expect(find.text('未找到匹配的历史记录'), findsOneWidget);

    await tester.tap(find.byTooltip('清空搜索'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('mobileHistoryCard:1')));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('删除'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, '删除'));
    await tester.pumpAndSettle();
    expect(repository.records, isEmpty);
    expect(find.text('暂无历史记录'), findsOneWidget);
  });

  testWidgets('API Key 自定义遮罩避免桌面 secure-text IME 崩溃', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [sharedPreferencesProvider.overrideWithValue(preferences)],
        child: const MaterialApp(home: SettingsScreen()),
      ),
    );

    final field = find.descendant(
      of: find.byKey(const Key('apiKeyField')),
      matching: find.byType(TextField),
    );
    final textField = tester.widget<TextField>(field);
    expect(textField.keyboardType, TextInputType.visiblePassword);
    expect(textField.obscureText, isFalse);
    expect(
      find.ancestor(of: field, matching: find.byType(ExcludeSemantics)),
      findsOneWidget,
    );
    expect(
      tester.getTopLeft(find.byKey(const Key('baseUrlField'))).dy,
      lessThan(tester.getTopLeft(find.byKey(const Key('apiKeyField'))).dy),
    );
    expect(find.byKey(const Key('viewLogsButton')), findsOneWidget);
    expect(find.byKey(const Key('exportLogsButton')), findsOneWidget);

    await tester.enterText(field, 'secret');
    final controller = textField.controller! as MaskedTextEditingController;
    expect(controller.text, 'secret');
    expect(
      controller
          .buildTextSpan(context: tester.element(field), withComposing: false)
          .toPlainText(),
      '••••••',
    );
  });

  testWidgets('获取模型后更新 STT 和 TTS 下拉选项', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();
    final repository = SettingsRepository(preferences, MemoryApiKeyStore());
    await repository.save(
      const SettingsState(
        apiKey: 'test-key',
        baseUrl: 'https://proxy.example/v1',
      ),
    );
    final notifier = SettingsNotifier(
      repository,
      modelLoader: (_) async => [
        'gpt-4o-transcribe',
        'gpt-4o-mini-tts',
        'chat-model',
      ],
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [settingsProvider.overrideWith((ref) => notifier)],
        child: const MaterialApp(home: SettingsScreen()),
      ),
    );

    final fetchModelsButton = find.byKey(const Key('fetchModelsButton'));
    await tester.ensureVisible(fetchModelsButton);
    await tester.pumpAndSettle();
    await tester.tap(fetchModelsButton);
    await tester.pumpAndSettle();

    expect(find.text('whisper-1'), findsNothing);
    expect(find.text('tts-1'), findsNothing);
    expect(find.text('gpt-4o-transcribe'), findsOneWidget);
    expect(find.text('gpt-4o-mini-tts'), findsOneWidget);

    final sttModelField = find.byKey(const Key('sttModelField'));
    await tester.ensureVisible(sttModelField);
    await tester.pumpAndSettle();
    await tester.tap(sttModelField);
    await tester.pumpAndSettle();
    expect(find.text('gpt-4o-transcribe'), findsWidgets);
    expect(find.text('whisper-1'), findsNothing);
    expect(find.text('chat-model'), findsNothing);
    final sttModelOption = find.text('gpt-4o-transcribe').last;
    await tester.ensureVisible(sttModelOption);
    await tester.pumpAndSettle();
    await tester.tap(sttModelOption);
    await tester.pumpAndSettle();

    final ttsModelField = find.byKey(const Key('ttsModelField'));
    await tester.ensureVisible(ttsModelField);
    await tester.pumpAndSettle();
    await tester.tap(ttsModelField);
    await tester.pumpAndSettle();
    expect(find.text('gpt-4o-mini-tts'), findsWidgets);
    expect(find.text('tts-1'), findsNothing);
  });

  testWidgets('火山 SeedASR 模型出现在 STT 下拉选项', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();
    final repository = SettingsRepository(preferences, MemoryApiKeyStore());
    await repository.save(
      const SettingsState(
        apiKey: 'test-key',
        baseUrl: 'https://proxy.example/v1',
      ),
    );
    final notifier = SettingsNotifier(
      repository,
      modelLoader: (_) async => [
        'bytedance/volc.seedasr.sauc.duration',
        'bytedance/seed-tts-2.0',
      ],
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [settingsProvider.overrideWith((ref) => notifier)],
        child: const MaterialApp(home: SettingsScreen()),
      ),
    );

    final fetchModelsButton = find.byKey(const Key('fetchModelsButton'));
    await tester.ensureVisible(fetchModelsButton);
    await tester.pumpAndSettle();
    await tester.tap(fetchModelsButton);
    await tester.pumpAndSettle();

    expect(find.text('bytedance/volc.seedasr.sauc.duration'), findsOneWidget);
  });

  testWidgets('TTS 失败原因持续显示在页面内', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(preferences),
          ttsProvider.overrideWith((ref) => _FailureTtsNotifier()),
        ],
        child: const MaterialApp(home: TtsScreen()),
      ),
    );

    await tester.enterText(find.byKey(const Key('ttsTextField')), 'test');
    final synthesizeButton = find.byKey(const Key('synthesizeButton'));
    await tester.ensureVisible(synthesizeButton);
    await tester.pumpAndSettle();
    await tester.tap(synthesizeButton);
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('inlineErrorMessage')), findsOneWidget);
    expect(find.text('测试服务不可用。'), findsWidgets);
  });

  testWidgets('Seed TTS 使用模型专属火山 Speaker ID', (tester) async {
    SharedPreferences.setMockInitialValues({
      'settings.tts_model': 'bytedance/seed-tts-2.0',
    });
    final preferences = await SharedPreferences.getInstance();
    final notifier = TtsNotifier(
      apiService: TtsApiService(DioClient(const SettingsState())),
      playback: const _SilentPlaybackController(),
      historyWriter: ({required text, required audioPath}) async {},
      model: 'bytedance/seed-tts-2.0',
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(preferences),
          ttsProvider.overrideWith((ref) => notifier),
        ],
        child: const MaterialApp(home: TtsScreen()),
      ),
    );

    expect(find.text('zh_female_cancan_uranus_bigtts'), findsOneWidget);
    expect(
      find.text('ByteDance Seed-TTS 2.0 使用火山引擎 Speaker ID。'),
      findsOneWidget,
    );
    expect(find.text('alloy'), findsNothing);
  });
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

ThemeMode? _appThemeMode(WidgetTester tester) {
  return tester.widget<MaterialApp>(find.byType(MaterialApp)).themeMode;
}

String _englishThemeLabel(AppThemePreference preference) {
  return switch (preference) {
    AppThemePreference.system => 'Follow system',
    AppThemePreference.light => 'Light',
    AppThemePreference.dark => 'Dark',
  };
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

class _FailureTtsNotifier extends TtsNotifier {
  _FailureTtsNotifier()
    : super(
        apiService: TtsApiService(DioClient(const SettingsState())),
        playback: const _SilentPlaybackController(),
        historyWriter: ({required text, required audioPath}) async {},
        model: 'tts-1',
      );

  @override
  Future<void> synthesize(String text) async {
    state = const TtsState(phase: TtsPhase.failure, errorMessage: '测试服务不可用。');
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

class _MemoryHistoryRepository extends HistoryRepository {
  final records = <HistoryRecord>[];

  @override
  Future<void> close() async {}

  @override
  Future<void> delete(int id) async {
    records.removeWhere((record) => record.id == id);
  }

  @override
  Future<HistoryRecord> insert(HistoryRecord record) async {
    final inserted = HistoryRecord(
      id: records.length + 1,
      type: record.type,
      text: record.text,
      audioPath: record.audioPath,
      createdAt: record.createdAt,
    );
    records.add(inserted);
    return inserted;
  }

  @override
  Future<List<HistoryRecord>> search([String query = '']) async {
    return records
        .where((record) => record.text.contains(query))
        .toList(growable: false);
  }
}
