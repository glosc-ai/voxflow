import 'package:flutter/material.dart';
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
import 'package:voxflow/features/settings/views/settings_screen.dart';
import 'package:voxflow/features/settings/widgets/masked_text_editing_controller.dart';
import 'package:voxflow/features/tts/models/tts_state.dart';
import 'package:voxflow/features/tts/providers/tts_provider.dart';
import 'package:voxflow/features/tts/services/audio_playback_manager.dart';
import 'package:voxflow/features/tts/services/tts_api_service.dart';
import 'package:voxflow/features/tts/views/tts_screen.dart';

void main() {
  testWidgets('移动端使用底部导航', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();
    await tester.binding.setSurfaceSize(const Size(600, 900));
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

    expect(find.byType(BottomNavigationBar), findsOneWidget);
    expect(find.byType(NavigationRail), findsNothing);
  });

  testWidgets('桌面端使用侧边导航', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();
    await tester.binding.setSurfaceSize(const Size(1200, 800));
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

    expect(find.byType(NavigationRail), findsOneWidget);
    expect(find.byType(BottomNavigationBar), findsNothing);
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
    await tester.tap(find.widgetWithText(TextButton, '删除').first);
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
        overrides: [
          sharedPreferencesProvider.overrideWithValue(preferences),
        ],
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

    await tester.enterText(field, 'secret');
    final controller = textField.controller! as MaskedTextEditingController;
    expect(controller.text, 'secret');
    expect(
      controller
          .buildTextSpan(
            context: tester.element(field),
            withComposing: false,
          )
          .toPlainText(),
      '••••••',
    );
  });

  testWidgets('获取模型后更新 STT 和 TTS 下拉选项', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();
    final repository = SettingsRepository(preferences);
    await repository.save(
      const SettingsState(
        apiKey: 'test-key',
        baseUrl: 'https://proxy.example/v1',
      ),
    );
    final notifier = SettingsNotifier(
      repository,
      modelLoader: (_) async => [
        'whisper-1',
        'gpt-4o-transcribe',
        'tts-1',
        'gpt-4o-mini-tts',
        'chat-model',
      ],
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          settingsProvider.overrideWith((ref) => notifier),
        ],
        child: const MaterialApp(home: SettingsScreen()),
      ),
    );

    await tester.tap(find.byKey(const Key('fetchModelsButton')));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('sttModelField')));
    await tester.pumpAndSettle();
    expect(find.text('gpt-4o-transcribe'), findsOneWidget);
    expect(find.text('chat-model'), findsNothing);
    await tester.tap(find.text('gpt-4o-transcribe'));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('ttsModelField')));
    await tester.pumpAndSettle();
    expect(find.text('gpt-4o-mini-tts'), findsOneWidget);
  });

  testWidgets('TTS 失败原因持续显示在页面内', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
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
    state = const TtsState(
      phase: TtsPhase.failure,
      errorMessage: '测试服务不可用。',
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
