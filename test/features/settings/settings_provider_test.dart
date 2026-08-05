import 'dart:io';
import 'dart:ui';
import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:voxflow/core/errors/app_exception.dart';
import 'package:voxflow/features/settings/models/settings_state.dart';
import 'package:voxflow/features/settings/providers/settings_provider.dart';
import 'package:voxflow/features/settings/services/settings_repository.dart';
import 'package:voxflow/features/stt/providers/stt_provider.dart';
import 'package:voxflow/features/stt/services/audio_record_manager.dart';
import 'package:voxflow/features/tts/providers/tts_provider.dart';
import 'package:voxflow/features/tts/services/audio_playback_manager.dart';

import '../../support/memory_api_key_store.dart';

void main() {
  test('启动时未配置 API 不发起连接请求', () async {
    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();
    var callCount = 0;
    final notifier = SettingsNotifier(
      SettingsRepository(preferences, MemoryApiKeyStore()),
      connectionTester: (_) async => callCount += 1,
    );
    addTearDown(notifier.dispose);

    await notifier.checkStoredConnectionOnLaunch();

    expect(callCount, 0);
    expect(notifier.state.lastConnectionSucceeded, isNull);
    expect(notifier.state.activeOperation, isNull);
  });

  test('凭据恢复状态不发起启动请求且重新保存后可检查', () async {
    SharedPreferences.setMockInitialValues({
      'settings.credentials_update_pending': true,
      'settings.base_url': 'https://provider.example/v1',
    });
    final preferences = await SharedPreferences.getInstance();
    final repository = SettingsRepository(
      preferences,
      MemoryApiKeyStore(initialValue: 'retained-secret'),
    );
    await repository.initialize();
    var callCount = 0;
    final notifier = SettingsNotifier(
      repository,
      connectionTester: (_) async => callCount += 1,
    );
    addTearDown(notifier.dispose);

    expect(notifier.state.credentialRecoveryRequired, isTrue);
    await notifier.checkStoredConnectionOnLaunch();
    expect(callCount, 0);

    await notifier.save(
      apiKey: 'replacement-secret',
      baseUrl: 'https://provider.example/v1',
      sttModel: 'whisper-1',
      ttsModel: 'tts-1',
    );
    expect(notifier.state.credentialRecoveryRequired, isFalse);

    await notifier.checkStoredConnectionOnLaunch();
    expect(callCount, 1);
    expect(notifier.state.lastConnectionSucceeded, isTrue);
  });

  test('启动 API 检查显示检测中并在成功后标记已连接', () async {
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
    addTearDown(notifier.dispose);

    final pending = notifier.checkStoredConnectionOnLaunch();

    expect(notifier.state.activeOperation, SettingsOperation.testingConnection);
    completion.complete();
    await pending;
    expect(notifier.state.activeOperation, isNull);
    expect(notifier.state.lastConnectionSucceeded, isTrue);
  });

  test('启动 API 检查失败不抛异常并标记不可用', () async {
    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();
    final repository = SettingsRepository(preferences, MemoryApiKeyStore());
    await repository.save(const SettingsState(apiKey: 'test-key'));
    final notifier = SettingsNotifier(
      repository,
      connectionTester: (_) async =>
          throw const AppException(AppErrorCode.unauthorized, '测试失败'),
    );
    addTearDown(notifier.dispose);

    await notifier.checkStoredConnectionOnLaunch();

    expect(notifier.state.activeOperation, isNull);
    expect(notifier.state.lastConnectionSucceeded, isFalse);
  });

  test('旧凭据的启动检查结果不会覆盖保存后的新凭据状态', () async {
    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();
    final repository = SettingsRepository(preferences, MemoryApiKeyStore());
    await repository.save(
      const SettingsState(apiKey: 'old-key', baseUrl: 'https://old.example/v1'),
    );
    final completion = Completer<void>();
    final notifier = SettingsNotifier(
      repository,
      connectionTester: (_) => completion.future,
    );
    addTearDown(notifier.dispose);

    final pending = notifier.checkStoredConnectionOnLaunch();
    await notifier.save(
      apiKey: 'new-key',
      baseUrl: 'https://new.example/v1',
      sttModel: 'whisper-1',
      ttsModel: 'tts-1',
    );
    completion.complete();
    await pending;

    expect(notifier.state.apiKey, 'new-key');
    expect(notifier.state.lastConnectionSucceeded, isNull);
    expect(notifier.state.activeOperation, isNull);
  });

  test('获取模型的瞬态设置变化不会重置语音工作状态', () async {
    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();
    final repository = SettingsRepository(preferences, MemoryApiKeyStore());
    await repository.save(
      const SettingsState(
        apiKey: 'test-key',
        baseUrl: 'https://proxy.example/v1',
      ),
    );
    final settings = SettingsNotifier(
      repository,
      modelLoader: (_) async => ['whisper-1', 'tts-1'],
    );
    final container = ProviderContainer(
      overrides: [
        settingsProvider.overrideWith((ref) => settings),
        audioRecordManagerProvider.overrideWithValue(_FakeRecorder()),
        ttsPlaybackManagerProvider.overrideWithValue(
          const _SilentPlaybackController(),
        ),
      ],
    );
    addTearDown(container.dispose);

    container.read(sttProvider.notifier).updateEditedText('尚未导出的转录草稿');
    container.read(ttsProvider.notifier).setSpeed(1.5);

    await container
        .read(settingsProvider.notifier)
        .fetchModels(apiKey: 'test-key', baseUrl: 'https://proxy.example/v1');

    expect(container.read(sttProvider).editedText, '尚未导出的转录草稿');
    expect(container.read(ttsProvider).speed, 1.5);
    expect(
      container.read(settingsProvider).messageFor(const Locale('en')),
      'Fetched 1 speech-to-text model and 1 text-to-speech model. '
      'Save settings after choosing models.',
    );
  });

  test('设置错误反馈保持双语且英文界面不显示中文服务原文', () async {
    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();
    final notifier = SettingsNotifier(
      SettingsRepository(preferences, MemoryApiKeyStore()),
      modelLoader: (_) async => throw const AppException(
        AppErrorCode.unauthorized,
        '凭据无效。',
        englishMessage: 'The credentials are invalid.',
        technicalDetail: '服务拒绝访问',
      ),
    );

    await expectLater(
      notifier.fetchModels(
        apiKey: 'test-key',
        baseUrl: 'https://proxy.example/v1',
      ),
      throwsA(isA<AppException>()),
    );

    expect(
      notifier.state.messageFor(const Locale('en')),
      'The credentials are invalid.',
    );
    expect(notifier.state.messageFor(const Locale('zh')), '凭据无效。 服务返回：服务拒绝访问');
  });

  test('保存新的运行配置不会中断现有状态并更新后续任务模型', () async {
    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();
    final repository = SettingsRepository(preferences, MemoryApiKeyStore());
    await repository.save(
      const SettingsState(apiKey: 'old-key', baseUrl: 'https://old.example/v1'),
    );
    final settings = SettingsNotifier(repository);
    final container = ProviderContainer(
      overrides: [
        settingsProvider.overrideWith((ref) => settings),
        audioRecordManagerProvider.overrideWithValue(_FakeRecorder()),
        ttsPlaybackManagerProvider.overrideWithValue(
          const _SilentPlaybackController(),
        ),
      ],
    );
    addTearDown(container.dispose);

    container.read(sttProvider.notifier).updateEditedText('正在处理的转录草稿');
    container.read(ttsProvider.notifier).setSpeed(1.5);

    await container
        .read(settingsProvider.notifier)
        .save(
          apiKey: 'new-key',
          baseUrl: 'https://new.example/v1',
          sttModel: 'gpt-4o-transcribe',
          ttsModel: 'bytedance/seed-tts-2.0',
        );

    expect(container.read(sttProvider).editedText, '正在处理的转录草稿');
    expect(container.read(ttsProvider).speed, 1.5);
    expect(container.read(ttsProvider).voice, 'zh_female_cancan_uranus_bigtts');
  });

  test('重置本地偏好恢复默认状态且不清除隐私确认', () async {
    SharedPreferences.setMockInitialValues({
      'privacy_notice.acknowledged.v1': true,
    });
    final preferences = await SharedPreferences.getInstance();
    final repository = SettingsRepository(preferences, MemoryApiKeyStore());
    await repository.save(
      const SettingsState(
        apiKey: 'test-key',
        baseUrl: 'https://proxy.example/v1',
        sttModel: 'gpt-4o-transcribe',
        ttsModel: 'gpt-4o-mini-tts',
        themePreference: AppThemePreference.dark,
        localePreference: AppLocalePreference.english,
      ),
    );
    final notifier = SettingsNotifier(repository);
    addTearDown(notifier.dispose);

    final feedback = await notifier.resetLocalPreferences();

    const defaults = SettingsState();
    expect(notifier.state.apiKey, defaults.apiKey);
    expect(notifier.state.baseUrl, defaults.baseUrl);
    expect(notifier.state.sttModel, defaults.sttModel);
    expect(notifier.state.ttsModel, defaults.ttsModel);
    expect(notifier.state.themePreference, defaults.themePreference);
    expect(notifier.state.localePreference, defaults.localePreference);
    expect(
      feedback.resolve(const Locale('en')),
      'Local preferences were reset.',
    );
    expect(preferences.getBool('privacy_notice.acknowledged.v1'), isTrue);
  });

  test('即时偏好保存期间保持忙碌并拒绝并发设置写入', () async {
    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();
    final repository = _DelayedSettingsRepository(
      preferences,
      MemoryApiKeyStore(),
    );
    final notifier = SettingsNotifier(repository);
    addTearDown(notifier.dispose);

    final pending = notifier.setThemePreference(AppThemePreference.dark);
    await repository.saveStarted.future;

    expect(notifier.state.isBusy, isTrue);
    expect(
      () => notifier.setLocalePreference(AppLocalePreference.english),
      throwsA(isA<AppException>()),
    );

    repository.allowSave.complete();
    await pending;
    expect(notifier.state.isBusy, isFalse);
    expect(notifier.state.themePreference, AppThemePreference.dark);
  });
}

class _DelayedSettingsRepository extends SettingsRepository {
  _DelayedSettingsRepository(super.preferences, super.apiKeyStore);

  final saveStarted = Completer<void>();
  final allowSave = Completer<void>();

  @override
  Future<void> save(SettingsState settings) async {
    saveStarted.complete();
    await allowSave.future;
    await super.save(settings);
  }
}

class _FakeRecorder implements AudioRecordManager {
  @override
  Future<void> start() async {}

  @override
  Future<void> pause() async {}

  @override
  Future<void> resume() async {}

  @override
  Future<File> stop() async => File('unused');

  @override
  Future<void> cancel() async {}

  @override
  Future<void> dispose() async {}
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
