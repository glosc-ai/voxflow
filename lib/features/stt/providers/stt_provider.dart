import 'dart:async';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/errors/app_exception.dart';
import '../../../core/services/permission_service.dart';
import '../../../core/services/platform_clock.dart';
import '../../../core/utils/path_utils.dart';
import '../../../core/utils/transcript_exporter.dart';
import '../../history/models/history_record.dart';
import '../../history/providers/history_provider.dart';
import '../../settings/providers/settings_provider.dart';
import '../models/stt_state.dart';
import '../services/audio_record_manager.dart';
import '../services/seed_asr_api_service.dart';
import '../services/whisper_api_service.dart';

typedef HistoryWriter = Future<void> Function({
  required HistoryType type,
  required String text,
  required String audioPath,
});

typedef UtcNow = Future<DateTime> Function();
typedef RequiresPcmWav = bool Function();

final permissionServiceProvider = Provider<PermissionService>((ref) {
  return const PermissionService();
});

final audioRecordManagerProvider = Provider<AudioRecordManager>((ref) {
  final manager = AudioRecordManager(
    permissionService: ref.watch(permissionServiceProvider),
  );
  ref.onDispose(manager.dispose);
  return manager;
});

final whisperApiServiceProvider = Provider<WhisperApiService>((ref) {
  return WhisperApiService(ref.watch(dioClientProvider));
});

final historyWriterProvider = Provider<HistoryWriter>((ref) {
  return ({required type, required text, required audioPath}) async {
    await ref.read(historyProvider.notifier).add(
          type: type,
          text: text,
          audioPath: audioPath,
        );
  };
});

final sttProvider = StateNotifierProvider<SttNotifier, SttState>((ref) {
  return SttNotifier(
    recorder: ref.watch(audioRecordManagerProvider),
    apiService: ref.watch(whisperApiServiceProvider),
    historyWriter: ref.watch(historyWriterProvider),
    requiresPcmWav: () => SeedAsrApiService.supportsModel(
      ref.read(settingsProvider).sttModel,
    ),
  );
});

class SttNotifier extends StateNotifier<SttState> {
  SttNotifier({
    required AudioRecordManager recorder,
    required WhisperApiService apiService,
    required HistoryWriter historyWriter,
    UtcNow? nowUtc,
    RequiresPcmWav? requiresPcmWav,
  })  : _recorder = recorder,
        _apiService = apiService,
        _historyWriter = historyWriter,
        _nowUtc = nowUtc ?? PlatformClock.nowUtc,
        _requiresPcmWav = requiresPcmWav ?? _neverRequiresPcmWav,
        super(const SttState());

  final AudioRecordManager _recorder;
  final WhisperApiService _apiService;
  final HistoryWriter _historyWriter;
  final UtcNow _nowUtc;
  final RequiresPcmWav _requiresPcmWav;
  DateTime? _recordingSegmentStartedAt;
  Duration _recordedElapsed = Duration.zero;
  Timer? _elapsedTimer;
  bool _clockReadInProgress = false;
  bool _disposed = false;

  Future<void> startRecording() async {
    if (!state.canStart) {
      return;
    }
    state = const SttState(phase: SttPhase.countdown, countdown: 3);
    try {
      for (var value = 3; value > 0; value--) {
        state = state.copyWith(phase: SttPhase.countdown, countdown: value);
        await _delayUsingClock(const Duration(seconds: 1));
        if (_disposed || state.phase != SttPhase.countdown) {
          return;
        }
      }
      if (_disposed || state.phase != SttPhase.countdown) {
        return;
      }
      await _recorder.start(requireWav: _requiresPcmWav());
      _recordedElapsed = Duration.zero;
      _recordingSegmentStartedAt = await _nowUtc();
      state = state.copyWith(
        phase: SttPhase.recording,
        countdown: 0,
        elapsed: Duration.zero,
        clearError: true,
      );
      _startElapsedTimer();
    } catch (error) {
      _setFailure(error, '无法开始录音。');
    }
  }

  Future<void> pauseRecording() async {
    if (state.phase != SttPhase.recording) {
      return;
    }
    try {
      await _recorder.pause();
      _elapsedTimer?.cancel();
      await _accumulateElapsed();
      state = state.copyWith(
        phase: SttPhase.paused,
        elapsed: _roundedRecordedElapsed,
        clearError: true,
      );
    } catch (error) {
      _setRecoverableError(error, '暂停录音失败。');
    }
  }

  Future<void> resumeRecording() async {
    if (state.phase != SttPhase.paused) {
      return;
    }
    try {
      await _recorder.resume();
      _recordingSegmentStartedAt = await _nowUtc();
      state = state.copyWith(phase: SttPhase.recording, clearError: true);
      _startElapsedTimer();
    } catch (error) {
      _setRecoverableError(error, '继续录音失败。');
    }
  }

  Future<void> stopRecording() async {
    if (!state.isRecording) {
      return;
    }
    _elapsedTimer?.cancel();
    await _accumulateElapsed();
    state = state.copyWith(elapsed: _roundedRecordedElapsed);
    try {
      final file = await _recorder.stop();
      await transcribeFile(file, removeSourceAfterSuccess: true);
    } catch (error) {
      await _recorder.cancel();
      _setFailure(error, '停止录音失败。');
    }
  }

  Future<void> pickAndTranscribe() async {
    if (!state.canStart) {
      return;
    }
    try {
      final selection = await FilePicker.platform.pickFiles(
        dialogTitle: '选择音频或视频文件',
        type: FileType.custom,
        allowedExtensions: _requiresPcmWav()
            ? const ['wav']
            : AppConstants.supportedImportExtensions,
        allowMultiple: false,
      );
      if (selection == null) {
        return;
      }
      final path = selection.files.single.path;
      if (path == null) {
        throw const AppException(
          AppErrorCode.fileNotFound,
          '无法访问所选文件。',
        );
      }
      await transcribeFile(File(path));
    } catch (error) {
      _setFailure(error, '导入文件失败。');
    }
  }

  Future<void> transcribeFile(
    File file, {
    bool removeSourceAfterSuccess = false,
  }) async {
    File? managedFile;
    state = SttState(
      phase: SttPhase.uploading,
      selectedFilePath: file.path,
      elapsed: state.elapsed,
    );
    try {
      final result = await _apiService.transcribe(
        file,
        onUploadProgress: (progress) {
          state = state.copyWith(
            phase: progress >= 1 ? SttPhase.transcribing : SttPhase.uploading,
            uploadProgress: progress,
          );
        },
      );
      state = state.copyWith(
        phase: SttPhase.transcribing,
        uploadProgress: 1,
      );
      managedFile = await PathUtils.persistManagedAudio(file, category: 'stt');
      final resultWithSource = result.copyWith(sourcePath: managedFile.path);
      await _historyWriter(
        type: HistoryType.stt,
        text: result.text,
        audioPath: managedFile.path,
      );
      if (removeSourceAfterSuccess && await file.exists()) {
        await file.delete();
      }
      state = SttState(
        phase: SttPhase.success,
        uploadProgress: 1,
        selectedFilePath: managedFile.path,
        result: resultWithSource,
        editedText: result.text,
        elapsed: state.elapsed,
      );
    } catch (error) {
      if (managedFile != null) {
        try {
          if (await managedFile.exists()) {
            await managedFile.delete();
          }
        } catch (_) {
          // Best-effort cleanup for an operation that did not complete.
        }
      }
      if (removeSourceAfterSuccess) {
        try {
          if (await file.exists()) {
            await file.delete();
          }
        } catch (_) {
          // Best-effort cleanup for temporary recordings.
        }
      }
      _setFailure(error, '音频转录失败，请稍后重试。');
    }
  }

  void updateEditedText(String value) {
    state = state.copyWith(editedText: value);
  }

  Future<bool> exportText() async {
    if (!state.canExport) {
      return false;
    }
    return TranscriptExporter.saveText(
      contents: TranscriptExporter.toText(state.editedText),
      extension: 'txt',
    );
  }

  Future<bool> exportSrt() async {
    final result = state.result;
    if (result == null) {
      return false;
    }
    return TranscriptExporter.saveText(
      contents: TranscriptExporter.toSrt(result),
      extension: 'srt',
    );
  }

  void reset() {
    _elapsedTimer?.cancel();
    _recordingSegmentStartedAt = null;
    _recordedElapsed = Duration.zero;
    state = const SttState();
  }

  void _startElapsedTimer() {
    _elapsedTimer?.cancel();
    _elapsedTimer = Timer.periodic(
      const Duration(seconds: 1),
      (_) => unawaited(_syncElapsed()),
    );
  }

  Future<void> _syncElapsed() async {
    if (_clockReadInProgress || _disposed || !state.isRecording) {
      return;
    }
    final startedAt = _recordingSegmentStartedAt;
    if (startedAt == null) {
      return;
    }
    _clockReadInProgress = true;
    try {
      final now = await _nowUtc();
      if (_disposed ||
          !state.isRecording ||
          startedAt != _recordingSegmentStartedAt) {
        return;
      }
      var elapsed = _recordedElapsed;
      final currentSegment = now.difference(startedAt);
      if (!currentSegment.isNegative) {
        elapsed += currentSegment;
      }
      elapsed = Duration(seconds: elapsed.inSeconds);
      if (elapsed != state.elapsed) {
        state = state.copyWith(elapsed: elapsed);
      }
    } finally {
      _clockReadInProgress = false;
    }
  }

  Future<void> _accumulateElapsed() async {
    final startedAt = _recordingSegmentStartedAt;
    _recordingSegmentStartedAt = null;
    if (startedAt == null) {
      return;
    }
    final segment = (await _nowUtc()).difference(startedAt);
    if (!segment.isNegative) {
      _recordedElapsed += segment;
    }
  }

  Future<void> _delayUsingClock(Duration duration) async {
    final deadline = (await _nowUtc()).add(duration);
    while (!_disposed) {
      if (!(await _nowUtc()).isBefore(deadline)) {
        return;
      }
      await Future<void>.delayed(const Duration(seconds: 1));
    }
  }

  Duration get _roundedRecordedElapsed =>
      Duration(seconds: _recordedElapsed.inSeconds);

  void _setFailure(Object error, String fallback) {
    _elapsedTimer?.cancel();
    _recordingSegmentStartedAt = null;
    final message = error is AppException ? error.message : fallback;
    state = state.copyWith(
      phase: SttPhase.failure,
      errorMessage: message,
    );
  }

  void _setRecoverableError(Object error, String fallback) {
    final message = error is AppException ? error.message : fallback;
    state = state.copyWith(errorMessage: message);
  }

  @override
  void dispose() {
    _disposed = true;
    _elapsedTimer?.cancel();
    _recordingSegmentStartedAt = null;
    super.dispose();
  }
}

bool _neverRequiresPcmWav() => false;
