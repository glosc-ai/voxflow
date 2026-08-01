import 'dart:async';
import 'dart:io';
import 'dart:ui' show Locale;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/app_exception.dart';
import '../../../core/utils/path_utils.dart';
import '../../tts/services/audio_playback_manager.dart';
import '../models/history_record.dart';
import '../services/history_repository.dart';

final historyRepositoryProvider = Provider<HistoryRepository>((ref) {
  final repository = HistoryRepository();
  ref.onDispose(repository.close);
  return repository;
});

final historyProvider =
    StateNotifierProvider<HistoryNotifier, AsyncValue<List<HistoryRecord>>>(
        (ref) {
  final notifier = HistoryNotifier(ref.watch(historyRepositoryProvider));
  Future.microtask(notifier.load);
  return notifier;
});

final historyPlaybackManagerProvider = Provider<PlaybackController>((ref) {
  final manager = AudioPlaybackManager();
  ref.onDispose(manager.dispose);
  return manager;
});

final historyPlaybackProvider =
    StateNotifierProvider<HistoryPlaybackNotifier, HistoryPlaybackState>((ref) {
  return HistoryPlaybackNotifier(ref.watch(historyPlaybackManagerProvider));
});

class HistoryNotifier extends StateNotifier<AsyncValue<List<HistoryRecord>>> {
  HistoryNotifier(this._repository) : super(const AsyncValue.loading());

  final HistoryRepository _repository;
  String _query = '';

  Future<void> load({String? query}) async {
    if (query != null) {
      _query = query;
    }
    final cachedRecords = state.valueOrNull;
    state = cachedRecords == null
        ? const AsyncValue.loading()
        : const AsyncValue<List<HistoryRecord>>.loading().copyWithPrevious(
            AsyncValue.data(cachedRecords),
          );
    try {
      state = AsyncValue.data(await _repository.search(_query));
    } catch (error, stackTrace) {
      final localizedError = error is AppException
          ? error
          : const AppException(
              AppErrorCode.storageFailure,
              '无法读取历史记录。',
              englishMessage: 'Unable to load history.',
            );
      final failure = AsyncValue<List<HistoryRecord>>.error(
        localizedError,
        stackTrace,
      );
      state = cachedRecords == null
          ? failure
          : failure.copyWithPrevious(AsyncValue.data(cachedRecords));
    }
  }

  Future<HistoryRecord> add({
    required HistoryType type,
    required String text,
    required String audioPath,
  }) async {
    try {
      final inserted = await _repository.insert(
        HistoryRecord(
          type: type,
          text: text,
          audioPath: audioPath,
          createdAt: DateTime.now().toUtc(),
        ),
      );
      await load();
      return inserted;
    } on AppException {
      rethrow;
    } catch (_) {
      throw const AppException(
        AppErrorCode.storageFailure,
        '无法保存历史记录。',
        englishMessage: 'Unable to save the history record.',
      );
    }
  }

  Future<String?> delete(HistoryRecord record) async {
    final id = record.id;
    if (id == null) {
      throw const AppException(
        AppErrorCode.storageFailure,
        '历史记录无效，无法删除。',
        englishMessage: 'The history record is invalid and cannot be deleted.',
      );
    }
    await _repository.delete(id);
    await load();
    String? warning;
    try {
      if (await PathUtils.isManagedAudioPath(record.audioPath)) {
        final file = File(record.audioPath);
        if (await file.exists()) {
          await file.delete();
        }
      }
    } catch (_) {
      warning = '记录已删除，但音频文件未能清理。';
    }
    return warning;
  }
}

class HistoryPlaybackState {
  const HistoryPlaybackState({
    this.recordId,
    this.isPlaying = false,
    this.error,
    String? errorMessage,
  }) : _legacyErrorMessage = errorMessage;

  final int? recordId;
  final bool isPlaying;
  final AppMessage? error;
  final String? _legacyErrorMessage;

  /// Chinese compatibility getter used by the current views.
  String? get errorMessage =>
      error?.resolve(const Locale('zh')) ?? _legacyErrorMessage;

  String? errorMessageFor(Locale locale) =>
      error?.resolve(locale) ?? _legacyErrorMessage;
}

class HistoryPlaybackNotifier extends StateNotifier<HistoryPlaybackState> {
  HistoryPlaybackNotifier(this._playback)
      : super(const HistoryPlaybackState()) {
    _completionSubscription = _playback.completions.listen((_) {
      state = HistoryPlaybackState(recordId: state.recordId);
    });
  }

  final PlaybackController _playback;
  late final StreamSubscription<void> _completionSubscription;

  Future<void> toggle(HistoryRecord record) async {
    try {
      if (record.id == state.recordId && state.isPlaying) {
        await _playback.pause();
        state = HistoryPlaybackState(recordId: record.id);
        return;
      }
      if (record.id != state.recordId) {
        await _playback.load(record.audioPath);
      }
      await _playback.play();
      state = HistoryPlaybackState(recordId: record.id, isPlaying: true);
    } catch (error) {
      state = HistoryPlaybackState(
        recordId: record.id,
        error: error is AppException
            ? error.localizedMessage
            : const AppMessage(
                zh: '无法播放历史音频。',
                en: 'Unable to play the history audio.',
              ),
      );
    }
  }

  Future<void> stop() async {
    try {
      await _playback.stop();
    } catch (_) {
      // The record can still be deleted if stopping a missing file fails.
    }
    state = const HistoryPlaybackState();
  }

  @override
  void dispose() {
    _completionSubscription.cancel();
    super.dispose();
  }
}
