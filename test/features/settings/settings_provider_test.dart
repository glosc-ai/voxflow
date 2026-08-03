import 'dart:io';
import 'dart:ui';

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

void main() {
  test('获取模型的瞬态设置变化不会重置语音工作状态', () async {
    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();
    final repository = SettingsRepository(preferences);
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

    await container.read(settingsProvider.notifier).fetchModels(
          apiKey: 'test-key',
          baseUrl: 'https://proxy.example/v1',
        );

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
      SettingsRepository(preferences),
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
    expect(
      notifier.state.messageFor(const Locale('zh')),
      '凭据无效。 服务返回：服务拒绝访问',
    );
  });

  test('保存新的运行配置不会中断现有状态并更新后续任务模型', () async {
    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();
    final repository = SettingsRepository(preferences);
    await repository.save(
      const SettingsState(
        apiKey: 'old-key',
        baseUrl: 'https://old.example/v1',
      ),
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

    await container.read(settingsProvider.notifier).save(
          apiKey: 'new-key',
          baseUrl: 'https://new.example/v1',
          sttModel: 'gpt-4o-transcribe',
          ttsModel: 'bytedance/seed-tts-2.0',
        );

    expect(container.read(sttProvider).editedText, '正在处理的转录草稿');
    expect(container.read(ttsProvider).speed, 1.5);
    expect(
      container.read(ttsProvider).voice,
      'zh_female_cancan_uranus_bigtts',
    );
  });

  test('重置本地偏好恢复默认状态且不清除隐私确认', () async {
    SharedPreferences.setMockInitialValues({
      'privacy_notice.acknowledged.v1': true,
    });
    final preferences = await SharedPreferences.getInstance();
    final repository = SettingsRepository(preferences);
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
        feedback.resolve(const Locale('en')), 'Local preferences were reset.');
    expect(preferences.getBool('privacy_notice.acknowledged.v1'), isTrue);
  });
}

class _FakeRecorder implements AudioRecordManager {
  @override
  Future<void> start({bool requireWav = false}) async {}

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
  Future<void> setVolume(double volume) async {}

  @override
  Future<void> stop() async {}
}
