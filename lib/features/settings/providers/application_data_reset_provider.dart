import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/app_exception.dart';
import '../../history/providers/history_provider.dart';
import '../../shell/providers/navigation_provider.dart';
import '../../stt/providers/stt_provider.dart';
import '../../tts/providers/tts_provider.dart';
import '../services/application_data_reset_service.dart';
import 'privacy_notice_provider.dart';
import 'settings_provider.dart';

final applicationDataResetServiceProvider =
    Provider<ApplicationDataResetService>((ref) {
      return ApplicationDataResetService(
        preferences: ref.watch(sharedPreferencesProvider),
        apiKeyStore: ref.watch(apiKeyStoreProvider),
        historyRepository: ref.watch(historyRepositoryProvider),
        logger: ref.watch(appLoggerProvider),
      );
    });

final applicationDataResetProvider =
    StateNotifierProvider<ApplicationDataResetNotifier, AsyncValue<void>>((
      ref,
    ) {
      return ApplicationDataResetNotifier(ref);
    });

class ApplicationDataResetNotifier extends StateNotifier<AsyncValue<void>> {
  ApplicationDataResetNotifier(this._ref) : super(const AsyncValue.data(null));

  final Ref _ref;

  Future<AppMessage> resetAllData() async {
    if (state.isLoading) {
      throw const AppException(
        AppErrorCode.invalidConfiguration,
        '正在清空本机数据，请稍候。',
        englishMessage: 'Local data is already being cleared.',
      );
    }
    final sttState = _ref.read(sttProvider);
    final ttsState = _ref.read(ttsProvider);
    if (_ref.read(settingsProvider).isBusy ||
        sttState.isProcessing ||
        ttsState.isGenerating) {
      throw const AppException(
        AppErrorCode.invalidConfiguration,
        '请等待当前语音任务结束后再清空数据。',
        englishMessage:
            'Wait for the current speech task to finish before clearing data.',
      );
    }

    state = const AsyncValue.loading();
    var persistentCleanupStarted = false;
    try {
      if (sttState.hasActiveRecordingSession &&
          !await _ref.read(sttProvider.notifier).cancelRecording()) {
        throw const AppException(
          AppErrorCode.recordingUnavailable,
          '无法停止当前录音，数据尚未清除。',
          englishMessage:
              'The active recording could not be stopped. No data was cleared.',
        );
      }
      await _ref.read(historyPlaybackProvider.notifier).stop();
      await _ref.read(ttsProvider.notifier).reset();
      await _ref.read(sttProvider.notifier).reset();
      persistentCleanupStarted = true;
      await _ref.read(applicationDataResetServiceProvider).reset();
      await _synchronizeLiveState();
      _ref.read(navigationIndexProvider.notifier).state = 0;
      state = const AsyncValue.data(null);
      return const AppMessage(
        zh: '全部本机数据已清除。',
        en: 'All local app data was cleared.',
      );
    } catch (error, stackTrace) {
      if (persistentCleanupStarted) {
        await _synchronizeLiveStateBestEffort();
      }
      final mapped = error is AppException
          ? error
          : const AppException(
              AppErrorCode.storageFailure,
              '无法清空全部本机数据，请重试。',
              englishMessage: 'Unable to clear all local data. Try again.',
            );
      state = AsyncValue.error(mapped, stackTrace);
      throw mapped;
    }
  }

  Future<void> _synchronizeLiveState() async {
    await _ref.read(settingsProvider.notifier).reloadAfterDataReset();
    await _ref.read(historyProvider.notifier).reloadAfterDataReset();
    _ref.invalidate(privacyNoticeProvider);
  }

  Future<void> _synchronizeLiveStateBestEffort() async {
    try {
      await _ref.read(settingsProvider.notifier).reloadAfterDataReset();
    } catch (_) {
      // Preserve the reset failure while removing stale state where possible.
    }
    try {
      await _ref.read(historyProvider.notifier).reloadAfterDataReset();
    } catch (_) {
      // Preserve the reset failure while removing stale state where possible.
    }
    _ref.invalidate(privacyNoticeProvider);
  }
}
