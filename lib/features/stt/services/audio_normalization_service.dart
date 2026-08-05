import 'dart:async';
import 'dart:io';

import 'package:ffmpeg_kit_extended_flutter/ffmpeg_kit_extended_flutter.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/errors/app_exception.dart';
import '../../../core/logging/app_logger.dart';
import '../../../core/utils/path_utils.dart';
import 'seed_asr_pcm_wav.dart';

typedef AudioTranscodeRunner =
    Future<int?> Function(List<String> arguments, Duration timeout);

typedef TemporaryAudioPathProvider =
    Future<String> Function({required String stem, required String extension});

/// Keeps FFmpeg, output validation, and temporary-file ownership behind one
/// callback-scoped interface. The callback may retain data derived from the
/// file, but the normalized file itself is deleted before this method returns.
abstract interface class AudioNormalizationService {
  Future<T> withSeedAsrAudio<T>(
    File source,
    Future<T> Function(File normalizedFile, SeedAsrPcmWavAudio normalizedAudio)
    use,
  );
}

class FfmpegAudioNormalizationService implements AudioNormalizationService {
  FfmpegAudioNormalizationService({
    AudioTranscodeRunner? runTranscode,
    TemporaryAudioPathProvider? temporaryPath,
    AppLogger? eventLogger,
    this.timeout = const Duration(minutes: 5),
    this.maxOutputBytes = AppConstants.maxTranscriptionBytes,
  }) : _runTranscode = runTranscode ?? _runWithFfmpeg,
       _temporaryPath = temporaryPath ?? PathUtils.temporaryAudioPath,
       _logger = eventLogger;

  final AudioTranscodeRunner _runTranscode;
  final TemporaryAudioPathProvider _temporaryPath;
  final AppLogger? _logger;
  final Duration timeout;
  final int maxOutputBytes;

  static Future<void>? _ffmpegInitialization;
  static const _cancellationGrace = Duration(seconds: 10);
  static const _ffmpegInitializationFailure = AppException(
    AppErrorCode.storageFailure,
    '内置音频转换组件无法加载。请确认使用完整应用目录，或重新安装后重试。',
    englishMessage:
        'The bundled audio converter could not be loaded. Use the complete application directory or reinstall the app and try again.',
    technicalDetail: 'ffmpeg_initialization_failed',
  );

  @override
  Future<T> withSeedAsrAudio<T>(
    File source,
    Future<T> Function(File normalizedFile, SeedAsrPcmWavAudio normalizedAudio)
    use,
  ) async {
    if (PathUtils.extensionOf(source.path) == 'wav') {
      final compatible = await SeedAsrPcmWavAudio.tryRead(source);
      if (compatible != null) {
        return use(source, compatible);
      }
    }

    final output = File(
      await _temporaryPath(stem: 'seed_asr_normalized', extension: 'wav'),
    );
    final working = File('${output.path}.part');
    final stopwatch = Stopwatch()..start();
    var prepared = false;
    await _deleteBestEffort(output);
    await _deleteBestEffort(working);
    await _logInfo('normalization_started', {
      'source_extension': PathUtils.extensionOf(source.path),
      'source_bytes': await source.length(),
      'target_format': 'pcm_s16le_wav_16000_mono',
      'platform': Platform.operatingSystem,
    });

    try {
      final exitCode = await _runTranscode(
        _arguments(source, working, maxOutputBytes),
        timeout,
      );
      if (exitCode != 0) {
        throw AppException(
          AppErrorCode.invalidFile,
          '无法将所选音频转换为 SeedASR 所需格式。请确认文件包含可解码的音轨。',
          englishMessage:
              'Unable to convert the selected audio for SeedASR. Make sure the file contains a decodable audio track.',
          technicalDetail: 'ffmpeg_exit_code=${exitCode ?? 'unknown'}',
        );
      }
      if (!await working.exists() || await working.length() == 0) {
        throw const AppException(
          AppErrorCode.invalidFile,
          '音频转换未生成有效文件。',
          englishMessage: 'Audio conversion did not produce a valid file.',
          technicalDetail: 'ffmpeg_output_missing',
        );
      }
      final outputBytes = await working.length();
      if (outputBytes >= maxOutputBytes) {
        throw const AppException(
          AppErrorCode.fileTooLarge,
          '转换后的 PCM WAV 超过 25 MB，请缩短音频后重试。',
          englishMessage:
              'The converted PCM WAV exceeds 25 MB. Shorten the audio and try again.',
          technicalDetail: 'normalized_audio_too_large',
        );
      }
      final normalizedAudio = await SeedAsrPcmWavAudio.read(working);
      await working.rename(output.path);
      prepared = true;
      stopwatch.stop();
      await _logInfo('normalization_completed', {
        'output_bytes': outputBytes,
        'duration_ms': stopwatch.elapsedMilliseconds,
        'target_format': 'pcm_s16le_wav_16000_mono',
      });
      return await use(output, normalizedAudio);
    } on TimeoutException {
      if (prepared) {
        rethrow;
      }
      stopwatch.stop();
      await _logError('normalization_failed', {
        'reason': 'timeout',
        'duration_ms': stopwatch.elapsedMilliseconds,
      });
      throw const AppException(
        AppErrorCode.invalidFile,
        '音频格式转换超时，请缩短文件后重试。',
        englishMessage:
            'Audio conversion timed out. Shorten the file and try again.',
        technicalDetail: 'ffmpeg_timeout',
      );
    } on AppException catch (error) {
      if (prepared) {
        rethrow;
      }
      stopwatch.stop();
      await _logError('normalization_failed', {
        'reason': error.technicalDetail ?? error.code.name,
        'duration_ms': stopwatch.elapsedMilliseconds,
      });
      rethrow;
    } catch (_) {
      if (prepared) {
        rethrow;
      }
      stopwatch.stop();
      await _logError('normalization_failed', {
        'reason': 'runtime_error',
        'duration_ms': stopwatch.elapsedMilliseconds,
      });
      throw const AppException(
        AppErrorCode.invalidFile,
        '无法转换所选音频，请确认文件未损坏后重试。',
        englishMessage:
            'Unable to convert the selected audio. Make sure the file is not damaged and try again.',
        technicalDetail: 'ffmpeg_runtime_error',
      );
    } finally {
      await _deleteBestEffort(working);
      await _deleteBestEffort(output);
    }
  }

  static List<String> _arguments(
    File source,
    File output,
    int outputSizeLimit,
  ) => [
    '-y',
    '-nostdin',
    '-hide_banner',
    '-nostats',
    '-loglevel',
    'quiet',
    '-i',
    source.path,
    '-map',
    '0:a:0',
    '-vn',
    '-ar',
    '16000',
    '-ac',
    '1',
    '-c:a',
    'pcm_s16le',
    '-f',
    'wav',
    '-fs',
    outputSizeLimit.toString(),
    output.path,
  ];

  static Future<int?> _runWithFfmpeg(
    List<String> arguments,
    Duration timeout,
  ) async {
    try {
      try {
        await _ensureFfmpegInitialized();
      } catch (_) {
        throw _ffmpegInitializationFailure;
      }
      final session = FFmpegKit.createSessionFromArguments(arguments);
      final execution = session.executeAsync();
      try {
        final completed = await execution.timeout(timeout);
        return completed.getReturnCode();
      } on TimeoutException {
        FFmpegKit.cancel(session);
        try {
          // Cancellation is only a request. Give native code a bounded grace
          // period to release its output handle before returning to the UI.
          await execution.timeout(_cancellationGrace);
        } on TimeoutException {
          // Do not block forever on an unresponsive native session. The
          // service's immediate cleanup may fail on Windows, so schedule a
          // second attempt for the moment the session eventually settles.
          _deleteOutputWhenSettled(execution, arguments.last);
        } catch (_) {
          // The timeout remains the user-facing failure if shutdown fails.
        }
        rethrow;
      }
    } on TimeoutException {
      rethrow;
    } on AppException {
      rethrow;
    } catch (_) {
      throw _ffmpegInitializationFailure;
    }
  }

  static void _deleteOutputWhenSettled(
    Future<Object?> execution,
    String outputPath,
  ) {
    unawaited(
      execution.then<void>(
        (_) => _deleteBestEffort(File(outputPath)),
        onError: (Object _, StackTrace __) =>
            _deleteBestEffort(File(outputPath)),
      ),
    );
  }

  static Future<void> _ensureFfmpegInitialized() {
    final existing = _ffmpegInitialization;
    if (existing != null) {
      return existing;
    }
    final pending = FFmpegKitExtended.initialize().then((_) {
      FFmpegKitConfig.setLogLevel(LogLevel.quiet);
    });
    _ffmpegInitialization = pending;
    return pending.catchError((Object error, StackTrace stackTrace) {
      if (identical(_ffmpegInitialization, pending)) {
        _ffmpegInitialization = null;
      }
      Error.throwWithStackTrace(error, stackTrace);
    });
  }

  static Future<void> _deleteBestEffort(File file) async {
    try {
      if (await file.exists()) {
        await file.delete();
      }
    } catch (_) {
      // The primary operation result is more useful than a cleanup failure.
    }
  }

  Future<void> _logInfo(String event, Map<String, Object?> fields) async {
    final logger = _logger;
    if (logger != null) {
      await logger.info('audio', event, fields: fields);
    }
  }

  Future<void> _logError(String event, Map<String, Object?> fields) async {
    final logger = _logger;
    if (logger != null) {
      await logger.error('audio', event, fields: fields);
    }
  }
}
