import 'dart:io';

import 'package:record/record.dart';

import '../../../core/errors/app_exception.dart';
import '../../../core/services/permission_service.dart';
import '../../../core/utils/path_utils.dart';

class AudioRecordManager {
  AudioRecordManager({
    AudioRecorder? recorder,
    PermissionService permissionService = const PermissionService(),
  })  : _recorder = recorder ?? AudioRecorder(),
        _permissionService = permissionService;

  final AudioRecorder _recorder;
  final PermissionService _permissionService;
  String? _currentPath;

  Future<void> start() async {
    try {
      await _permissionService.ensureMicrophoneAccess();
      if (!await _recorder.hasPermission()) {
        throw const AppException(
          AppErrorCode.permissionDenied,
          '麦克风不可用，请检查系统隐私设置。',
        );
      }
      final supportsWav = await _recorder.isEncoderSupported(AudioEncoder.wav);
      final encoder = supportsWav ? AudioEncoder.wav : AudioEncoder.aacLc;
      final extension = supportsWav ? 'wav' : 'm4a';
      final path = await PathUtils.temporaryAudioPath(
        stem: 'recording',
        extension: extension,
      );
      await _recorder.start(
        RecordConfig(
          encoder: encoder,
          sampleRate: 16000,
          bitRate: 128000,
          numChannels: 1,
          echoCancel: true,
          noiseSuppress: true,
        ),
        path: path,
      );
      _currentPath = path;
    } on AppException {
      rethrow;
    } catch (_) {
      throw const AppException(
        AppErrorCode.recordingUnavailable,
        '无法开始录音，麦克风可能正被其他程序占用。',
      );
    }
  }

  Future<void> pause() async {
    try {
      await _recorder.pause();
    } catch (_) {
      throw const AppException(
        AppErrorCode.recordingUnavailable,
        '暂停录音失败。',
      );
    }
  }

  Future<void> resume() async {
    try {
      await _recorder.resume();
    } catch (_) {
      throw const AppException(
        AppErrorCode.recordingUnavailable,
        '继续录音失败。',
      );
    }
  }

  Future<File> stop() async {
    try {
      final path = await _recorder.stop() ?? _currentPath;
      _currentPath = null;
      if (path == null) {
        throw const AppException(
          AppErrorCode.recordingUnavailable,
          '录音未生成有效文件。',
        );
      }
      final file = File(path);
      if (!await file.exists()) {
        throw const AppException(
          AppErrorCode.fileNotFound,
          '录音文件不存在。',
        );
      }
      return file;
    } on AppException {
      rethrow;
    } catch (_) {
      throw const AppException(
        AppErrorCode.recordingUnavailable,
        '停止录音失败。',
      );
    }
  }

  Future<void> dispose() async {
    try {
      await _recorder.dispose();
    } catch (_) {
      // Recorder disposal is best-effort during provider shutdown.
    }
  }
}
