import 'dart:async';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/errors/app_exception.dart';
import '../../history/models/history_record.dart';
import '../../history/providers/history_provider.dart';
import '../../settings/providers/settings_provider.dart';
import '../models/tts_request.dart';
import '../models/tts_state.dart';
import '../services/audio_playback_manager.dart';
import '../services/tts_api_service.dart';

typedef TtsHistoryWriter = Future<void> Function({
  required String text,
  required String audioPath,
});

final ttsApiServiceProvider = Provider<TtsApiService>((ref) {
  return TtsApiService(ref.watch(dioClientProvider));
});

final ttsPlaybackManagerProvider = Provider<PlaybackController>((ref) {
  final manager = AudioPlaybackManager();
  ref.onDispose(manager.dispose);
  return manager;
});

final ttsHistoryWriterProvider = Provider<TtsHistoryWriter>((ref) {
  return ({required text, required audioPath}) async {
    await ref.read(historyProvider.notifier).add(
          type: HistoryType.tts,
          text: text,
          audioPath: audioPath,
        );
  };
});

final ttsProvider = StateNotifierProvider<TtsNotifier, TtsState>((ref) {
  final notifier = TtsNotifier(
    apiService: ref.watch(ttsApiServiceProvider),
    playback: ref.watch(ttsPlaybackManagerProvider),
    historyWriter: ref.watch(ttsHistoryWriterProvider),
    model: ref.read(settingsProvider).ttsModel,
  );
  ref.listen<String>(
    settingsProvider.select((settings) => settings.ttsModel),
    (_, model) => notifier.updateModel(model),
  );
  return notifier;
});

class TtsNotifier extends StateNotifier<TtsState> {
  TtsNotifier({
    required TtsApiService apiService,
    required PlaybackController playback,
    required TtsHistoryWriter historyWriter,
    required String model,
  })  : _apiService = apiService,
        _playback = playback,
        _historyWriter = historyWriter,
        _model = model,
        super(
          TtsState(
            voice: AppConstants.defaultTtsVoiceForModel(model),
          ),
        ) {
    _positionSubscription = _playback.positionChanges.listen((position) {
      state = state.copyWith(position: position);
    });
    _durationSubscription = _playback.durationChanges.listen((duration) {
      state = state.copyWith(duration: duration);
    });
    _completionSubscription = _playback.completions.listen((_) {
      state = state.copyWith(
        phase: TtsPhase.completed,
        position: state.duration,
      );
    });
  }

  final TtsApiService _apiService;
  final PlaybackController _playback;
  final TtsHistoryWriter _historyWriter;
  String _model;
  late final StreamSubscription<Duration> _positionSubscription;
  late final StreamSubscription<Duration> _durationSubscription;
  late final StreamSubscription<void> _completionSubscription;

  List<String> get availableVoices => AppConstants.ttsVoicesForModel(_model);

  bool get usesSeedTtsSpeakerIds =>
      _model.trim().toLowerCase() == AppConstants.seedTtsModel;

  void updateModel(String model) {
    final normalized = model.trim();
    if (normalized.isEmpty || normalized == _model) {
      return;
    }
    _model = normalized;
    final voices = availableVoices;
    state = state.copyWith(
      voice: voices.contains(state.voice)
          ? state.voice
          : AppConstants.defaultTtsVoiceForModel(_model),
      clearError: true,
    );
  }

  void setVoice(String voice) {
    if (availableVoices.contains(voice) && !state.isGenerating) {
      state = state.copyWith(voice: voice, clearError: true);
    }
  }

  void setSpeed(double speed) {
    if (!state.isGenerating) {
      state = state.copyWith(speed: speed.clamp(0.25, 4.0), clearError: true);
    }
  }

  Future<void> synthesize(String text) async {
    if (state.isGenerating) {
      return;
    }
    state = state.copyWith(
      phase: TtsPhase.generating,
      position: Duration.zero,
      duration: Duration.zero,
      clearError: true,
    );
    File? output;
    try {
      final request = TtsRequest(
        text: text,
        model: _model,
        voice: state.voice,
        speed: state.speed,
      ).validated();
      output = await _apiService.synthesize(request);
      await _playback.load(output.path);
      await _playback.setVolume(state.volume);
      await _historyWriter(text: request.text, audioPath: output.path);
      state = state.copyWith(
        phase: TtsPhase.ready,
        audioPath: output.path,
        position: Duration.zero,
        clearError: true,
      );
    } catch (error) {
      if (output != null) {
        try {
          await _playback.stop();
          if (await output.exists()) {
            await output.delete();
          }
        } catch (_) {
          // Best-effort cleanup for a synthesis that did not complete.
        }
      }
      _setFailure(
        error,
        const AppMessage(
          zh: '语音合成失败，请稍后重试。',
          en: 'Speech synthesis failed. Try again later.',
        ),
      );
    }
  }

  Future<void> playOrPause() async {
    if (!state.hasAudio) {
      return;
    }
    try {
      if (state.isPlaying) {
        await _playback.pause();
        state = state.copyWith(phase: TtsPhase.paused, clearError: true);
        return;
      }
      if (state.phase == TtsPhase.completed) {
        await _playback.seek(Duration.zero);
        state = state.copyWith(position: Duration.zero);
      }
      await _playback.play();
      state = state.copyWith(phase: TtsPhase.playing, clearError: true);
    } catch (error) {
      _setFailure(
        error,
        const AppMessage(
          zh: '播放音频失败。',
          en: 'Unable to play the audio.',
        ),
      );
    }
  }

  Future<void> seek(Duration position) async {
    if (!state.hasAudio) {
      return;
    }
    final maximum = state.duration;
    final target = position < Duration.zero
        ? Duration.zero
        : (maximum > Duration.zero && position > maximum ? maximum : position);
    try {
      await _playback.seek(target);
      state = state.copyWith(position: target, clearError: true);
    } catch (error) {
      _setFailure(
        error,
        const AppMessage(
          zh: '调整播放进度失败。',
          en: 'Unable to seek in the audio.',
        ),
      );
    }
  }

  Future<void> setVolume(double volume) async {
    final normalized = volume.clamp(0.0, 1.0);
    state = state.copyWith(volume: normalized);
    try {
      await _playback.setVolume(normalized);
    } catch (error) {
      _setFailure(
        error,
        const AppMessage(
          zh: '调整音量失败。',
          en: 'Unable to change the volume.',
        ),
      );
    }
  }

  Future<bool> saveCopy({String dialogTitle = '保存合成语音'}) async {
    final audioPath = state.audioPath;
    if (audioPath == null) {
      return false;
    }
    try {
      final source = File(audioPath);
      if (!await source.exists()) {
        throw const AppException(
          AppErrorCode.fileNotFound,
          '合成音频文件不存在。',
          englishMessage: 'The generated audio file could not be found.',
        );
      }
      final path = await FilePicker.platform.saveFile(
        dialogTitle: dialogTitle,
        fileName: 'voxflow_${DateTime.now().millisecondsSinceEpoch}.mp3',
        type: FileType.custom,
        allowedExtensions: const ['mp3'],
        bytes: Platform.isAndroid ? await source.readAsBytes() : null,
      );
      if (path == null) {
        return false;
      }
      if (!Platform.isAndroid &&
          File(path).absolute.path != source.absolute.path) {
        await source.copy(path);
      }
      return true;
    } on AppException {
      rethrow;
    } catch (_) {
      throw const AppException(
        AppErrorCode.storageFailure,
        '保存 MP3 失败，请重新选择位置。',
        englishMessage: 'Unable to save the MP3 file. Choose another location.',
      );
    }
  }

  void _setFailure(Object error, AppMessage fallback) {
    final message = error is AppException ? error.localizedMessage : fallback;
    state = state.copyWith(
      phase: TtsPhase.failure,
      error: message,
    );
  }

  @override
  void dispose() {
    _positionSubscription.cancel();
    _durationSubscription.cancel();
    _completionSubscription.cancel();
    super.dispose();
  }
}
