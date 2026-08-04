import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:voxflow/core/errors/app_exception.dart';
import 'package:voxflow/features/history/models/history_record.dart';
import 'package:voxflow/features/history/providers/history_provider.dart';
import 'package:voxflow/features/settings/models/settings_state.dart';
import 'package:voxflow/features/stt/models/stt_state.dart';
import 'package:voxflow/features/tts/models/tts_state.dart';
import 'package:voxflow/features/tts/services/audio_playback_manager.dart';

void main() {
  test('AppMessage resolves Chinese and English with redacted detail', () {
    const message = AppMessage(
      zh: '请求失败。',
      en: 'The request failed.',
      technicalDetail: 'code=denied; token=[REDACTED]',
    );

    expect(
      message.resolve(const Locale('zh', 'CN')),
      '请求失败。 服务返回：code=denied; token=[REDACTED]',
    );
    expect(
      message.resolve(const Locale('en', 'US')),
      'The request failed. Service response: code=denied; token=[REDACTED]',
    );
    expect(
      message.resolve(const Locale('de')),
      'The request failed. Service response: code=denied; token=[REDACTED]',
    );
  });

  test('English messages do not expose untranslated Chinese service detail',
      () {
    const message = AppMessage(
      zh: '请求失败。',
      en: 'The request failed.',
      technicalDetail: '上游服务暂时不可用 code=busy',
    );

    expect(
      message.resolve(const Locale('zh', 'CN')),
      '请求失败。 服务返回：上游服务暂时不可用 code=busy',
    );
    expect(
      message.resolve(const Locale('en', 'US')),
      'The request failed.',
    );
  });

  test('settings state resolves structured feedback for the active locale', () {
    const state = SettingsState(
      feedback: AppMessage(
        zh: '连接失败。',
        en: 'Connection failed.',
      ),
    );

    expect(state.message, '连接失败。');
    expect(state.messageFor(const Locale('en')), 'Connection failed.');
    expect(state.copyWith(clearMessage: true).message, isNull);
  });

  test('AppException keeps its code and compatible Chinese message getter', () {
    const exception = AppException(
      AppErrorCode.unauthorized,
      '无权访问。',
      englishMessage: 'Access is denied.',
      technicalDetail: 'code=permission_error',
    );

    expect(exception.code, AppErrorCode.unauthorized);
    expect(exception.message, '无权访问。 服务返回：code=permission_error');
    expect(exception.toString(), exception.message);
    expect(
      exception.englishMessage,
      'Access is denied. Service response: code=permission_error',
    );
    expect(
      exception.messageFor(const Locale('en')),
      exception.englishMessage,
    );
  });

  test('legacy exceptions receive a reliable English fallback by code', () {
    const exception = AppException(
      AppErrorCode.fileNotFound,
      '文件不存在。',
    );

    expect(exception.message, '文件不存在。');
    expect(exception.englishMessage, 'The requested file could not be found.');
  });

  test('feature states preserve bilingual errors and legacy strings', () {
    const message = AppMessage(
      zh: '播放失败。',
      en: 'Playback failed.',
    );
    const stt = SttState(error: message);
    const tts = TtsState(error: message);
    const history = HistoryPlaybackState(error: message);

    expect(stt.errorMessage, '播放失败。');
    expect(stt.errorMessageFor(const Locale('en')), 'Playback failed.');
    expect(tts.errorMessageFor(const Locale('en')), 'Playback failed.');
    expect(history.errorMessageFor(const Locale('en')), 'Playback failed.');

    const legacy = TtsState(errorMessage: '旧版错误。');
    expect(legacy.errorMessage, '旧版错误。');
    expect(legacy.errorMessageFor(const Locale('en')), '旧版错误。');
    expect(tts.copyWith(clearError: true).errorMessage, isNull);
  });

  test('history playback fallback is available in both languages', () async {
    final notifier = HistoryPlaybackNotifier(_FailingPlayback());
    addTearDown(notifier.dispose);

    await notifier.toggle(
      HistoryRecord(
        id: 1,
        type: HistoryType.tts,
        text: 'test',
        audioPath: 'missing.mp3',
        createdAt: DateTime.utc(2026),
      ),
    );

    expect(notifier.state.errorMessage, '无法播放历史音频。');
    expect(
      notifier.state.errorMessageFor(const Locale('en')),
      'Unable to play the history audio.',
    );
  });
}

class _FailingPlayback implements PlaybackController {
  @override
  Stream<void> get completions => const Stream.empty();

  @override
  Stream<Duration> get durationChanges => const Stream.empty();

  @override
  Stream<Duration> get positionChanges => const Stream.empty();

  @override
  Future<void> load(String path) async {
    throw StateError('internal failure');
  }

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
