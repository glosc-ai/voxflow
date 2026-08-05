import 'dart:io';
import 'dart:ui' show Locale;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:voxflow/core/errors/app_exception.dart';
import 'package:voxflow/core/logging/app_logger.dart';
import 'package:voxflow/core/network/dio_client.dart';
import 'package:voxflow/features/history/models/history_record.dart';
import 'package:voxflow/features/history/providers/history_provider.dart';
import 'package:voxflow/features/history/services/history_repository.dart';
import 'package:voxflow/features/settings/models/settings_state.dart';
import 'package:voxflow/features/settings/providers/application_data_reset_provider.dart';
import 'package:voxflow/features/settings/providers/privacy_notice_provider.dart';
import 'package:voxflow/features/settings/providers/settings_provider.dart';
import 'package:voxflow/features/settings/services/application_data_reset_service.dart';
import 'package:voxflow/features/settings/services/settings_repository.dart';
import 'package:voxflow/features/shell/providers/navigation_provider.dart';
import 'package:voxflow/features/stt/models/stt_state.dart';
import 'package:voxflow/features/stt/providers/stt_provider.dart';
import 'package:voxflow/features/stt/services/audio_record_manager.dart';
import 'package:voxflow/features/stt/services/whisper_api_service.dart';
import 'package:voxflow/features/tts/models/tts_state.dart';
import 'package:voxflow/features/tts/providers/tts_provider.dart';
import 'package:voxflow/features/tts/services/audio_playback_manager.dart';
import 'package:voxflow/features/tts/services/tts_api_service.dart';

import '../../support/memory_api_key_store.dart';

void main() {
  test(
    'full reset clears live settings and history and revokes privacy notice',
    () async {
      final harness = await _ResetHarness.create();
      addTearDown(harness.dispose);
      final container = harness.container;

      expect(container.read(privacyNoticeProvider), isTrue);
      await container.read(historyProvider.notifier).load();
      expect(container.read(historyProvider).valueOrNull, hasLength(1));
      expect(container.read(settingsProvider).apiKey, 'test-secret');
      container.read(navigationIndexProvider.notifier).state = 3;

      final feedback = await container
          .read(applicationDataResetProvider.notifier)
          .resetAllData();

      const defaults = SettingsState();
      final settings = container.read(settingsProvider);
      expect(
        feedback.resolve(const Locale('en')),
        'All local app data was cleared.',
      );
      expect(harness.resetService.resetCount, 1);
      expect(settings.apiKey, defaults.apiKey);
      expect(settings.baseUrl, defaults.baseUrl);
      expect(settings.sttModel, defaults.sttModel);
      expect(settings.ttsModel, defaults.ttsModel);
      expect(container.read(historyProvider).valueOrNull, isEmpty);
      expect(container.read(privacyNoticeProvider), isFalse);
      expect(container.read(navigationIndexProvider), 0);
      expect(harness.apiKeyStore.value, isNull);
      expect(harness.preferences.getKeys(), isEmpty);
    },
  );

  test(
    'late reset failure still reconciles providers with cleared storage',
    () async {
      final harness = await _ResetHarness.create(failAfterCleanup: true);
      addTearDown(harness.dispose);
      final container = harness.container;
      await container.read(historyProvider.notifier).load();
      container.read(navigationIndexProvider.notifier).state = 3;

      await expectLater(
        container.read(applicationDataResetProvider.notifier).resetAllData(),
        throwsA(
          isA<AppException>().having(
            (error) => error.code,
            'code',
            AppErrorCode.storageFailure,
          ),
        ),
      );

      expect(container.read(settingsProvider).apiKey, isEmpty);
      expect(container.read(historyProvider).valueOrNull, isEmpty);
      expect(container.read(privacyNoticeProvider), isFalse);
      expect(harness.apiKeyStore.value, isNull);
      expect(harness.preferences.getKeys(), isEmpty);
    },
  );

  for (final (name, sttPhase, ttsPhase) in [
    ('STT processing', SttPhase.transcribing, TtsPhase.idle),
    ('TTS processing', SttPhase.idle, TtsPhase.generating),
  ]) {
    test('$name rejects reset before invoking persistent cleanup', () async {
      final harness = await _ResetHarness.create(
        sttPhase: sttPhase,
        ttsPhase: ttsPhase,
      );
      addTearDown(harness.dispose);
      final container = harness.container;
      expect(container.read(privacyNoticeProvider), isTrue);
      await container.read(historyProvider.notifier).load();

      await expectLater(
        container.read(applicationDataResetProvider.notifier).resetAllData(),
        throwsA(
          isA<AppException>().having(
            (error) => error.code,
            'code',
            AppErrorCode.invalidConfiguration,
          ),
        ),
      );

      expect(harness.resetService.resetCount, 0);
      expect(container.read(settingsProvider).apiKey, 'test-secret');
      expect(container.read(historyProvider).valueOrNull, hasLength(1));
      expect(container.read(privacyNoticeProvider), isTrue);
      expect(harness.preferences.getKeys(), isNotEmpty);

      final restoredRepository = SettingsRepository(
        harness.preferences,
        harness.apiKeyStore,
      );
      await restoredRepository.initialize();
      expect(restoredRepository.load().apiKey, 'test-secret');
    });
  }
}

class _ResetHarness {
  _ResetHarness({
    required this.container,
    required this.preferences,
    required this.apiKeyStore,
    required this.resetService,
    required this.temporaryDirectory,
  });

  final ProviderContainer container;
  final SharedPreferences preferences;
  final MemoryApiKeyStore apiKeyStore;
  final _TrackingResetService resetService;
  final Directory temporaryDirectory;

  static Future<_ResetHarness> create({
    SttPhase sttPhase = SttPhase.idle,
    TtsPhase ttsPhase = TtsPhase.idle,
    bool failAfterCleanup = false,
  }) async {
    SharedPreferences.setMockInitialValues({
      'privacy_notice.acknowledged.v1': true,
      'settings.base_url': 'https://proxy.example/v1',
      'settings.stt_model': 'gpt-4o-transcribe',
      'settings.tts_model': 'gpt-4o-mini-tts',
      'settings.theme_mode': AppThemePreference.dark.name,
      'settings.locale': AppLocalePreference.english.name,
    });
    final preferences = await SharedPreferences.getInstance();
    final apiKeyStore = MemoryApiKeyStore(initialValue: 'test-secret');
    final settingsRepository = SettingsRepository(preferences, apiKeyStore);
    await settingsRepository.initialize();
    final settingsNotifier = SettingsNotifier(settingsRepository);
    final historyRepository = _MemoryHistoryRepository()
      ..records.add(
        HistoryRecord(
          id: 1,
          type: HistoryType.stt,
          text: 'persisted transcript',
          audioPath: 'managed.wav',
          createdAt: DateTime.utc(2026, 8, 5),
        ),
      );
    final sttNotifier = _ControllableSttNotifier()..setPhase(sttPhase);
    final ttsNotifier = _ControllableTtsNotifier()..setPhase(ttsPhase);
    final temporaryDirectory = await Directory.systemTemp.createTemp(
      'voxflow_reset_provider_',
    );
    final logger = AppLogger(
      fileResolver: () async => File(
        '${temporaryDirectory.path}${Platform.pathSeparator}voxflow.log',
      ),
    );
    final resetService = _TrackingResetService(
      preferences: preferences,
      apiKeyStore: apiKeyStore,
      historyRepository: historyRepository,
      logger: logger,
      failAfterCleanup: failAfterCleanup,
    );
    final container = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(preferences),
        apiKeyStoreProvider.overrideWithValue(apiKeyStore),
        settingsRepositoryProvider.overrideWithValue(settingsRepository),
        settingsProvider.overrideWith((ref) => settingsNotifier),
        historyRepositoryProvider.overrideWithValue(historyRepository),
        historyPlaybackManagerProvider.overrideWithValue(
          const _SilentPlaybackController(),
        ),
        sttProvider.overrideWith((ref) => sttNotifier),
        ttsProvider.overrideWith((ref) => ttsNotifier),
        applicationDataResetServiceProvider.overrideWithValue(resetService),
      ],
    );
    return _ResetHarness(
      container: container,
      preferences: preferences,
      apiKeyStore: apiKeyStore,
      resetService: resetService,
      temporaryDirectory: temporaryDirectory,
    );
  }

  Future<void> dispose() async {
    container.dispose();
    if (await temporaryDirectory.exists()) {
      await temporaryDirectory.delete(recursive: true);
    }
  }
}

class _TrackingResetService extends ApplicationDataResetService {
  _TrackingResetService({
    required super.preferences,
    required MemoryApiKeyStore apiKeyStore,
    required super.historyRepository,
    required super.logger,
    this.failAfterCleanup = false,
  }) : super(
         apiKeyStore: apiKeyStore,
         clearManagedAudio: _noOp,
         clearTemporaryFiles: _noOp,
       );

  int resetCount = 0;
  final bool failAfterCleanup;

  @override
  Future<void> reset() async {
    resetCount += 1;
    await super.reset();
    if (failAfterCleanup) {
      throw const AppException(
        AppErrorCode.storageFailure,
        '模拟清理尾部失败。',
        englishMessage: 'Simulated late reset failure.',
      );
    }
  }

  static Future<void> _noOp() async {}
}

class _MemoryHistoryRepository extends HistoryRepository {
  final records = <HistoryRecord>[];

  @override
  Future<void> clear() async => records.clear();

  @override
  Future<void> close() async {}

  @override
  Future<List<HistoryRecord>> search([String query = '']) async {
    return records
        .where((record) => record.text.contains(query))
        .toList(growable: false);
  }
}

class _ControllableSttNotifier extends SttNotifier {
  _ControllableSttNotifier()
    : super(
        recorder: _FakeRecorder(),
        apiService: WhisperApiService(DioClient(const SettingsState())),
        historyWriter:
            ({required type, required text, required audioPath}) async {},
      );

  void setPhase(SttPhase phase) {
    state = SttState(phase: phase);
  }
}

class _ControllableTtsNotifier extends TtsNotifier {
  _ControllableTtsNotifier()
    : super(
        apiService: TtsApiService(DioClient(const SettingsState())),
        playback: const _SilentPlaybackController(),
        historyWriter: ({required text, required audioPath}) async {},
        model: 'tts-1',
      );

  void setPhase(TtsPhase phase) {
    state = TtsState(phase: phase);
  }
}

class _FakeRecorder implements AudioRecordManager {
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
  Future<File> stop() async => File('unused');
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
